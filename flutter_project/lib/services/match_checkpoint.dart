import 'dart:convert';
import '../models/padel_match_state.dart';

/// Formato locale versionato. Non contiene dati sincronizzati in rete.
class MatchCheckpointCodec {
  static const int version = 1;
  static const String key = 'padel_active_match_v1';

  static String encode(Map<String, dynamic> data) => jsonEncode({
    'version': version,
    'savedAt': DateTime.now().millisecondsSinceEpoch,
    ...data,
  });

  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != version) return null;
      if (value['settings'] is! Map || value['snapshot'] is! Map ||
          value['history'] is! List || value['runtime'] is! Map) {
        return null;
      }
      if (value['matchId'] != null &&
          (value['matchId'] is! String || (value['matchId'] as String).isEmpty ||
           (value['matchId'] as String).length > 128)) return null;
      final settings = Map<String, dynamic>.from(value['settings'] as Map);
      final runtime = Map<String, dynamic>.from(value['runtime'] as Map);
      if (!['teamAName', 'teamBName', 'player1Name', 'player2Name',
        'player3Name', 'player4Name'].every((k) => settings[k] is String) ||
        settings['firstServerPlayerId'] is! int ||
        (settings['firstServerPlayerId'] as int) < 1 ||
        (settings['firstServerPlayerId'] as int) > 4 ||
        settings['isGoldenPoint'] is! bool ||
        settings['advantagesBeforeGoldenPoint'] is! int ||
        ![1, 3, 5].contains(settings['bestOfSets']) ||
        settings['shortSets'] is! bool ||
        settings['decidingMatchTieBreak'] is! bool ||
        ![7, 10].contains(settings['decidingTieBreakPoints']) ||
        runtime['elapsedSeconds'] is! int ||
        (runtime['elapsedSeconds'] as int) < 0 ||
        runtime['isTimerRunning'] is! bool ||
        runtime['isSidesSwapped'] is! bool ||
        runtime['breakSecondsLeft'] is! int ||
        (runtime['breakSecondsLeft'] as int) < 0 ||
        runtime['isBreakActive'] is! bool) {
        return null;
      }
      final list = value['history'] as List;
      if (list.length > 50000) return null;
      snapshotFromJson(Map<String, dynamic>.from(value['snapshot'] as Map));
      for (final entry in list) {
        if (entry is! Map) return null;
        snapshotFromJson(Map<String, dynamic>.from(entry));
      }
      return value;
    } catch (_) { return null; }
  }

  static Team _team(dynamic value) {
    if (value == 'teamA') return Team.teamA;
    if (value == 'teamB') return Team.teamB;
    throw const FormatException('Squadra non valida');
  }
  static int _number(dynamic value, [int max = 1000000]) {
    if (value is! int || value < 0 || value > max) {
      throw const FormatException('Numero non valido');
    }
    return value;
  }

  static Map<String, dynamic> snapshotToJson(PadelMatchSnapshot s) => {
    'rawPointsA': s.rawPointsA, 'rawPointsB': s.rawPointsB,
    'deuceCount': s.deuceCount,
    'currentGamesA': s.currentGamesA, 'currentGamesB': s.currentGamesB,
    'completedSets': s.completedSets.map((set) => {
      'gamesA': set.gamesA, 'gamesB': set.gamesB,
      'tieBreakPointsA': set.tieBreakPointsA, 'tieBreakPointsB': set.tieBreakPointsB,
      'isCompleted': set.isCompleted, 'isMatchTieBreak': set.isMatchTieBreak,
      'winner': set.winner?.name,
    }).toList(),
    'servingTeam': s.servingTeam.name,
    'servingRotationIndex': s.servingRotationIndex,
    'initialSetServer': s.initialSetServer.name,
    'isTieBreak': s.isTieBreak, 'isMatchTieBreak': s.isMatchTieBreak,
    'tieBreakPointsA': s.tieBreakPointsA, 'tieBreakPointsB': s.tieBreakPointsB,
    'tieBreakInitialRotationIndex': s.tieBreakInitialRotationIndex,
    'matchWinner': s.matchWinner?.name, 'lastEventMessage': s.lastEventMessage,
  };

  static PadelMatchSnapshot snapshotFromJson(Map<String, dynamic> json) {
    final sets = json['completedSets'];
    if (sets is! List || sets.length > 5) throw const FormatException('Set invalidi');
    if (json['isTieBreak'] is! bool || json['lastEventMessage'] is! String) {
      throw const FormatException('Snapshot non valido');
    }
    return PadelMatchSnapshot(
      rawPointsA: _number(json['rawPointsA'], 4),
      rawPointsB: _number(json['rawPointsB'], 4),
      deuceCount: _number(json['deuceCount'] ?? 0, 10000),
      currentGamesA: _number(json['currentGamesA'], 10000),
      currentGamesB: _number(json['currentGamesB'], 10000),
      completedSets: sets.map((value) {
        if (value is! Map) throw const FormatException('Set non valido');
        final s = Map<String, dynamic>.from(value);
        return SetScore(
          gamesA: _number(s['gamesA'], 10000),
          gamesB: _number(s['gamesB'], 10000),
          tieBreakPointsA: s['tieBreakPointsA'] == null ? null : _number(s['tieBreakPointsA'], 10000),
          tieBreakPointsB: s['tieBreakPointsB'] == null ? null : _number(s['tieBreakPointsB'], 10000),
          isCompleted: s['isCompleted'] == true,
          isMatchTieBreak: s['isMatchTieBreak'] == true,
          winner: s['winner'] == null ? null : _team(s['winner']),
        );
      }).toList(growable: false),
      servingTeam: _team(json['servingTeam']),
      servingRotationIndex: _number(json['servingRotationIndex']),
      initialSetServer: _team(json['initialSetServer']),
      isTieBreak: json['isTieBreak'] as bool,
      isMatchTieBreak: json['isMatchTieBreak'] == true,
      tieBreakPointsA: _number(json['tieBreakPointsA'], 10000),
      tieBreakPointsB: _number(json['tieBreakPointsB'], 10000),
      tieBreakInitialRotationIndex: json['tieBreakInitialRotationIndex'] == null ? null : _number(json['tieBreakInitialRotationIndex']),
      matchWinner: json['matchWinner'] == null ? null : _team(json['matchWinner']),
      lastEventMessage: json['lastEventMessage'] as String,
    );
  }
}
