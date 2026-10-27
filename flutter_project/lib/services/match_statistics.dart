/// Statistiche derivate dai risultati conclusi: non scrive nello storico.
/// Usa esclusivamente gli ID registrati, mai l'uguaglianza tra nomi.
class MatchStatistics {
  static String _pairKey(String first, String second) {
    final ids = [first, second]..sort();
    return '${ids[0].length}:${ids[0]}${ids[1]}';
  }

  static Map<String, dynamic> _row(String id, String name) => {
    'id': id, 'name': name, 'played': 0, 'wins': 0, 'losses': 0,
    'winRate': 0.0, 'setsWon': 0, 'setsLost': 0,
    'lastFive': <String>[], 'shortSets': 0, 'standardSets': 0,
  };

  static void _apply(Map<String, dynamic> row, Map<String, dynamic> match, String side) {
    row['played'] = (row['played'] as int) + 1;
    final won = match['winner'] == side;
    row[won ? 'wins' : 'losses'] = (row[won ? 'wins' : 'losses'] as int) + 1;
    (row['lastFive'] as List<String>).add(won ? 'W' : 'L');
    final sets = match['sets'] as List;
    final wonSets = sets.where((s) => s['winner'] == side).length;
    row['setsWon'] = (row['setsWon'] as int) + wonSets;
    row['setsLost'] = (row['setsLost'] as int) + sets.length - wonSets;
    final field = match['gamesPerSet'] == 4 ? 'shortSets' : 'standardSets';
    row[field] = (row[field] as int) + 1;
  }

  static List<Map<String, dynamic>> _rank(Iterable<Map<String, dynamic>> rows) {
    final result = rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      final played = copy['played'] as int;
      copy['winRate'] = played == 0 ? 0.0 : ((copy['wins'] as int) / played * 1000).round() / 10.0;
      copy['lastFive'] = (copy['lastFive'] as List<String>).take(5).toList();
      return copy;
    }).toList();
    result.sort((a, b) {
      var c = (b['wins'] as int).compareTo(a['wins'] as int);
      if (c != 0) return c;
      c = (b['winRate'] as double).compareTo(a['winRate'] as double);
      if (c != 0) return c;
      c = (b['played'] as int).compareTo(a['played'] as int);
      if (c != 0) return c;
      return (a['name'] as String).compareTo(b['name'] as String);
    });
    return result;
  }

  static Map<String, dynamic> calculate(
    Map<String, dynamic> directory, List<Map<String, dynamic>> completed,
  ) {
    final playerRows = <String, Map<String, dynamic>>{};
    final pairRows = <String, Map<String, dynamic>>{};
    for (final p in directory['players'] as List) {
      playerRows[p['id'] as String] = _row(p['id'] as String, p['name'] as String);
    }
    for (final p in directory['pairs'] as List) {
      final ids = p['playerIds'] as List;
      pairRows[_pairKey(ids[0] as String, ids[1] as String)] = _row(p['id'] as String, p['name'] as String);
    }
    final ordered = List<Map<String, dynamic>>.from(completed)
      ..sort((a, b) {
        final c = (b['completedAt'] as int).compareTo(a['completedAt'] as int);
        return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
      });
    var unlinked = 0;
    for (final match in ordered) {
      final rawIds = match['playerIds'];
      if (rawIds is! List || rawIds.length != 4) { unlinked++; continue; }
      final ids = rawIds.map((v) => v is String ? v : null).toList();
      final nonNull = ids.whereType<String>().toList();
      if (nonNull.isEmpty || nonNull.toSet().length != nonNull.length) { unlinked++; continue; }
      var attributed = false;
      for (var team = 0; team < 2; team++) {
        final side = team == 0 ? 'teamA' : 'teamB';
        final first = ids[team * 2];
        final second = ids[team * 2 + 1];
        for (final id in [first, second]) {
          final row = playerRows[id];
          if (row != null) { _apply(row, match, side); attributed = true; }
        }
        if (first != null && second != null) {
          final row = pairRows[_pairKey(first, second)];
          if (row != null) { _apply(row, match, side); attributed = true; }
        }
      }
      if (!attributed) unlinked++;
    }
    return {
      'players': _rank(playerRows.values),
      'pairs': _rank(pairRows.values),
      'totalCompleted': completed.length,
      'unlinkedMatches': unlinked,
    };
  }
}
