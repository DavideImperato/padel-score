import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/padel_match_state.dart';

/// Archivio separato dal checkpoint della partita in corso, solo locale.
class MatchHistoryStore {
  static const String key = 'padel_completed_matches_v1';
  static const int maxMatches = 250;

  static bool validRecord(dynamic value) {
    if (value is! Map) return false;
    final r = Map<String, dynamic>.from(value);
    final players = r['players'];
    final sets = r['sets'];
    if (r['version'] != 1 || r['id'] is! String ||
        (r['id'] as String).isEmpty || (r['id'] as String).length > 128 ||
        r['completedAt'] is! int || (r['completedAt'] as int) < 0 ||
        r['durationSeconds'] is! int || (r['durationSeconds'] as int) < 0 ||
        r['teamAName'] is! String || r['teamBName'] is! String ||
        r['winner'] != 'teamA' && r['winner'] != 'teamB' ||
        players is! List || players.length != 4 || !players.every((p) => p is String) ||
        sets is! List || sets.isEmpty || sets.length > 5 ||
        ![1, 3, 5].contains(r['bestOfSets']) || ![4, 6].contains(r['gamesPerSet'])) {
      return false;
    }
    for (final value in sets) {
      if (value is! Map) return false;
      final s = Map<String, dynamic>.from(value);
      if (s['gamesA'] is! int || s['gamesB'] is! int ||
          (s['gamesA'] as int) < 0 || (s['gamesB'] as int) < 0 ||
          s['isCompleted'] != true ||
          s['winner'] != 'teamA' && s['winner'] != 'teamB' ||
          s['isMatchTieBreak'] is! bool ||
          (s['tieBreakPointsA'] != null && s['tieBreakPointsA'] is! int) ||
          (s['tieBreakPointsB'] != null && s['tieBreakPointsB'] is! int)) {
        return false;
      }
    }
    return true;
  }

  /// Null = archivio non valido; non sovrascriverlo con una lista vuota.
  static List<Map<String, dynamic>>? decode(String? raw) {
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List || data.length > maxMatches || !data.every(validRecord)) return null;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { return null; }
  }

  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = decode(prefs.getString(key)) ?? [];
      data.sort((a, b) => (b['completedAt'] as int).compareTo(a['completedAt'] as int));
      return data;
    } catch (_) { return []; }
  }

  static Map<String, dynamic> buildRecord({
    required String id, required PadelMatchSnapshot snapshot,
    required int durationSeconds,
    required String teamAName, required String teamBName,
    required List<String> players, required int bestOfSets,
    required int gamesPerSet, required int completedAt,
  }) => {
    'version': 1, 'id': id, 'completedAt': completedAt,
    'durationSeconds': durationSeconds,
    'teamAName': teamAName, 'teamBName': teamBName,
    'players': players, 'winner': snapshot.matchWinner?.name,
    'sets': snapshot.completedSets.map((set) => {
      'gamesA': set.gamesA, 'gamesB': set.gamesB,
      'isCompleted': set.isCompleted,
      'isMatchTieBreak': set.isMatchTieBreak,
      'tieBreakPointsA': set.tieBreakPointsA,
      'tieBreakPointsB': set.tieBreakPointsB,
      'winner': set.winner?.name,
    }).toList(),
    'bestOfSets': bestOfSets,
    'gamesPerSet': gamesPerSet,
  };

  static Future<bool> saveRecord(SharedPreferences prefs, Map<String, dynamic> record) async {
    if (!validRecord(record)) return false;
    final items = decode(prefs.getString(key));
    if (items == null) return false;
    if (items.any((m) => m['id'] == record['id'])) return true; // idempotente
    if (items.length >= maxMatches) return false;
    return prefs.setString(key, jsonEncode([record, ...items]));
  }

  static Future<bool> delete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = decode(prefs.getString(key));
      if (items == null || !items.any((m) => m['id'] == id)) return false;
      return prefs.setString(key, jsonEncode(items.where((m) => m['id'] != id).toList()));
    } catch (_) { return false; }
  }
}
