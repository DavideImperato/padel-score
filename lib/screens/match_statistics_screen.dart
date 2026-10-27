import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/match_history.dart';
import '../services/player_directory.dart';
import '../services/match_statistics.dart';

class MatchStatisticsScreen extends StatefulWidget {
  const MatchStatisticsScreen({super.key});
  @override
  State<MatchStatisticsScreen> createState() => _MatchStatisticsScreenState();
}

class _MatchStatisticsScreenState extends State<MatchStatisticsScreen> {
  late Future<Map<String, dynamic>?> _statistics;
  bool _players = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statistics = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final directory = await PlayerDirectoryStore.load();
      final rawHistory = prefs.getString(MatchHistoryStore.key);
      if (directory == null || MatchHistoryStore.decode(rawHistory) == null) {
        _error = 'Rubrica o storico non leggibile: nessun dato è stato modificato.';
        return null;
      }
      return MatchStatistics.calculate(directory, await MatchHistoryStore.load());
    } catch (_) {
      _error = 'Impossibile leggere le statistiche locali.';
      return null;
    }
  }

  Widget _metric(String label, String value) => Expanded(child: Card(
    color: const Color(0xFF0F172A),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8), Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))],
    )),
  ));

  Widget _row(Map<String, dynamic> item, int index) {
    final recent = item['lastFive'] as List;
    return Card(color: const Color(0xFF0F172A), child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('#${index + 1}  ${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          Text('${item['winRate']}%', style: const TextStyle(color: Color(0xFFCCFF00), fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        Text('Giocate: ${item['played']}   Vittorie: ${item['wins']}   Sconfitte: ${item['losses']}', style: const TextStyle(color: Colors.white70)),
        Text('Set vinti/persi: ${item['setsWon']}/${item['setsLost']} · Partite con set brevi: ${item['shortSets']} · Standard: ${item['standardSets']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        if (recent.isNotEmpty) Wrap(spacing: 8, children: [const Text('Ultime:', style: TextStyle(color: Colors.white70)),
          ...recent.map((v) => Chip(label: Text(v == 'W' ? 'V' : 'S')))]),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF070B14),
    appBar: AppBar(title: const Text('STATISTICHE'), backgroundColor: const Color(0xFF0F172A)),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _statistics,
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final data = snap.data;
        if (data == null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Dati non disponibili.')));
        final rows = (data[_players ? 'players' : 'pairs'] as List).cast<Map<String, dynamic>>();
        final ranked = rows.where((r) => (r['played'] as int) > 0).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Solo partite concluse · Giocatori identificati tramite ID · Offline', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [_metric('Partite concluse', '${data['totalCompleted']}'),
            _metric('Senza collegamento', '${data['unlinkedMatches']}')]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: () => setState(() => _players = true), child: Text('Giocatori', style: TextStyle(color: _players ? const Color(0xFFCCFF00) : Colors.white70))),
            OutlinedButton(onPressed: () => setState(() => _players = false), child: Text('Coppie', style: TextStyle(color: !_players ? const Color(0xFFCCFF00) : Colors.white70))),
          ]),
          if (ranked.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(
            rows.isEmpty ? 'Nessun elemento registrato.' : 'Nessuna partita conclusa collegata. Seleziona i giocatori dalla rubrica nel setup.',
            style: const TextStyle(color: Colors.white70))),
          for (var i = 0; i < ranked.length; i++) _row(ranked[i], i),
          const SizedBox(height: 16),
          const Text('Le partite interrotte e quelle senza ID non contano come vittorie o sconfitte. Eliminando un risultato i totali cambiano alla successiva apertura.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]);
      },
    ),
  );
}
