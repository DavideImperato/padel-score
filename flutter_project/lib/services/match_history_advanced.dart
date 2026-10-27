/// Filtri ed esportazione CSV dello storico offline, senza modificare i record.
class MatchHistoryAdvanced {
  static String _normalize(String value) => value.trim().toLowerCase()
    .replaceAll(RegExp('[àáâãä]'), 'a')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[òóôõö]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u');

  static bool _match({required int timestamp, required List<String> terms,
    required List<String?> ids, required String query,
    required String playerId, required List<String> pairIds,
    required DateTime? from, required DateTime? to}) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (from != null && date.isBefore(DateTime(from.year, from.month, from.day))) return false;
    if (to != null && !date.isBefore(DateTime(to.year, to.month, to.day + 1))) return false;
    if (playerId.isNotEmpty && !ids.contains(playerId)) return false;
    if (pairIds.isNotEmpty) {
      if (pairIds.length != 2) return false;
      final a = ids.take(2).toList();
      final b = ids.skip(2).take(2).toList();
      if (!(pairIds.every(a.contains) || pairIds.every(b.contains))) return false;
    }
    final q = _normalize(query);
    return q.isEmpty || terms.any((term) => _normalize(term).contains(q));
  }

  static List<String?> _ids(dynamic source) {
    if (source is! List || source.length != 4) return <String?>[null, null, null, null];
    return source.map((v) => v is String ? v : null).toList();
  }

  static List<Map<String, dynamic>> finished(List<Map<String, dynamic>> matches, {
    String query = '', String playerId = '', List<String> pairIds = const [],
    DateTime? from, DateTime? to, Map<String, String> currentNames = const {},
  }) => matches.where((m) {
    final ids = _ids(m['playerIds']);
    final names = (m['players'] as List).cast<String>();
    return _match(timestamp: m['completedAt'] as int,
      terms: [m['teamAName'] as String, m['teamBName'] as String, ...names,
        ...ids.map((id) => currentNames[id] ?? '')],
      ids: ids, query: query, playerId: playerId, pairIds: pairIds, from: from, to: to);
  }).toList();

  static List<Map<String, dynamic>> interrupted(List<Map<String, dynamic>> matches, {
    String query = '', String playerId = '', List<String> pairIds = const [],
    DateTime? from, DateTime? to, Map<String, String> currentNames = const {},
  }) => matches.where((m) {
    final checkpoint = Map<String, dynamic>.from(m['checkpoint'] as Map);
    final settings = Map<String, dynamic>.from(checkpoint['settings'] as Map);
    final ids = _ids(settings['playerIds']);
    return _match(timestamp: m['interruptedAt'] as int,
      terms: [for (final key in ['teamAName','teamBName','player1Name','player2Name','player3Name','player4Name']) settings[key] as String,
        ...ids.map((id) => currentNames[id] ?? '')],
      ids: ids, query: query, playerId: playerId, pairIds: pairIds, from: from, to: to);
  }).toList();

  static String _csvCell(Object? value) {
    var text = (value ?? '').toString().replaceAll(RegExp(r'\r\n?'), '\n');
    if (RegExp(r'^\s*[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _row(List<Object?> cells) => cells.map(_csvCell).join(';');

  static String _score(Map<String, dynamic> s) {
    if (s['isMatchTieBreak'] == true) return 'MTB ${s['tieBreakPointsA'] ?? 0}-${s['tieBreakPointsB'] ?? 0}';
    final a = s['tieBreakPointsA'];
    final b = s['tieBreakPointsB'];
    return '${s['gamesA']}-${s['gamesB']}${a == null || b == null ? '' : ' (TB $a-$b)'}';
  }

  /// CSV UTF-8 separato da punto e virgola; da copiare negli appunti in Flutter.
  static String csv({List<Map<String, dynamic>> finished = const [], List<Map<String, dynamic>> interrupted = const []}) {
    final rows = <String>[_row(['Stato','Data ISO','Squadra A','Squadra B','Giocatore A1','Giocatore A2','Giocatore B1','Giocatore B2','Vincitore','Set','Durata (secondi)'])];
    for (final item in finished) {
      final players = (item['players'] as List).cast<String>();
      final sets = (item['sets'] as List).map((s) => _score(Map<String, dynamic>.from(s as Map))).join(' | ');
      rows.add(_row(['Conclusa', DateTime.fromMillisecondsSinceEpoch(item['completedAt'] as int).toUtc().toIso8601String(), item['teamAName'], item['teamBName'], ...players,
        item['winner'] == 'teamA' ? item['teamAName'] : item['teamBName'], sets, item['durationSeconds']]));
    }
    for (final item in interrupted) {
      final checkpoint = Map<String, dynamic>.from(item['checkpoint'] as Map);
      final s = Map<String, dynamic>.from(checkpoint['settings'] as Map);
      final snapshot = Map<String, dynamic>.from(checkpoint['snapshot'] as Map);
      final runtime = Map<String, dynamic>.from(checkpoint['runtime'] as Map);
      final sets = (snapshot['completedSets'] as List).map((s) => _score(Map<String, dynamic>.from(s as Map))).toList();
      sets.add(snapshot['isTieBreak'] == true ? 'In corso TB ${snapshot['tieBreakPointsA']}-${snapshot['tieBreakPointsB']}' : 'In corso ${snapshot['currentGamesA']}-${snapshot['currentGamesB']}');
      rows.add(_row(['Interrotta', DateTime.fromMillisecondsSinceEpoch(item['interruptedAt'] as int).toUtc().toIso8601String(), s['teamAName'], s['teamBName'],
        s['player1Name'], s['player2Name'], s['player3Name'], s['player4Name'], '', sets.join(' | '), runtime['elapsedSeconds']]));
    }
    return '\uFEFF${rows.join('\r\n')}\r\n';
  }
}
