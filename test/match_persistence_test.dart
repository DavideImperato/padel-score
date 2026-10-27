import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/match_checkpoint.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Riprende punteggio, rotazione, tempo, regole e Undo offline', () async {
    SharedPreferences.setMockInitialValues({});
    final original = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    original.setupMatch(team1: 'Prima', team2: 'Seconda',
      player1: 'A1', player2: 'A2', player3: 'B1', player4: 'B2',
      firstServerPlayerId: 3, goldenPoint: true,
      bestOfSets: 5, shortSets: true,
      decidingMatchTieBreak: true, decidingTieBreakPoints: 7);
    for (var i = 0; i < 15; i++) { original.addPoint(Team.teamA); }
    original.toggleServingTeam();
    original.switchSides();
    original.updateClock(139, false, breakSeconds: 28, breakActive: true);
    final points = original.snapshot.rawPointsA;
    final server = original.currentServerPlayerId;
    await original.flushCheckpoint();
    original.dispose();

    final fresh = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fresh.hasSavedMatch, isTrue);
    expect(fresh.resumeSavedMatch(), isTrue);
    expect(fresh.teamAName, 'Prima');
    expect(fresh.bestOfSets, 5);
    expect(fresh.shortSets, isTrue);
    expect(fresh.decidingTieBreakPoints, 7);
    expect(fresh.firstServerPlayerId, 3);
    expect(fresh.snapshot.rawPointsA, points);
    expect(fresh.currentServerPlayerId, server);
    expect(fresh.canUndo, isTrue);
    expect(fresh.elapsedSeconds, 139);
    expect(fresh.isTimerRunning, isFalse);
    expect(fresh.isSidesSwapped, isTrue);
    expect(fresh.breakSecondsLeft, 28);
    fresh.undo();
    expect(fresh.currentServerPlayerId, isNot(server));
    fresh.addPoint(Team.teamB);
    await fresh.flushCheckpoint();
    fresh.dispose();
  });

  test('Versione errata e JSON danneggiato non vengono ripristinati', () async {
    for (final bad in ['{broken', '{"version":999}']) {
      expect(MatchCheckpointCodec.decode(bad), isNull);
    }
    final s = PadelMatchSnapshot.initial();
    final encoded = MatchCheckpointCodec.encode({
      'settings': {
        'teamAName':'A', 'teamBName':'B', 'player1Name':'1',
        'player2Name':'2', 'player3Name':'3', 'player4Name':'4',
        'firstServerPlayerId':1, 'isGoldenPoint':true,
        'advantagesBeforeGoldenPoint':0, 'bestOfSets':3,
        'shortSets':false, 'decidingMatchTieBreak':false,
        'decidingTieBreakPoints':10,
      },
      'snapshot': MatchCheckpointCodec.snapshotToJson(s),
      'history': [],
      'runtime': {
        'elapsedSeconds':0, 'isTimerRunning':true,
        'isSidesSwapped':false, 'breakSecondsLeft':0, 'isBreakActive':false,
      },
    });
    expect(MatchCheckpointCodec.decode(encoded), isNotNull);
    expect(MatchCheckpointCodec.snapshotFromJson(
      MatchCheckpointCodec.snapshotToJson(s)).servingTeam, s.servingTeam);
  });

  test('Scartare la partita cancella il checkpoint', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1:'A',team2:'B',player1:'A1',player2:'A2',
      player3:'B1',player4:'B2',firstServerPlayerId:1,
      goldenPoint:true,bestOfSets:3);
    p.addPoint(Team.teamB);
    await p.flushCheckpoint();
    p.dispose();
    final reopened = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reopened.hasSavedMatch, isTrue);
    reopened.discardSavedMatch();
    await reopened.flushCheckpoint();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MatchCheckpointCodec.key), isNull);
    reopened.dispose();
  });
}
