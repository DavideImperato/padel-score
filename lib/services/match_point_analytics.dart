import '../models/padel_match_state.dart';

/// Registro cronologico dei soli punti assegnati. Il provider iPhone resta
/// l'unica fonte: Watch, telecomando e tap attraversano tutti addPoint().
/// I dati sono locali e gli incontri precedenti non vengono stimati.
class MatchPointAnalytics {
  static const int maxEvents = 5000;

  static Map<String, dynamic> event({
    required int index,
    required int undoDepth,
    required int elapsedSeconds,
    required Team scoringTeam,
    required int serverPlayerId,
    required PadelMatchSnapshot before,
    required PadelMatchSnapshot after,
    required bool goldenPoint,
  }) {
    final gamesWon = after.completedSets.length > before.completedSets.length ||
        after.currentGamesA != before.currentGamesA ||
        after.currentGamesB != before.currentGamesB;
    final setWon = after.completedSets.length > before.completedSets.length;
    return <String, dynamic>{
      'index': index,
      'undoDepth': undoDepth,
      'elapsedSeconds': elapsedSeconds,
      'occurredAt': DateTime.now().millisecondsSinceEpoch,
      'team': scoringTeam.name,
      'serverPlayerId': serverPlayerId,
      'setNumber': before.completedSets.length + 1,
      'gamesA': before.currentGamesA,
      'gamesB': before.currentGamesB,
      'beforeA': before.displayPointA,
      'beforeB': before.displayPointB,
      'afterA': after.displayPointA,
      'afterB': after.displayPointB,
      'isTieBreak': before.isTieBreak,
      'isMatchTieBreak': before.isMatchTieBreak,
      'isGoldenPoint': goldenPoint,
      'gameWon': gamesWon,
      'setWon': setWon,
      'matchWon': after.matchWinner != null,
    };
  }

  static bool validEvent(dynamic value) {
    if (value is! Map) return false;
    final e = Map<String, dynamic>.from(value);
    bool number(String key, int max) => e[key] is int && e[key] >= 0 && e[key] <= max;
    return number('index', maxEvents) && number('undoDepth', 50000) &&
        number('elapsedSeconds', 100000000) &&
        number('occurredAt', 9000000000000000) &&
        number('setNumber', 5) && e['setNumber'] > 0 &&
        number('gamesA', 10000) && number('gamesB', 10000) &&
        number('serverPlayerId', 4) && e['serverPlayerId'] > 0 &&
        (e['team'] == 'teamA' || e['team'] == 'teamB') &&
        ['beforeA', 'beforeB', 'afterA', 'afterB'].every(
          (key) => e[key] is String && (e[key] as String).length <= 16) &&
        ['isTieBreak', 'isMatchTieBreak', 'isGoldenPoint',
          'gameWon', 'setWon', 'matchWon'].every((key) => e[key] is bool);
  }

  /// null = dati non validi; [] = incontro nuovo o privo di cronologia.
  static List<Map<String, dynamic>>? decode(dynamic raw) {
    if (raw == null) return <Map<String, dynamic>>[];
    if (raw is! List || raw.length > maxEvents || !raw.every(validEvent)) return null;
    final list = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    for (var i = 0; i < list.length; i++) {
      if (list[i]['index'] != i + 1 ||
          (i > 0 && list[i]['elapsedSeconds'] < list[i - 1]['elapsedSeconds'])) {
        return null;
      }
    }
    return list;
  }

  static Map<String, dynamic>? fromRecord(Map<String, dynamic> record) {
    // Gli incontri legacy non possiedono un registro: non inferire i punti.
    if (!record.containsKey('pointEvents')) return null;
    final events = decode(record['pointEvents']);
    if (events == null) return null;
    var a = 0, b = 0, streakA = 0, streakB = 0;
    var maxA = 0, maxB = 0, leadChanges = 0, lastLeader = 0;
    var goldA = 0, goldB = 0, tbA = 0, tbB = 0;
    var gamesA = 0, gamesB = 0, breaksA = 0, breaksB = 0;
    final timeline = <Map<String, int>>[{'index': 0, 'a': 0, 'b': 0}];
    for (final event in events) {
      final teamA = event['team'] == 'teamA';
      if (teamA) {
        a++; streakA++; streakB = 0;
        if (streakA > maxA) maxA = streakA;
      } else {
        b++; streakB++; streakA = 0;
        if (streakB > maxB) maxB = streakB;
      }
      if (event['isGoldenPoint'] == true) {
        if (teamA) { goldA++; } else { goldB++; }
      }
      if (event['isTieBreak'] == true) {
        if (teamA) { tbA++; } else { tbB++; }
      }
      if (event['gameWon'] == true && event['isMatchTieBreak'] != true) {
        final serverTeamA = (event['serverPlayerId'] == 1 || event['serverPlayerId'] == 2);
        if (teamA) {
          gamesA++;
          if (!serverTeamA) breaksA++;
        } else {
          gamesB++;
          if (serverTeamA) breaksB++;
        }
      }
      final leader = a == b ? 0 : (a > b ? 1 : -1);
      if (leader != 0) {
        if (lastLeader != 0 && leader != lastLeader) leadChanges++;
        lastLeader = leader;
      }
      timeline.add({'index': a + b, 'a': a, 'b': b});
    }
    return <String, dynamic>{
      'totalPoints': events.length,
      'pointsA': a, 'pointsB': b,
      'pointShareA': events.isEmpty ? null : a * 100 / events.length,
      'pointShareB': events.isEmpty ? null : b * 100 / events.length,
      'longestStreakA': maxA, 'longestStreakB': maxB,
      'leadChanges': leadChanges,
      'goldenPointsA': goldA, 'goldenPointsB': goldB,
      'tieBreakPointsA': tbA, 'tieBreakPointsB': tbB,
      'gamesWonA': gamesA, 'gamesWonB': gamesB,
      'breakGamesA': breaksA, 'breakGamesB': breaksB,
      'timeline': timeline,
      'lastTen': events.length <= 10 ? events : events.sublist(events.length - 10),
    };
  }
}
