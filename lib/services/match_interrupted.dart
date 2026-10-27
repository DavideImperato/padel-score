import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'match_checkpoint.dart';

/// Offline archive of paused (not completed) matches. Independent of final results.
class MatchInterruptedStore {
  static const key = 'padel_interrupted_matches_v1';
  static const maxMatches = 30;

  static bool validRecord(dynamic value) {
    if (value is! Map) return false;
    final data = Map<String, dynamic>.from(value);
    if (data['version'] != 1 || data['id'] is! String ||
        (data['id'] as String).isEmpty || (data['id'] as String).length > 128 ||
        data['interruptedAt'] is! int || (data['interruptedAt'] as int) <= 0 ||
        data['checkpoint'] is! Map) return false;
    final checkpoint = MatchCheckpointCodec.decode(jsonEncode(data['checkpoint']));
    if (checkpoint == null || checkpoint['matchId'] != data['id']) return false;
    final snapshot = Map<String, dynamic>.from(checkpoint['snapshot'] as Map);
    return snapshot['matchWinner'] == null;
  }

  /// null means corrupt archive; never overwrite it by assuming it is empty.
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
      final result = decode(prefs.getString(key)) ?? [];
      result.sort((a, b) => (b['interruptedAt'] as int).compareTo(a['interruptedAt'] as int));
      return result;
    } catch (_) { return []; }
  }

  static Future<bool> save(SharedPreferences prefs, Map<String, dynamic> checkpoint) async {
    final id = checkpoint['matchId'];
    if (id is! String || id.isEmpty) return false;
    final modified = Map<String, dynamic>.from(checkpoint);
    final runtime = Map<String, dynamic>.from(checkpoint['runtime'] as Map);
    modified['runtime'] = {...runtime, 'isTimerRunning': false, 'breakSecondsLeft': 0, 'isBreakActive': false};
    final validated = MatchCheckpointCodec.decode(MatchCheckpointCodec.encode(modified));
    if (validated == null) return false;
    final record = {
      'version': 1, 'id': id,
      'interruptedAt': DateTime.now().millisecondsSinceEpoch,
      'checkpoint': validated,
    };
    if (!validRecord(record)) return false;
    final items = decode(prefs.getString(key));
    if (items == null) return false;
    if (items.any((e) => e['id'] == id)) return true;
    if (items.length >= maxMatches) return false;
    return prefs.setString(key, jsonEncode([record, ...items]));
  }

  static Future<bool> delete(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = decode(prefs.getString(key));
      if (items == null || !items.any((item) => item['id'] == id)) return false;
      return prefs.setString(key, jsonEncode(items.where((item) => item['id'] != id).toList()));
    } catch (_) { return false; }
  }
}
