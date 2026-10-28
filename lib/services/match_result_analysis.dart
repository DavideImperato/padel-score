import 'match_history.dart';
import 'match_point_analytics.dart';

/// Calcoli riproducibili dai soli risultati effettivamente archiviati.
/// Non inventa colpi o punti attribuiti a singoli giocatori.
class MatchResultAnalysis {
  static Map<String, dynamic> fromRecord(Map<String, dynamic> record) {
    if (!MatchHistoryStore.validRecord(record)) {
      throw ArgumentError('Risultato non valido');
    }
    final sets = (record['sets'] as List).cast<Map>();
    var wonA = 0, wonB = 0, gamesA = 0, gamesB = 0;
    var tieBreaks = 0;
    final progression = <Map<String, int>>[];
    final perSet = <Map<String, dynamic>>[];
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      final isMtb = s['isMatchTieBreak'] == true;
      final a = s['gamesA'] as int;
      final b = s['gamesB'] as int;
      gamesA += a;
      gamesB += b;
      if (s['winner'] == 'teamA') wonA++; else wonB++;
      if (isMtb || s['tieBreakPointsA'] != null) tieBreaks++;
      perSet.add({
        'number': i + 1, 'a': a, 'b': b,
        'isMatchTieBreak': isMtb,
        'tieBreakA': s['tieBreakPointsA'], 'tieBreakB': s['tieBreakPointsB'],
        'winner': s['winner'],
      });
      progression.add({'set': i + 1, 'a': wonA, 'b': wonB});
    }
    final totalGames = gamesA + gamesB;
    return {
      'winner': record['winner'],
      'setsA': wonA, 'setsB': wonB,
      'gamesA': gamesA, 'gamesB': gamesB,
      'totalGames': totalGames,
      'gameShareA': totalGames == 0 ? null : gamesA / totalGames * 100,
      'gameShareB': totalGames == 0 ? null : gamesB / totalGames * 100,
      'tieBreaks': tieBreaks,
      'perSet': perSet,
      'progression': progression,
      'durationSeconds': record['durationSeconds'],
      'pointAnalytics': MatchPointAnalytics.fromRecord(record),
    };
  }
}
