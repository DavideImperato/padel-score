import 'package:flutter/material.dart';
import '../services/match_result_analysis.dart';
import '../widgets/app_content_safe_area.dart';

/// Report del singolo incontro, distinto dalle statistiche cumulative.
/// Valori individuali non presenti nei dati non vengono stimati.
class MatchResultStatisticsScreen extends StatelessWidget {
  const MatchResultStatisticsScreen({super.key, required this.record});
  final Map<String, dynamic> record;
  static const navy = Color(0xFF101D3A);
  static const yellow = Color(0xFFCCFF00);
  static const cyan = Color(0xFF00E5FF);

  String _duration(int seconds) =>
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _label(String label, String value, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF1D2D4B), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
    ]),
  ));

  @override
  Widget build(BuildContext context) {
    final analysis = MatchResultAnalysis.fromRecord(record);
    final sets = (analysis['perSet'] as List).cast<Map<String, dynamic>>();
    final progression = (analysis['progression'] as List).cast<Map<String, int>>();
    final players = (record['players'] as List).cast<String>();
    final nameA = record['teamAName'] as String;
    final nameB = record['teamBName'] as String;
    final winnerA = analysis['winner'] == 'teamA';
    final gamesA = analysis['gamesA'] as int;
    final gamesB = analysis['gamesB'] as int;
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(title: const Text('Analisi della partita'), backgroundColor: const Color(0xFF0F172A)),
      body: AppContentSafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Icon(Icons.emoji_events_rounded, size: 42, color: yellow)),
        const SizedBox(height: 8),
        Text('Vittoria ${winnerA ? nameA : nameB}', textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 12),
        Row(children: [
          _label('Set ${nameA}', '${analysis['setsA']}', yellow),
          const SizedBox(width: 10),
          _label('Set ${nameB}', '${analysis['setsB']}', cyan),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _label('Game vinti A', '$gamesA', yellow),
          const SizedBox(width: 10),
          _label('Game vinti B', '$gamesB', cyan),
        ]),
        const SizedBox(height: 12),
        Text('Durata ${_duration(analysis['durationSeconds'] as int)} · '
          '${analysis['tieBreaks']} tie-break giocati', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 22),
        const Text('Riepilogo dei set', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final set in sets) Card(color: const Color(0xFF1D2D4B), child: ListTile(
          title: Text('Set ${set['number']}', style: const TextStyle(color: Colors.white)),
          trailing: Text(set['isMatchTieBreak'] == true
            ? 'MTB ${set['tieBreakA']}–${set['tieBreakB']}'
            : '${set['a']}–${set['b']}${set['tieBreakA'] != null ? ' (TB ${set['tieBreakA']}–${set['tieBreakB']})' : ''}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Vince ${set['winner'] == 'teamA' ? nameA : nameB}', style: const TextStyle(color: Colors.white70)),
        )),
        const SizedBox(height: 16),
        const Text('Andamento della partita', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        const Text('Progressione dei set, non dei singoli punti', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 12),
        for (final row in progression) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          SizedBox(width: 58, child: Text('Set ${row['set']}', style: const TextStyle(color: Colors.white70))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Row(children: [
            if (row['a']! > 0) Expanded(flex: row['a']!, child: Container(height: 14, color: yellow)),
            if (row['b']! > 0) Expanded(flex: row['b']!, child: Container(height: 14, color: cyan)),
          ]))),
          const SizedBox(width: 8),
          Text('${row['a']}–${row['b']}', style: const TextStyle(color: Colors.white)),
        ])),
        if (analysis['gameShareA'] != null) ...[
          const SizedBox(height: 12),
          const Text('Ripartizione dei game vinti', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: gamesA / (gamesA + gamesB), minHeight: 12,
            backgroundColor: cyan, valueColor: const AlwaysStoppedAnimation<Color>(yellow)),
          const SizedBox(height: 5),
          Text('${(analysis['gameShareA'] as double).toStringAsFixed(1)}% A · '
            '${(analysis['gameShareB'] as double).toStringAsFixed(1)}% B',
            style: const TextStyle(color: Colors.white70)),
        ],
        const SizedBox(height: 24),
        const Text('Giocatori e coppie', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('$nameA: ${players[0]} / ${players[1]}', style: const TextStyle(color: yellow)),
        const SizedBox(height: 5),
        Text('$nameB: ${players[2]} / ${players[3]}', style: const TextStyle(color: cyan)),
        const SizedBox(height: 10),
        for (var i = 0; i < players.length; i++) Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Icon(Icons.circle, size: 8, color: i < 2 ? yellow : cyan),
            const SizedBox(width: 8),
            Expanded(child: Text(players[i], style: const TextStyle(color: Colors.white))),
            Text((i < 2) == winnerA ? 'Vittoria di coppia' : 'Sconfitta di coppia',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        const SizedBox(height: 12),
        const Text('Analisi individuale: l’app non registra ancora chi ha eseguito il colpo, '
          'errori, vincenti, smash o punti personali. Questi dati non possono essere '
          'ricavati dal solo risultato e non vengono inventati.',
          style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 24),
      ])),
    );
  }
}
