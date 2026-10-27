import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Rubrica indipendente dal salvataggio delle partite; nessuna sincronizzazione online.
class PlayerDirectoryStore {
  static const key = 'padel_player_directory_v1';
  static const maxPlayers = 150;
  static const maxPairs = 150;

  static Map<String, dynamic> empty() => {'version': 1, 'players': <dynamic>[], 'pairs': <dynamic>[]};
  static String _normalized(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  static bool _validName(dynamic v) => v is String && v.trim().isNotEmpty && v.length <= 60;
  static bool _validId(dynamic v) => v is String && v.isNotEmpty && v.length <= 100;

  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null) return empty();
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1 || data['players'] is! List || data['pairs'] is! List) return null;
      final players = data['players'] as List;
      final pairs = data['pairs'] as List;
      if (players.length > maxPlayers || pairs.length > maxPairs) return null;
      if (!players.every((p) => p is Map && _validId(p['id']) && _validName(p['name']) && p['createdAt'] is int && p['createdAt'] > 0)) return null;
      final ids = players.map((p) => p['id'] as String).toSet();
      if (ids.length != players.length || players.map((p) => _normalized(p['name'] as String)).toSet().length != players.length) return null;
      if (!pairs.every((p) => p is Map && _validId(p['id']) && _validName(p['name']) && p['createdAt'] is int && p['createdAt'] > 0 && p['playerIds'] is List && (p['playerIds'] as List).length == 2 && p['playerIds'][0] != p['playerIds'][1] && ids.contains(p['playerIds'][0]) && ids.contains(p['playerIds'][1]))) return null;
      final pairIds = pairs.map((p) => p['id'] as String).toSet();
      final compositions = pairs.map((p) => ((p['playerIds'] as List).cast<String>().toList()..sort()).join('|')).toSet();
      if (pairIds.length != pairs.length || compositions.length != pairs.length) return null;
      return {'version': 1, 'players': players.map((p) => Map<String, dynamic>.from(p as Map)).toList(), 'pairs': pairs.map((p) => Map<String, dynamic>.from(p as Map)).toList()};
    } catch (_) { return null; }
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(key));
    } catch (_) { return null; }
  }

  static String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().hashCode}';

  static Future<String?> addPlayer(String name) => _change((d) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final players = d['players'] as List;
    if (!_validName(clean)) return 'Nome non valido (massimo 60 caratteri).';
    if (players.length >= maxPlayers) return 'Limite giocatori raggiunto.';
    if (players.any((p) => _normalized(p['name'] as String) == _normalized(clean))) return 'Giocatore già presente.';
    players.add({'id': _newId(), 'name': clean, 'createdAt': DateTime.now().millisecondsSinceEpoch});
    return null;
  });

  static Future<String?> renamePlayer(String id, String name) => _change((d) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final players = d['players'] as List;
    if (!_validName(clean)) return 'Nome non valido.';
    if (players.any((p) => p['id'] != id && _normalized(p['name'] as String) == _normalized(clean))) return 'Nome già presente.';
    final index = players.indexWhere((p) => p['id'] == id);
    if (index < 0) return 'Giocatore non trovato.';
    players[index]['name'] = clean;
    return null;
  });

  static Future<String?> removePlayer(String id) => _change((d) {
    final players = d['players'] as List;
    if (!players.any((p) => p['id'] == id)) return 'Giocatore non trovato.';
    if ((d['pairs'] as List).any((p) => (p['playerIds'] as List).contains(id))) return 'Elimina prima le coppie del giocatore.';
    players.removeWhere((p) => p['id'] == id);
    return null;
  });

  static Future<String?> addPair(String name, String first, String second) => _change((d) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final players = d['players'] as List;
    final pairs = d['pairs'] as List;
    if (!_validName(clean)) return 'Nome coppia non valido.';
    if (pairs.length >= maxPairs) return 'Limite coppie raggiunto.';
    if (first == second || !players.any((p) => p['id'] == first) || !players.any((p) => p['id'] == second)) return 'Seleziona due giocatori diversi.';
    if (pairs.any((p) => (p['playerIds'] as List).contains(first) && (p['playerIds'] as List).contains(second))) return 'Coppia già presente.';
    pairs.add({'id': _newId(), 'name': clean, 'playerIds': [first, second], 'createdAt': DateTime.now().millisecondsSinceEpoch});
    return null;
  });

  static Future<String?> removePair(String id) => _change((d) {
    final pairs = d['pairs'] as List;
    if (!pairs.any((p) => p['id'] == id)) return 'Coppia non trovata.';
    pairs.removeWhere((p) => p['id'] == id);
    return null;
  });

  /// null indica successo, altrimenti messaggio d'errore. Archivio corrotto non sovrascritto.
  static Future<String?> _change(String? Function(Map<String, dynamic>) apply) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = decode(prefs.getString(key));
      if (data == null) return 'Archivio non leggibile: nessuna modifica effettuata.';
      final err = apply(data);
      if (err != null) return err;
      if (decode(jsonEncode(data)) == null) return 'Dati non validi.';
      if (!await prefs.setString(key, jsonEncode(data))) return 'Salvataggio non riuscito.';
      return null;
    } catch (_) { return 'Memoria locale non disponibile.'; }
  }
}
