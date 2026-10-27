import 'package:flutter/material.dart';
import '../services/match_history.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() { _history = MatchHistoryStore.load(); }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(title: const Text('STORICO PARTITE'), backgroundColor: const Color(0xFF0F172A)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _history,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('Nessuna partita conclusa salvata sul dispositivo.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
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
      ),
    );
  }
}
