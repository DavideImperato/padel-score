import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/match_history.dart';
import '../services/match_interrupted.dart';
import '../providers/padel_score_provider.dart';
import 'landscape_scoreboard_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _history;
  late Future<List<Map<String, dynamic>>> _interrupted;
  bool _showInterrupted = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = MatchHistoryStore.load();
    _interrupted = MatchInterruptedStore.load();
  }

  String _duration(int n) =>
      '${(n ~/ 3600).toString().padLeft(2, '0')}:${((n % 3600) ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';

  String _setLabel(Map<String, dynamic> s) {
    final a = s['tieBreakPointsA'];
    final b = s['tieBreakPointsB'];
    if (s['isMatchTieBreak'] == true) return 'MTB $a–$b';
    return '${s['gamesA']}–${s['gamesB']}${a == null || b == null ? '' : ' (TB $a–$b)'}';
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare il risultato?'),
        content: Text('${item['teamAName']} vs ${item['teamBName']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await MatchHistoryStore.delete(item['id'] as String);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile eliminare il risultato.')));
    }
    setState(_reload);
  }

  Future<void> _deleteInterrupted(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Eliminare la partita interrotta?'),
      content: const Text('Non potrai più recuperarla.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Annulla')),
        TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Elimina')),
      ],
    ));
    if (yes != true) return;
    final ok = await MatchInterruptedStore.delete(item['id'] as String);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eliminazione non riuscita.')));
    }
    setState(_reload);
  }

  Future<void> _resumeInterrupted(Map<String, dynamic> item) async {
    final ok = await context.read<PadelScoreProvider>().resumeInterruptedMatch(item['id'] as String);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandscapeScoreboardScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non è stato possibile riprendere la partita.')));
    }
  }

  Widget _interruptedItem(Map<String, dynamic> item) {
    final checkpoint = Map<String, dynamic>.from(item['checkpoint'] as Map);
    final settings = Map<String, dynamic>.from(checkpoint['settings'] as Map);
    final snap = Map<String, dynamic>.from(checkpoint['snapshot'] as Map);
    final runtime = Map<String, dynamic>.from(checkpoint['runtime'] as Map);
    final date = DateTime.fromMillisecondsSinceEpoch(item['interruptedAt'] as int);
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${settings['teamAName']} vs ${settings['teamBName']}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Partita interrotta · ${date.day}/${date.month}/${date.year} · ${_duration(runtime['elapsedSeconds'] as int)}',
            style: const TextStyle(color: Color(0xFFFBBF24))),
          const SizedBox(height: 8),
          Text('Set in corso: ${snap['currentGamesA']}–${snap['currentGamesB']} · Set conclusi: ${(snap['completedSets'] as List).length}', style: const TextStyle(color: Colors.white70)),
          Wrap(spacing: 8, children: [
            ElevatedButton.icon(onPressed: () => _resumeInterrupted(item), icon: const Icon(Icons.play_arrow), label: const Text('RIPRENDI')),
            TextButton.icon(onPressed: () => _deleteInterrupted(item), icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: const Text('Elimina')),
          ]),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(title: const Text('STORICO PARTITE'), backgroundColor: const Color(0xFF0F172A)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 12, children: [
          OutlinedButton(onPressed: () => setState(() => _showInterrupted = false),
            child: Text('Concluse', style: TextStyle(color: _showInterrupted ? Colors.white70 : const Color(0xFFCCFF00)))),
          OutlinedButton(onPressed: () => setState(() => _showInterrupted = true),
            child: Text('Interrotte', style: TextStyle(color: _showInterrupted ? const Color(0xFFCCFF00) : Colors.white70))),
        ])),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _showInterrupted ? _interrupted : _history,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return Center(child: Text(_showInterrupted ? 'Nessuna partita interrotta.' : 'Nessuna partita conclusa salvata sul dispositivo.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (_showInterrupted) return _interruptedItem(item);
              final sets = (item['sets'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
              final players = List<String>.from(item['players'] as List);
              final winningName = item['winner'] == 'teamA' ? item['teamAName'] : item['teamBName'];
              final date = DateTime.fromMillisecondsSinceEpoch(item['completedAt'] as int);
              return Card(
                color: const Color(0xFF0F172A),
                child: ExpansionTile(
                  iconColor: const Color(0xFFCCFF00),
                  collapsedIconColor: Colors.white70,
                  title: Text('${item['teamAName']}  vs  ${item['teamBName']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('🏆 $winningName · ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${_duration(item['durationSeconds'] as int)}', style: const TextStyle(color: Color(0xFFCCFF00))),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  children: [
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      for (var i = 0; i < sets.length; i++) Chip(label: Text('Set ${i + 1}: ${_setLabel(sets[i])}')),
                    ]),
                    const SizedBox(height: 8),
                    Text('${item['teamAName']}: ${players[0]} / ${players[1]}', style: const TextStyle(color: Colors.white70)),
                    Text('${item['teamBName']}: ${players[2]} / ${players[3]}', style: const TextStyle(color: Colors.white70)),
                    Text('Al meglio di ${item['bestOfSets']} set · ${item['gamesPerSet']} game', style: const TextStyle(color: Colors.white54)),
                    TextButton.icon(onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: const Text('Elimina dallo storico')),
                  ],
                ),
              );
            },
          );
        },
      )),
      ]),
    );
  }
}
