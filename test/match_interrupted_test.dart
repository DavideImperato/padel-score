import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/match_checkpoint.dart';
import 'package:padel_scorebot/services/match_interrupted.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PadelScoreProvider> makeProvider() async {
    SharedPreferences.setMockInitialValues({});
    final provider = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    provider.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 1);
    provider.addPoint(Team.teamA);
    provider.addPoint(Team.teamB);
    provider.updateClock(145, true);
    await provider.flushCheckpoint();
    return provider;
  }

  test('Archivia e ripristina una partita interrotta con Undo', () async {
    final provider = await makeProvider();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MatchCheckpointCodec.key), isNotNull);
    expect(await provider.interruptAndArchiveMatch(), isTrue);
    expect(prefs.getString(MatchCheckpointCodec.key), isNull);
    final archived = await MatchInterruptedStore.load();
    expect(archived, hasLength(1));
    expect((archived.single['checkpoint'] as Map)['runtime']['elapsedSeconds'], 145);
    expect(await provider.resumeInterruptedMatch(archived.single['id'] as String), isTrue);
    expect(prefs.getString(MatchCheckpointCodec.key), isNotNull);
    expect(await MatchInterruptedStore.load(), isEmpty);
    expect(provider.canUndo, isTrue);
    provider.undo();
    expect(provider.canUndo, isTrue);
    provider.dispose();
  });

  test('Archivia più partite distinte senza perdere le precedenti', () async {
    final provider = await makeProvider();
    expect(await provider.interruptAndArchiveMatch(), isTrue);
    provider.setupMatch(team1: 'Seconda A', team2: 'Seconda B',
      player1: '1', player2: '2', player3: '3', player4: '4',
      firstServerPlayerId: 1, goldenPoint: true, bestOfSets: 1);
    provider.addPoint(Team.teamA);
    expect(await provider.interruptAndArchiveMatch(), isTrue);
    final saved = await MatchInterruptedStore.load();
    expect(saved, hasLength(2));
    final ids = saved.map((e) => e['id']).toSet();
    expect(ids, hasLength(2));
    provider.dispose();
  });

  test('Protegge un archivio interrotto corrotto', () async {
    final provider = await makeProvider();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MatchInterruptedStore.key, 'broken');
    expect(await provider.interruptAndArchiveMatch(), isFalse);
    expect(prefs.getString(MatchInterruptedStore.key), 'broken');
    expect(prefs.getString(MatchCheckpointCodec.key), isNotNull);
    expect(MatchInterruptedStore.decode(jsonEncode([{'version': 999}])), isNull);
    provider.dispose();
  });

  test('Partita conclusa non può finire nelle interrotte', () async {
    final provider = await makeProvider();
    for (var i = 0; i < 24; i++) { provider.addPoint(Team.teamA); }
    expect(provider.snapshot.matchWinner, Team.teamA);
    expect(await provider.interruptAndArchiveMatch(), isFalse);
    expect(await MatchInterruptedStore.load(), isEmpty);
    provider.dispose();
  });
}
