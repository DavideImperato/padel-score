import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_directory.dart';
import 'tournament_draw.dart';
import 'match_history.dart';
import 'tournament_match_link.dart';

/// Tornei locali in bozza (Fase 6A): iscrizioni senza generare incontri.
/// Le coppie iscritte sono snapshot: eliminazioni/rinomine in rubrica non
/// alterano i dati del torneo già salvati.
class TournamentStore {
  static const key = 'padel_tournaments_v1';
  static const maxTournaments = 50;
  static const maxPairsPerTournament = 32;
  static const formats = {'groups', 'knockout'};

  static Map<String, dynamic> empty() => {
    'version': 1,
    'tournaments': <dynamic>[],
  };

  static String normalize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
  static bool _name(dynamic s, int max) =>
      s is String && s.isNotEmpty && s.trim() == s && s.length <= max;
  static bool _id(dynamic s) => s is String && s.isNotEmpty && s.length <= 100;
  static bool _date(dynamic value) {
    if (value is! String) return false;
    if (value.isEmpty) return true;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' == value;
  }

  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null) return empty();
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1 || data['tournaments'] is! List) return null;
      final tournaments = data['tournaments'] as List;
      if (tournaments.length > maxTournaments) return null;
      final tourneyIds = <String>{};
      final tourneyNames = <String>{};
      for (final item in tournaments) {
        if (item is! Map || !_id(item['id']) || !_name(item['name'], 60) ||
            !formats.contains(item['format']) || item['venue'] is! String ||
            (item['venue'] as String).length > 100 ||
            !_date(item['date']) || item['createdAt'] is! int ||
            (item['createdAt'] as int) <= 0 || item['entries'] is! List) return null;
        if (!tourneyIds.add(item['id'] as String) ||
            !tourneyNames.add((item['name'] as String).toLowerCase())) return null;
        final linked = item['linkedResults'];
        if (linked != null && (linked is! Map || linked.length > 250 ||
            !linked.keys.every((key) => key is String && (key as String).isNotEmpty) ||
            !linked.values.every((id) => id is String && (id as String).isNotEmpty && id.length <= 128))) return null;
        final draw = item['draw'];
        if (draw != null) {
          if (draw is! Map || draw['version'] != 1) return null;
          try {
            final canonical = TournamentDraw.rebuild(
                Map<String, dynamic>.from(item), draw);
            if (jsonEncode(canonical) != jsonEncode(draw)) return null;
          } catch (_) { return null; }
        }
        final entries = item['entries'] as List;
        if (entries.length > maxPairsPerTournament) return null;
        final pairIds = <String>{};
        final playerIds = <String>{};
        for (final entry in entries) {
          if (entry is! Map || !_id(entry['pairId']) ||
              !_name(entry['pairName'], 60) || entry['playerIds'] is! List ||
              entry['playerNames'] is! List || entry['joinedAt'] is! int ||
              (entry['joinedAt'] as int) <= 0) return null;
          final ids = entry['playerIds'] as List;
          final names = entry['playerNames'] as List;
          if (ids.length != 2 || names.length != 2 ||
              !ids.every(_id) || !names.every((v) => _name(v, 60)) ||
              ids[0] == ids[1] || !pairIds.add(entry['pairId'] as String)) return null;
          for (final id in ids) {
            if (!playerIds.add(id as String)) return null;
          }
        }
      }
      // Round-trip gives fresh maps so caller cannot mutate persisted state.
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
    } catch (_) { return null; }
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(key));
    } catch (_) { return null; }
  }

  static int _serial = 0;
  static String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${++_serial}';

  // Serializza le mutazioni asincrone per non perdere due iscrizioni ravvicinate.
  static Future<void> _queue = Future<void>.value();
  static Future<String?> _change(Future<String?> Function(Map<String, dynamic>) modify) {
    final pending = _queue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = decode(prefs.getString(key));
        if (data == null) return 'Archivio tornei non leggibile: nessun dato sovrascritto.';
        final error = await modify(data);
        if (error != null) return error;
        final encoded = jsonEncode(data);
        if (decode(encoded) == null) return 'Dati torneo non validi.';
        if (!await prefs.setString(key, encoded)) return 'Salvataggio torneo non riuscito.';
        return null;
      } catch (_) { return 'Memoria locale non disponibile.'; }
    });
    _queue = pending.then<void>((_) {}, onError: (Object _) {});
    return pending;
  }

  static String? _validate(String title, String venue, String date, String format) {
    if (!_name(title, 60)) return 'Inserisci un nome (massimo 60 caratteri).';
    if (venue.length > 100) return 'Luogo troppo lungo (massimo 100 caratteri).';
    if (!_date(date)) return 'Data non valida.';
    if (!formats.contains(format)) return 'Formato non valido.';
    return null;
  }

  static Future<String?> create({required String name, required String format,
      String venue = '', String date = ''}) => _change((data) async {
    final title = normalize(name);
    final location = normalize(venue);
    final error = _validate(title, location, date, format);
    if (error != null) return error;
    final tournaments = data['tournaments'] as List;
    if (tournaments.length >= maxTournaments) return 'Limite tornei raggiunto.';
    if (tournaments.any((t) => (t['name'] as String).toLowerCase() == title.toLowerCase())) {
      return 'Esiste già un torneo con questo nome.';
    }
    tournaments.add({
      'id': _newId(), 'name': title, 'format': format,
      'venue': location, 'date': date,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'entries': <dynamic>[],
    });
    return null;
  });

  static Future<String?> update({required String id, required String name,
      required String format, String venue = '', String date = ''}) => _change((data) async {
    final title = normalize(name);
    final location = normalize(venue);
    final error = _validate(title, location, date, format);
    if (error != null) return error;
    final tournaments = data['tournaments'] as List;
    final index = tournaments.indexWhere((t) => t['id'] == id);
    if (index < 0) return 'Torneo non trovato.';
    if (tournaments.any((t) => t['id'] != id &&
        (t['name'] as String).toLowerCase() == title.toLowerCase())) {
      return 'Esiste già un torneo con questo nome.';
    }
    final record = tournaments[index] as Map;
    if (record['draw'] != null && format != record['format']) {
      return 'Per cambiare formula devi prima azzerare il calendario.';
    }
    record['name'] = title;
    record['venue'] = location;
    record['date'] = date;
    record['format'] = format;
    return null;
  });

  static Future<String?> delete(String id) => _change((data) async {
    final tournaments = data['tournaments'] as List;
    if (!tournaments.any((t) => t['id'] == id)) return 'Torneo non trovato.';
    tournaments.removeWhere((t) => t['id'] == id);
    return null;
  });

  static Future<String?> enroll(String tournamentId, String pairId) => _change((data) async {
    final tournaments = data['tournaments'] as List;
    final index = tournaments.indexWhere((t) => t['id'] == tournamentId);
    if (index < 0) return 'Torneo non trovato.';
    if (tournaments[index]['draw'] != null) {
      return 'Calendario già generato: azzeralo per cambiare le iscrizioni.';
    }
    final entries = tournaments[index]['entries'] as List;
    if (entries.length >= maxPairsPerTournament) return 'Massimo 32 coppie per torneo.';
    if (entries.any((e) => e['pairId'] == pairId)) return 'Coppia già iscritta.';
    final directory = await PlayerDirectoryStore.load();
    if (directory == null) return 'Rubrica non leggibile: non è stata modificata.';
    final pairs = directory['pairs'] as List;
    final match = pairs.where((p) => p['id'] == pairId);
    if (match.isEmpty) return 'Coppia non trovata nella rubrica.';
    final pair = match.first as Map;
    final ids = List<String>.from(pair['playerIds'] as List);
    final existing = <String>{};
    for (final entry in entries) {
      existing.addAll(List<String>.from(entry['playerIds'] as List));
    }
    if (ids.any(existing.contains)) return 'Un giocatore è già iscritto con un’altra coppia.';
    final players = directory['players'] as List;
    final names = <String>[];
    for (final id in ids) {
      final player = players.where((p) => p['id'] == id);
      if (player.isEmpty) return 'Giocatore non trovato nella rubrica.';
      names.add(player.first['name'] as String);
    }
    entries.add({
      'pairId': pairId, 'pairName': pair['name'], 'playerIds': ids,
      'playerNames': names, 'joinedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return null;
  });

  static Future<String?> removeEntry(String tournamentId, String pairId) => _change((data) async {
    final tournaments = data['tournaments'] as List;
    final match = tournaments.where((t) => t['id'] == tournamentId);
    if (match.isEmpty) return 'Torneo non trovato.';
    if (match.first['draw'] != null) {
      return 'Calendario già generato: azzeralo per cambiare le iscrizioni.';
    }
    final entries = match.first['entries'] as List;
    if (!entries.any((e) => e['pairId'] == pairId)) return 'Coppia non iscritta.';
    entries.removeWhere((e) => e['pairId'] == pairId);
    return null;
  });
  /// Avvia il calendario soltanto dopo la chiusura delle iscrizioni.
  static Future<String?> generateDraw(String id, {int groupSize = 4}) =>
      _change((data) async {
    final tournaments = data['tournaments'] as List;
    final matches = tournaments.where((t) => t['id'] == id);
    if (matches.isEmpty) return 'Torneo non trovato.';
    final tournament = matches.first as Map<String, dynamic>;
    if (tournament['draw'] != null) return 'Calendario già creato.';
    try {
      tournament['draw'] = TournamentDraw.create(tournament, groupSize: groupSize);
    } on FormatException catch (e) { return e.message; }
    return null;
  });

  /// Tutti i risultati e gli abbinamenti vengono eliminati con conferma UI.
  static Future<String?> resetDraw(String id) => _change((data) async {
    final tournaments = data['tournaments'] as List;
    final matches = tournaments.where((t) => t['id'] == id);
    if (matches.isEmpty) return 'Torneo non trovato.';
    final tournament = matches.first as Map;
    if (tournament['draw'] == null) return 'Nessun calendario da azzerare.';
    tournament.remove('draw');
    tournament.remove('linkedResults');
    return null;
  });

  /// Imposta o corregge un risultato; i turni dipendenti vengono ricalcolati.
  static Future<String?> saveResult(String id, String matchId,
      List<List<int>>? sets) => _change((data) async {
    final tournaments = data['tournaments'] as List;
    final matches = tournaments.where((t) => t['id'] == id);
    if (matches.isEmpty) return 'Torneo non trovato.';
    final tournament = matches.first as Map<String, dynamic>;
    final draw = tournament['draw'];
    if (draw is! Map) return 'Genera prima il calendario.';
    try {
      tournament['draw'] = TournamentDraw.withResult(tournament, draw,
          matchId, sets);
    } on FormatException catch (e) { return e.message; }
    return null;
  });

  /// Importa un match solo se identificatori e avversari coincidono con lo
  /// slot attuale. Mai sovrascrivere un risultato inserito manualmente.
  /// Un registro persistente evita doppie importazioni anche dopo un riavvio.
  static Future<String?> applyFinishedRecord(Map<String, dynamic> record) {
    final link = record['tournamentLink'];
    if (!TournamentMatchLink.valid(link) || !MatchHistoryStore.validRecord(record)) {
      return Future.value('Risultato collegato al torneo non valido.');
    }
    final metadata = Map<String, dynamic>.from(link as Map);
    final sets = <List<int>>[];
    for (final raw in record['sets'] as List) {
      final set = raw as Map;
      if (set['isMatchTieBreak'] == true) {
        if (set['tieBreakPointsA'] is! int || set['tieBreakPointsB'] is! int) {
          return Future.value('Punteggio match tie-break non disponibile.');
        }
        sets.add([set['tieBreakPointsA'] as int, set['tieBreakPointsB'] as int]);
      } else {
        sets.add([set['gamesA'] as int, set['gamesB'] as int]);
      }
    }
    if (!TournamentDraw.validResult({'sets': sets})) {
      return Future.value('Set non compatibili col torneo: risultato conservato nello Storico.');
    }
    return _change((data) async {
      final tournaments = data['tournaments'] as List;
      final matching = tournaments.where((t) => t['id'] == metadata['tournamentId']);
      if (matching.isEmpty) return 'Il torneo originario non esiste più.';
      final tournament = matching.first as Map<String, dynamic>;
      final draw = tournament['draw'];
      if (draw is! Map || draw['createdAt'] != metadata['drawCreatedAt']) {
        return 'Il calendario del torneo è stato ricreato: risultato non importato.';
      }
      final fixtures = (draw['matches'] as List).where((m) => m['id'] == metadata['fixtureId']);
      if (fixtures.isEmpty) return 'L’incontro non è più nel calendario.';
      final fixture = fixtures.first as Map;
      if (fixture['homeId'] != metadata['homeId'] ||
          fixture['awayId'] != metadata['awayId']) {
        return 'Le coppie dell’incontro sono cambiate: risultato non importato.';
      }
      final tracked = Map<String, dynamic>.from(tournament['linkedResults'] as Map? ?? {});
      final prior = tracked[metadata['fixtureId']];
      if (prior == record['id']) return null; // idempotenza
      if (fixture['result'] != null) {
        return 'L’incontro ha già un risultato: nessuna sovrascrittura.';
      }
      try {
        tournament['draw'] = TournamentDraw.withResult(tournament, draw,
            metadata['fixtureId'] as String, sets);
      } on FormatException catch (e) { return e.message; }
      tracked[metadata['fixtureId'] as String] = record['id'] as String;
      tournament['linkedResults'] = tracked;
      return null;
    });
  }

  /// Recupera archiviazioni iPhone completate prima del salvataggio del torneo
  /// (es. chiusura improvvisa dell'app). Le correzioni manuali rimangono intatte.
  static Future<void> reconcileFinishedMatches(String tournamentId) async {
    final data = await load();
    if (data == null) return;
    final matches = (data['tournaments'] as List).where((t) => t['id'] == tournamentId);
    if (matches.isEmpty) return;
    final tournament = matches.first as Map;
    if (tournament['draw'] is! Map) return;
    final alreadyLinked = Map<String, dynamic>.from(tournament['linkedResults'] as Map? ?? {});
    final fixtures = (tournament['draw']['matches'] as List);
    final history = await MatchHistoryStore.load();
    for (final record in history) {
      final link = record['tournamentLink'];
      if (!TournamentMatchLink.valid(link) || link['tournamentId'] != tournamentId) continue;
      if (alreadyLinked.containsKey(link['fixtureId'])) continue;
      if ((tournament['draw'] as Map)['createdAt'] != link['drawCreatedAt']) continue;
      if (!fixtures.any((m) => m['id'] == link['fixtureId'] && m['result'] == null &&
          m['homeId'] == link['homeId'] && m['awayId'] == link['awayId'])) continue;
      final error = await applyFinishedRecord(record);
      if (error == null) alreadyLinked[link['fixtureId'] as String] = record['id'];
    }
  }

}
