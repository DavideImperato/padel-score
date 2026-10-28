import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/match_checkpoint.dart';
import 'package:padel_scorebot/services/match_history.dart';
import 'package:padel_scorebot/services/match_point_analytics.dart';
import 'support/fake_tts_service.dart';

PadelScoreProvider _newProvider() =>
    PadelScoreProvider(ttsService: FakeTtsService());

void _setup(PadelScoreProvider provider, {int bestOfSets = 1}) {
  provider.setupMatch(team1: 'A', team2: 'B', player1: 'A1',
    player2: 'A2', player3: 'B1', player4: 'B2',
    firstServerPlayerId: 1, goldenPoint: true, bestOfSets: bestOfSets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Punti da più sorgenti: registro singolo, ordine e Undo', () async {
    SharedPreferences.setMockInitialValues({});
    final p = _newProvider();
    await Future<void>.delayed(Duration.zero);
    _setup(p);
    p.addPoint(Team.teamA); // schermata
    final reply = await p.handleWatchCommand({
      'commandId': 'watch-pt-01', 'matchId': p.watchMatchId, 'action': 'point_b',
    }); // watch
    expect(reply['ok'], true);
    p.addPoint(Team.teamA); // Bluetooth (stesso ingresso)
    expect(p.pointEvents.map((e) => e['team']).toList(),
      ['teamA', 'teamB', 'teamA']);
    expect(p.pointEvents.map((e) => e['index']).toList(), [1, 2, 3]);
    expect(p.pointEvents.first['occurredAt'], greaterThan(0));
    final duplicated = await p.handleWatchCommand({
      'commandId': 'watch-pt-01', 'matchId': p.watchMatchId, 'action': 'point_b',
    });
    expect(duplicated['duplicate'], true);
    expect(p.pointEvents.length, 3);
    p.undo();
    expect(p.pointEvents.length, 2);
    expect(p.snapshot.displayPointA, '15');
    p.dispose();
  });

  test('Undo di solo cambio battitore non cancella un punto', () async {
    SharedPreferences.setMockInitialValues({});
    final p = _newProvider();
    await Future<void>.delayed(Duration.zero);
    _setup(p);
    p.addPoint(Team.teamA);
    p.toggleServingTeam();
    p.undo();
    expect(p.pointEvents.length, 1);
    p.undo();
    expect(p.pointEvents, isEmpty);
    p.dispose();
  });

  test('Checkpoint mantiene eventi; recupero riprende la stessa cronologia', () async {
    SharedPreferences.setMockInitialValues({});
    final p = _newProvider();
    await Future<void>.delayed(Duration.zero);
    _setup(p);
    p.addPoint(Team.teamA);
    p.addPoint(Team.teamB);
    p.updateClock(14, true);
    p.addPoint(Team.teamB);
    await p.flushCheckpoint();
    final prefs = await SharedPreferences.getInstance();
    final checkpoint = MatchCheckpointCodec.decode(prefs.getString(MatchCheckpointCodec.key));
    expect(checkpoint, isNotNull);
    expect(MatchPointAnalytics.decode(checkpoint!['pointEvents'])?.length, 3);
    p.dispose();
    final restored = _newProvider();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(restored.resumeSavedMatch(), true);
    expect(restored.pointEvents.length, 3);
    restored.undo();
    expect(restored.pointEvents.length, 2);
    restored.addPoint(Team.teamA);
    expect(restored.pointEvents.map((e) => e['index']).toList(), [1, 2, 3]);
    restored.dispose();
  });

  test('Punto d’oro riconosciuto e statistiche calcolate dagli eventi', () async {
    SharedPreferences.setMockInitialValues({});
    final p = _newProvider();
    await Future<void>.delayed(Duration.zero);
    _setup(p);
    for (var i = 0; i < 3; i++) { p.addPoint(Team.teamA); p.addPoint(Team.teamB); }
    p.addPoint(Team.teamA);
    expect(p.pointEvents.length, 7);
    expect(p.pointEvents.last['isGoldenPoint'], true);
    expect(p.pointEvents.last['gameWon'], true);
    final record = MatchHistoryStore.buildRecord(
      id: 'analytics-fixture', snapshot: p.snapshot.copyWith(matchWinner: Team.teamA),
      durationSeconds: 90, teamAName: 'A', teamBName: 'B',
      players: ['A1', 'A2', 'B1', 'B2'], bestOfSets: 1,
      gamesPerSet: 6, completedAt: 100, pointEvents: p.pointEvents);
    // A record with missing completed sets is invalid, but the pure analytics
    // engine can still compute reliable events independently of archive status.
    expect(MatchHistoryStore.validRecord(record), false);
    final stats = MatchPointAnalytics.fromRecord(record)!;
    expect(stats['pointsA'], 4);
    expect(stats['pointsB'], 3);
    expect(stats['goldenPointsA'], 1);
    expect(stats['gamesWonA'], 1);
    expect((stats['timeline'] as List).length, 8);
    expect((stats['lastTen'] as List).length, 7);
    p.dispose();
  });

  test('Partita conclusa archivia eventi, Undo non conta due volte', () async {
    SharedPreferences.setMockInitialValues({});
    final p = _newProvider();
    await Future<void>.delayed(Duration.zero);
    _setup(p);
    for (var i = 0; i < 24; i++) { p.addPoint(Team.teamA); }
    expect(p.isMatchOver, true);
    expect(p.pointEvents.length, 24);
    expect(p.pointEvents.last['matchWon'], true);
    expect(await p.archiveFinishedMatch(), true);
    final records = await MatchHistoryStore.load();
    expect(records.length, 1);
    final stored = records.first;
    expect(MatchHistoryStore.validRecord(stored), true);
    expect((stored['pointEvents'] as List).length, 24);
    final stats = MatchPointAnalytics.fromRecord(stored)!;
    expect(stats['pointsA'], 24);
    expect(stats['gamesWonA'], 6);
    expect(stats['longestStreakA'], 24);
    expect(stats['breakGamesA'], 3);
    expect(stats['pointShareA'], 100.0);
    p.dispose();
  });

  test('Archivio legacy compatibile, dati malformati rifiutati', () {
    expect(MatchPointAnalytics.fromRecord({'id': 'old'}), null);
    expect(MatchPointAnalytics.decode([{'team': 'teamA'}]), null);
    expect(MatchPointAnalytics.decode([]), isEmpty);
    expect(MatchPointAnalytics.decode(jsonDecode('[null]')), null);
    final old = MatchCheckpointCodec.encode({
      'settings': {
        'teamAName':'A', 'teamBName':'B', 'player1Name':'1',
        'player2Name':'2', 'player3Name':'3', 'player4Name':'4',
        'firstServerPlayerId':1, 'isGoldenPoint':true,
        'advantagesBeforeGoldenPoint':0, 'bestOfSets':3,
        'shortSets':false, 'decidingMatchTieBreak':false,
        'decidingTieBreakPoints':10,
      },
      'snapshot': MatchCheckpointCodec.snapshotToJson(PadelMatchSnapshot.initial()),
      'history': [],
      'runtime': {
        'elapsedSeconds':0, 'isTimerRunning':true, 'isSidesSwapped':false,
        'breakSecondsLeft':0, 'isBreakActive':false,
      },
    });
    expect(MatchCheckpointCodec.decode(old), isNotNull);
  });
}
