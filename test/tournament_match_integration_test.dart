import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/models/padel_match_state.dart';
import '../lib/providers/padel_score_provider.dart';
import '../lib/services/match_checkpoint.dart';
import '../lib/services/match_history.dart';
import '../lib/services/tournament_draw.dart';
import '../lib/services/tournament_match_link.dart';
import '../lib/services/tournament_store.dart';
import 'support/fake_tts_service.dart';

Map<String, dynamic> _tournament() => {
  'id': 't1', 'name': 'Test torneo', 'format': 'knockout',
  'venue': '', 'date': '', 'createdAt': 123,
  'entries': [
    {'pairId': 'p1', 'pairName': 'Alfa', 'playerIds': ['a1', 'a2'],
     'playerNames': ['Anna', 'Arianna'], 'joinedAt': 123},
    {'pairId': 'p2', 'pairName': 'Beta', 'playerIds': ['b1', 'b2'],
     'playerNames': ['Bruno', 'Biagio'], 'joinedAt': 123},
  ],
};

Future<Map<String, dynamic>> _createTournament() async {
  final prefs = await SharedPreferences.getInstance();
  final t = _tournament();
  t['draw'] = TournamentDraw.create(t, timestamp: 123);
  await prefs.setString(TournamentStore.key,
      jsonEncode({'version': 1, 'tournaments': [t]}));
  return t;
}

Map<String, dynamic> _link() => TournamentMatchLink.build(
  tournamentId: 't1', fixtureId: 'K_R1_M1', homeId: 'p1', awayId: 'p2', drawCreatedAt: 123);

Map<String, dynamic> _record({String id = 'history-1',
    Map<String, dynamic>? link}) => {
  'version': 1, 'id': id, 'completedAt': 12345,
  'durationSeconds': 120,
  'teamAName': 'Alfa', 'teamBName': 'Beta',
  'players': ['Anna', 'Arianna', 'Bruno', 'Biagio'],
  'playerIds': ['a1', 'a2', 'b1', 'b2'],
  'winner': 'teamA',
  'sets': [
    {'gamesA': 6, 'gamesB': 4, 'isCompleted': true,
      'isMatchTieBreak': false, 'winner': 'teamA',
      'tieBreakPointsA': null, 'tieBreakPointsB': null},
    {'gamesA': 6, 'gamesB': 3, 'isCompleted': true,
      'isMatchTieBreak': false, 'winner': 'teamA',
      'tieBreakPointsA': null, 'tieBreakPointsB': null},
  ],
  'bestOfSets': 3, 'gamesPerSet': 6,
  'tournamentLink': link ?? _link(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('importa il risultato giocato, aggiorna il tabellone ed è idempotente', () async {
    await _createTournament();
    final record = _record();
    expect(MatchHistoryStore.validRecord(record), true);
    expect(await TournamentStore.applyFinishedRecord(record), isNull);
    expect(await TournamentStore.applyFinishedRecord(record), isNull);
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect(t['linkedResults']['K_R1_M1'], 'history-1');
    final match = (t['draw']['matches'] as List).single;
    expect(match['result']['sets'], [[6, 4], [6, 3]]);
    expect(TournamentDraw.champion(t['draw']), 'p1');
  });

  test('non sovrascrive un risultato inserito manualmente', () async {
    await _createTournament();
    expect(await TournamentStore.saveResult('t1', 'K_R1_M1', [[4, 6], [3, 6]]), isNull);
    expect(await TournamentStore.applyFinishedRecord(_record()), contains('già un risultato'));
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect(TournamentDraw.champion(t['draw']), 'p2');
  });

  test('non importa in un incontro con coppie o identificatori diversi', () async {
    await _createTournament();
    final incorrect = _record(link: TournamentMatchLink.build(
        tournamentId: 't1', fixtureId: 'K_R1_M1',
        homeId: 'p2', awayId: 'p1', drawCreatedAt: 123));
    expect(await TournamentStore.applyFinishedRecord(incorrect), contains('cambiate'));
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect((t['draw']['matches'] as List).single['result'], isNull);
  });

  test('riconcilia risultato dallo storico dopo un salvataggio interrotto', () async {
    await _createTournament();
    final prefs = await SharedPreferences.getInstance();
    expect(await MatchHistoryStore.saveRecord(prefs, _record()), true);
    await TournamentStore.reconcileFinishedMatches('t1');
    await TournamentStore.reconcileFinishedMatches('t1');
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect((t['draw']['matches'] as List).single['result'], isNotNull);
    expect(t['linkedResults'].length, 1);
    // Una correzione manuale non viene ripristinata automaticamente.
    expect(await TournamentStore.saveResult('t1', 'K_R1_M1', null), isNull);
    await TournamentStore.reconcileFinishedMatches('t1');
    final updated = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect((updated['draw']['matches'] as List).single['result'], isNull);
  });

  test('dopo rigenerazione del calendario un vecchio match non è importato', () async {
    await _createTournament();
    expect(await TournamentStore.resetDraw('t1'), isNull);
    // Il nuovo calendario ha un identificativo temporale diverso.
    expect(await TournamentStore.generateDraw('t1'), isNull);
    final imported = await TournamentStore.applyFinishedRecord(_record());
    expect(imported, contains('ricreato'));
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect((t['draw']['matches'] as List).single['result'], isNull);
  });

  test('record non completato o senza identificatori validi non è importato', () async {
    await _createTournament();
    final incomplete = _record();
    incomplete['sets'] = [incomplete['sets'][0]];
    expect(await TournamentStore.applyFinishedRecord(incomplete), isNotNull);
    final malformed = _record(link: {'tournamentId': 't1'});
    expect(await TournamentStore.applyFinishedRecord(malformed), isNotNull);
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect((t['draw']['matches'] as List).single['result'], isNull);
  });

  test('provider salva link nel checkpoint, lo ripristina e archivia nel torneo', () async {
    await _createTournament();
    final provider = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    provider.setupMatch(team1: 'Alfa', team2: 'Beta',
      player1: 'Anna', player2: 'Arianna', player3: 'Bruno', player4: 'Biagio',
      firstServerPlayerId: 1, goldenPoint: true, bestOfSets: 3,
      playerIds: ['a1', 'a2', 'b1', 'b2'], tournamentLink: _link());
    provider.addPoint(Team.teamA);
    await provider.flushCheckpoint();
    final prefs = await SharedPreferences.getInstance();
    final checkpoint = MatchCheckpointCodec.decode(prefs.getString(MatchCheckpointCodec.key));
    expect(checkpoint?['tournamentLink'], _link());
    provider.dispose();

    final restored = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(restored.resumeSavedMatch(), true);
    expect(restored.tournamentLink, _link());
    // Il primo punto era già stato salvato; ne servono altri 47 per il 6-0 6-0.
    for (var i = 0; i < 47; i++) {
      restored.addPoint(Team.teamA);
    }
    expect(restored.isMatchOver, true);
    expect(await restored.archiveFinishedMatch(), true);
    expect(restored.lastTournamentSyncError, isNull);
    final results = await MatchHistoryStore.load();
    expect(results.single['tournamentLink'], _link());
    final t = ((await TournamentStore.load())!['tournaments'] as List).single;
    expect((t['draw']['matches'] as List).single['result']['sets'], [[6, 0], [6, 0]]);
    restored.dispose();
  });
}
