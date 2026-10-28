import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/tournament_draw.dart';
import '../lib/services/tournament_store.dart';

Map<String, dynamic> tournament(int count, String format) => {
  'id': 't1', 'name': 'Coppa Test', 'format': format, 'venue': '',
  'date': '', 'createdAt': 123, 'entries': [
    for (var i = 0; i < count; i++) {
      'pairId': 'p${i + 1}', 'pairName': 'Squadra ${i + 1}',
      'playerIds': ['a$i', 'b$i'], 'playerNames': ['A$i', 'B$i'],
      'joinedAt': 123,
    },
  ],
};

List<List<int>> winA() => [[6, 4], [6, 3]];
List<List<int>> winB() => [[3, 6], [4, 6]];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('girone di quattro: tutte le sei sfide senza duplicati', () {
    final t = tournament(4, 'groups');
    var draw = TournamentDraw.create(t, timestamp: 100);
    final fixtures = draw['matches'] as List;
    expect((draw['groups'] as List).length, 1);
    expect(fixtures.length, 6);
    final couples = <String>{};
    for (final match in fixtures) {
      final sorted = [match['homeId'] as String, match['awayId'] as String]..sort();
      expect(couples.add(sorted.join(':')), isTrue);
    }
    draw = TournamentDraw.withResult(t, draw, fixtures.first['id'] as String, winA());
    final ranking = (TournamentDraw.standing((draw['groups'] as List).first,
        draw)['rows'] as List);
    expect(ranking.first['pairId'], fixtures.first['homeId']);
    expect(ranking.first['points'], 3);
    expect(ranking.first['wins'], 1);
    expect(ranking.first['setsFor'], 2);
    expect(ranking.first['gamesFor'], 12);
    expect(ranking.last['points'], 0);
  });

  test('gironi bilanciati, coppie univoche e tutti gli incontri', () {
    final t = tournament(7, 'groups');
    final draw = TournamentDraw.create(t, groupSize: 3, timestamp: 100);
    final groups = draw['groups'] as List;
    expect(groups.length, 3);
    expect(groups.map((g) => (g['pairIds'] as List).length).toList(), [3, 2, 2]);
    expect((draw['matches'] as List).length, 5);
    expect(groups.expand((g) => g['pairIds'] as List).toSet().length, 7);
    expect(() => TournamentDraw.create(t, groupSize: 5, timestamp: 100), throwsFormatException);
  });

  test('knockout 5 coppie: 8 slot, tre BYE, finale propagata', () {
    final t = tournament(5, 'knockout');
    var draw = TournamentDraw.create(t, timestamp: 100);
    final matches = draw['matches'] as List;
    expect(matches.length, 7);
    final first = matches.where((m) => m['round'] == 1).toList();
    expect(first.where((m) => TournamentDraw.isBye(m)).length, 3);
    expect(TournamentDraw.champion(draw), isNull);
    final firstPlayable = first.singleWhere((m) => !TournamentDraw.isBye(m));
    draw = TournamentDraw.withResult(t, draw,
        firstPlayable['id'] as String, winA());
    // Dopo il quarto di finale, sono definiti entrambi i semifinalisti.
    final semi = (draw['matches'] as List)
        .where((m) => m['round'] == 2).toList();
    expect(semi.every((m) => m['homeId'] != null && m['awayId'] != null), isTrue);
    for (final match in semi) {
      draw = TournamentDraw.withResult(t, draw, match['id'] as String, winA());
    }
    final finalMatch = (draw['matches'] as List).last;
    expect(finalMatch['homeId'], isNotNull);
    expect(finalMatch['awayId'], isNotNull);
    draw = TournamentDraw.withResult(t, draw, finalMatch['id'] as String, winB());
    expect(TournamentDraw.champion(draw), finalMatch['awayId']);
    expect(TournamentDraw.rebuild(t, draw), draw);
  });

  test('cambiare una semifinale annulla una finale dipendente', () {
    final t = tournament(4, 'knockout');
    var draw = TournamentDraw.create(t, timestamp: 100);
    for (final m in (draw['matches'] as List).where((m) => m['round'] == 1)) {
      draw = TournamentDraw.withResult(t, draw, m['id'] as String, winA());
    }
    final finalMatch = (draw['matches'] as List).last;
    draw = TournamentDraw.withResult(t, draw, finalMatch['id'] as String, winA());
    expect(TournamentDraw.champion(draw), isNotNull);
    draw = TournamentDraw.withResult(t, draw, 'K_R1_M1', winB());
    final revisedFinal = (draw['matches'] as List).last;
    expect(revisedFinal['homeId'], isNot(finalMatch['homeId']));
    expect(revisedFinal['result'], isNull);
    expect(TournamentDraw.champion(draw), isNull);
    draw = TournamentDraw.withResult(t, draw, 'K_R1_M1', null);
    expect((draw['matches'] as List).last['homeId'], isNull);
  });

  test('set inconsistenti e match incompleti non sono registrabili', () {
    final t = tournament(2, 'knockout');
    final draw = TournamentDraw.create(t, timestamp: 100);
    expect(TournamentDraw.validResult({'sets': [[6, 4], [6, 4]]}), isTrue);
    expect(TournamentDraw.validResult({'sets': [[6, 4], [4, 6], [10, 8]]}), isTrue);
    expect(TournamentDraw.validResult({'sets': [[6, 4], [6, 4], [6, 4]]}), isFalse);
    expect(TournamentDraw.validResult({'sets': [[6, 6], [6, 3]]}), isFalse);
    expect(TournamentDraw.validResult({'sets': [[6, 4], [4, 6]]}), isFalse);
    expect(() => TournamentDraw.withResult(t, draw, 'K_R1_M1', [[6, 6], [6, 4]]),
      throwsFormatException);
    expect(() => TournamentDraw.withResult(t, draw, 'non-esiste', winA()),
      throwsFormatException);
  });

  test('archivio 6A resta leggibile e calendario blocca le iscrizioni', () async {
    final oldTournament = tournament(4, 'groups');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TournamentStore.key,
      jsonEncode({'version': 1, 'tournaments': [oldTournament]}));
    expect((await TournamentStore.load())!['tournaments'], hasLength(1));
    expect(await TournamentStore.generateDraw('t1'), isNull);
    var saved = (await TournamentStore.load())!;
    var t = (saved['tournaments'] as List).single;
    expect(t['draw'], isNotNull);
    expect(await TournamentStore.generateDraw('t1'), isNotNull);
    expect(await TournamentStore.enroll('t1', 'new'), contains('Calendario'));
    expect(await TournamentStore.removeEntry('t1', 'p1'), contains('Calendario'));
    expect(await TournamentStore.update(id: 't1', name: 'Coppa',
        format: 'knockout'), contains('azzerare'));
    final fixture = (t['draw']['matches'] as List).first;
    expect(await TournamentStore.saveResult('t1', fixture['id'] as String, winA()), isNull);
    saved = (await TournamentStore.load())!;
    t = (saved['tournaments'] as List).single;
    expect((t['draw']['matches'] as List).first['result'], isNotNull);
    expect(await TournamentStore.resetDraw('t1'), isNull);
    t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect(t.containsKey('draw'), isFalse);
    expect((t['entries'] as List).length, 4);
  });

  test('un calendario manomesso non viene sovrascritto', () async {
    final prefs = await SharedPreferences.getInstance();
    final t = tournament(4, 'knockout');
    t['draw'] = TournamentDraw.create(t, timestamp: 100);
    final matches = t['draw']['matches'] as List;
    matches.first['homeId'] = 'sconosciuta';
    final raw = jsonEncode({'version': 1, 'tournaments': [t]});
    await prefs.setString(TournamentStore.key, raw);
    expect(await TournamentStore.load(), isNull);
    expect(await TournamentStore.generateDraw('t1'), isNotNull);
    expect(prefs.getString(TournamentStore.key), raw);
  });
}
