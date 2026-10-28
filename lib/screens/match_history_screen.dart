import 'package:flutter/material.dart';
import '../widgets/app_content_safe_area.dart';
import '../services/app_orientation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/match_history.dart';
import '../services/match_interrupted.dart';
import '../services/match_history_advanced.dart';
import '../widgets/match_result_share_sheet.dart';
import 'match_result_statistics_screen.dart';
import '../services/player_directory.dart';
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
  bool _showFilters = false;
  String _query = '';
  String _playerId = '';
  String _pairId = '';
  DateTime? _from;
  DateTime? _to;
  Map<String, dynamic> _directory = {'players': <dynamic>[], 'pairs': <dynamic>[]};
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> items) {
    final pairs = (_directory['pairs'] as List).cast<Map<String, dynamic>>();
    final selectedPair = pairs.where((p) => p['id'] == _pairId);
    final pairIds = selectedPair.isEmpty ? <String>[] : List<String>.from(selectedPair.first['playerIds'] as List);
    final players = (_directory['players'] as List).cast<Map<String, dynamic>>();
    final names = <String, String>{};
    for (final player in players) {
      names[player['id'] as String] = player['name'] as String;
    }
    return _showInterrupted
      ? MatchHistoryAdvanced.interrupted(items, query: _query, playerId: _playerId,
          pairIds: pairIds, from: _from, to: _to, currentNames: names)
      : MatchHistoryAdvanced.finished(items, query: _query, playerId: _playerId,
          pairIds: pairIds, from: _from, to: _to, currentNames: names);
  }

  Future<void> _chooseDate(bool isStart) async {
    final value = await showDatePicker(context: context,
      initialDate: (isStart ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (value != null && mounted) setState(() { if (isStart) { _from = value; } else { _to = value; } });
  }

  String _dateLabel(DateTime? d) => d == null ? 'Tutte le date' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _copyVisibleCsv() async {
    final exportInterrupted = _showInterrupted;
    final records = await (exportInterrupted ? _interrupted : _history);
    if (exportInterrupted != _showInterrupted) return;
    final filtered = _filtered(records);
    if (filtered.isEmpty || !mounted) return;
    final csv = MatchHistoryAdvanced.csv(
      finished: exportInterrupted ? [] : filtered,
      interrupted: exportInterrupted ? filtered : []);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copiato negli appunti. Incollalo in un file o in un foglio di calcolo.')));
  }

  Widget _filters() {
    final players = (_directory['players'] as List).cast<Map<String, dynamic>>();
    final pairs = (_directory['pairs'] as List).cast<Map<String, dynamic>>();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Card(
      color: const Color(0xFF0F172A),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _searchController, onChanged: (text) => setState(() => _query = text),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Cerca squadra o giocatore',
              labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.search, color: Colors.white70))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              key: ValueKey('history-player-$_playerId'), initialValue: _playerId,
              dropdownColor: const Color(0xFF1E293B), isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giocatore', labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
              items: [const DropdownMenuItem(value: '', child: Text('Tutti')),
                ...players.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String)))],
              onChanged: (v) => setState(() => _playerId = v ?? ''),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
              key: ValueKey('history-pair-$_pairId'), initialValue: _pairId,
              dropdownColor: const Color(0xFF1E293B), isExpanded: true,
              decoration: const InputDecoration(labelText: 'Coppia', labelStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
              items: [const DropdownMenuItem(value: '', child: Text('Tutte')),
                ...pairs.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String)))],
              onChanged: (v) => setState(() => _pairId = v ?? ''),
            )),
          ]),
          Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.spaceBetween, children: [
            TextButton.icon(onPressed: () => _chooseDate(true), icon: const Icon(Icons.event), label: Text('Dal: ${_dateLabel(_from)}')),
            TextButton.icon(onPressed: () => _chooseDate(false), icon: const Icon(Icons.event), label: Text('Al: ${_dateLabel(_to)}')),
          ]),
          Wrap(spacing: 8, alignment: WrapAlignment.end, children: [
            TextButton.icon(onPressed: () => setState(() { _query = ''; _playerId = ''; _pairId = ''; _from = null; _to = null; _searchController.clear(); }),
              icon: const Icon(Icons.refresh), label: const Text('Azzera filtri')),
            OutlinedButton.icon(onPressed: _copyVisibleCsv, icon: const Icon(Icons.copy), label: const Text('Copia CSV')),
          ]),
        ],
      )),
    ));
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }


  @override
  void initState() {
    super.initState();
    _reload();
    PlayerDirectoryStore.load().then((directory) {
      if (mounted && directory != null) setState(() => _directory = directory);
    });
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
      await AppOrientation.match();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandscapeScoreboardScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non è stato possibile riprendere la partita.')));
    }
  }

  void _showInterruptedDetails(Map<String, dynamic> item) {
    final checkpoint = Map<String, dynamic>.from(item['checkpoint'] as Map);
    final settings = Map<String, dynamic>.from(checkpoint['settings'] as Map);
    final snap = Map<String, dynamic>.from(checkpoint['snapshot'] as Map);
    final sets = (snap['completedSets'] as List).map((s) => _setLabel(Map<String, dynamic>.from(s as Map))).join(' · ');
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Dettagli partita interrotta'),
      content: SingleChildScrollView(child: Text('Squadra A: ${settings['teamAName']}\n'
        '${settings['player1Name']} · ${settings['player2Name']}\n\n'
        'Squadra B: ${settings['teamBName']}\n'
        '${settings['player3Name']} · ${settings['player4Name']}\n\n'
        'Set conclusi: ${sets.isEmpty ? 'Nessuno' : sets}\n'
        'Set corrente: ${snap['currentGamesA']}–${snap['currentGamesB']}\n'
        'Formato: al meglio di ${settings['bestOfSets']} set')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi'))],
    ));
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
            TextButton.icon(onPressed: () => _showInterruptedDetails(item), icon: const Icon(Icons.info_outline), label: const Text('Dettagli')),
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
      body: AppContentSafeArea(
        child: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 12, children: [
          OutlinedButton(onPressed: () => setState(() => _showInterrupted = false),
            child: Text('Concluse', style: TextStyle(color: _showInterrupted ? Colors.white70 : const Color(0xFFCCFF00)))),
          OutlinedButton(onPressed: () => setState(() => _showInterrupted = true),
            child: Text('Interrotte', style: TextStyle(color: _showInterrupted ? const Color(0xFFCCFF00) : Colors.white70))),
          OutlinedButton.icon(onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list, color: const Color(0xFFCCFF00)),
            label: Text(_showFilters ? 'Nascondi filtri' : 'Cerca e filtra')),
        ])),
        if (_showFilters) SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.42).clamp(135.0, 225.0),
          child: SingleChildScrollView(child: _filters()),
        ),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _showInterrupted ? _interrupted : _history,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          final items = _filtered(all);
          if (items.isEmpty) return Center(child: Text(all.isEmpty
            ? (_showInterrupted ? 'Nessuna partita interrotta.' : 'Nessuna partita conclusa salvata sul dispositivo.')
            : 'Nessuna partita corrisponde ai filtri.',
            style: const TextStyle(color: Colors.white70)));
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
                    TextButton.icon(onPressed: () => MatchResultShareSheet.show(context, item),
                      icon: const Icon(Icons.share_outlined, color: Color(0xFFCCFF00)),
                      label: const Text('Condividi risultato')),
                    TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MatchResultStatisticsScreen(record: item))),
                      icon: const Icon(Icons.bar_chart, color: Color(0xFFCCFF00)),
                      label: const Text('Analisi della partita')),
                    TextButton.icon(onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: const Text('Elimina dallo storico')),
                  ],
                ),
              );
            },
          );
        },
      )),
        ]),
      ),
    );
  }
}
