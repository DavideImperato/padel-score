import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/player_directory.dart';
import '../lib/services/tournament_store.dart';

Future<String> createPair(String pairName, String a, String b) async {
  expect(await PlayerDirectoryStore.addPair(pairName, a, b), isNull);
  final directory = (await PlayerDirectoryStore.load())!;
  return (directory['pairs'] as List).firstWhere((p) => p['name'] == pairName)['id'] as String;
}

Future<String> createTournament(String title) async {
  expect(await TournamentStore.create(name: title, format: 'groups', venue: '  Club  Padel  '), isNull);
  final store = (await TournamentStore.load())!;
  return (store['tournaments'] as List).firstWhere((t) => t['name'] == title)['id'] as String;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creazione, persistenza, dati opzionali e nomi unici', () async {
    expect((await TournamentStore.load())!['tournaments'], isEmpty);
    final id = await createTournament('Torneo Estivo');
    expect(await TournamentStore.create(name: 'torneo estivo', format: 'knockout'), isNotNull);
    expect(await TournamentStore.create(name: '  ', format: 'groups'), isNotNull);
    expect(await TournamentStore.create(name: 'Un altro', format: 'altro'), isNotNull);
    expect(await TournamentStore.create(name: 'Altro', format: 'groups', date: '2026-02-30'), isNotNull);
    expect(await TournamentStore.update(id: id, name: 'Torneo Autunno', format: 'knockout', date: '2026-10-29', venue: 'Centro'), isNull);
    final record = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect(record['name'], 'Torneo Autunno');
    expect(record['format'], 'knockout');
    expect(record['date'], '2026-10-29');
    expect(await TournamentStore.delete(id), isNull);
    expect((await TournamentStore.load())!['tournaments'], isEmpty);
  });

  test('iscrizioni offline, coppie non duplicate e snapshot dei nomi', () async {
    expect(await PlayerDirectoryStore.addPlayer('Andrea'), isNull);
    expect(await PlayerDirectoryStore.addPlayer('Luca'), isNull);
    final players = (await PlayerDirectoryStore.load())!['players'] as List;
    final a = players[0]['id'] as String;
    final b = players[1]['id'] as String;
    final pairId = await createPair('I Razzi', a, b);
    final tournamentId = await createTournament('Torneo Comune');
    expect(await TournamentStore.enroll(tournamentId, pairId), isNull);
    expect(await TournamentStore.enroll(tournamentId, pairId), isNotNull);
    expect(await PlayerDirectoryStore.renamePlayer(a, 'Andrea 2'), isNull);
    expect(await PlayerDirectoryStore.removePair(pairId), isNull);
    final entry = (((await TournamentStore.load())!['tournaments'] as List).single['entries'] as List).single;
    expect(entry['playerNames'], ['Andrea', 'Luca']);
    expect(entry['pairName'], 'I Razzi');
    expect(await TournamentStore.removeEntry(tournamentId, pairId), isNull);
    expect(await TournamentStore.removeEntry(tournamentId, pairId), isNotNull);
    expect(await TournamentStore.enroll(tournamentId, pairId), isNotNull);
  });

  test('un giocatore non può iscriversi con due coppie nello stesso torneo', () async {
    for (final name in ['A', 'B', 'C', 'D']) {
      expect(await PlayerDirectoryStore.addPlayer(name), isNull);
    }
    final players = (await PlayerDirectoryStore.load())!['players'] as List;
    final ids = players.map((p) => p['id'] as String).toList();
    final ab = await createPair('AB', ids[0], ids[1]);
    final ac = await createPair('AC', ids[0], ids[2]);
    final cd = await createPair('CD', ids[2], ids[3]);
    final t1 = await createTournament('Prima Coppa');
    final t2 = await createTournament('Seconda Coppa');
    expect(await TournamentStore.enroll(t1, ab), isNull);
    expect(await TournamentStore.enroll(t1, ac), contains('già iscritto'));
    expect(await TournamentStore.enroll(t1, cd), isNull);
    expect(await TournamentStore.enroll(t2, ac), isNull);
    expect((((await TournamentStore.load())!['tournaments'] as List)
        .firstWhere((t) => t['id'] == t1)['entries'] as List).length, 2);
  });

  test('due iscrizioni simultanee non si sovrascrivono', () async {
    for (final name in ['A', 'B', 'C', 'D']) {
      expect(await PlayerDirectoryStore.addPlayer(name), isNull);
    }
    final ids = ((await PlayerDirectoryStore.load())!['players'] as List)
        .map((p) => p['id'] as String).toList();
    final ab = await createPair('Team AB', ids[0], ids[1]);
    final cd = await createPair('Team CD', ids[2], ids[3]);
    final id = await createTournament('Torneo Contemporaneo');
    final results = await Future.wait([
      TournamentStore.enroll(id, ab), TournamentStore.enroll(id, cd),
    ]);
    expect(results, [null, null]);
    expect(((((await TournamentStore.load())!['tournaments'] as List).single)['entries'] as List).length, 2);
  });

  test('archivio malformato o con partecipanti sovrapposti non si sovrascrive', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TournamentStore.key, '{non-json');
    expect(await TournamentStore.load(), isNull);
    expect(await TournamentStore.create(name: 'Tentativo', format: 'groups'), isNotNull);
    expect(prefs.getString(TournamentStore.key), '{non-json');
    final duplicated = {
      'version': 1,
      'tournaments': [{
        'id': '1', 'name': 'Campionato', 'format': 'groups', 'venue': '', 'date': '',
        'createdAt': 1, 'entries': [
          {'pairId': 'p1', 'pairName': 'Uno', 'playerIds': ['a', 'b'], 'playerNames': ['A', 'B'], 'joinedAt': 1},
          {'pairId': 'p2', 'pairName': 'Due', 'playerIds': ['a', 'c'], 'playerNames': ['A', 'C'], 'joinedAt': 1},
        ],
      }],
    };
    expect(TournamentStore.decode(jsonEncode(duplicated)), isNull);
    expect(TournamentStore.decode(jsonEncode(TournamentStore.empty())), isNotNull);
  });
}
