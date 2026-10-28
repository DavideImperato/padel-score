import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/padel_match_state.dart';
import '../lib/services/watch_match_sync.dart';

Map<String, dynamic> makeState(PadelMatchSnapshot snapshot, {
  bool active = true,
  bool recovery = false,
}) => buildWatchMatchState(
  matchId: 'match-123', active: active, awaitingRecovery: recovery,
  snapshot: snapshot,
  teamAName: 'Coppia A', teamBName: 'Coppia B',
  players: const ['Anna', 'Luca', 'Giulia', 'Marco'],
  servingPlayer: 'Anna', servingPlayerId: 1,
  goldenPoint: true, advantagesBeforeGoldenPoint: 0,
  shortSets: false, bestOfSets: 3,
  decidingMatchTieBreak: true, decidingTieBreakPoints: 10,
  elapsedSeconds: 75, timerRunning: true, canUndo: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('padel_score_board/watch_link');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('snapshot iniziale e` completo e solo leggibile', () {
    final state = makeState(PadelMatchSnapshot.initial());
    expect(state['status'], 'live');
    expect(state['pointsA'], '0');
    expect(state['pointsB'], '0');
    expect(state['servingPlayer'], 'Anna');
    expect(state['gamesA'], 0);
    expect(state['sets'], isEmpty);
    expect(state['elapsedSeconds'], 75);
    expect(state.containsKey('history'), isFalse);
    expect(state.containsKey('command'), isFalse);
  });

  test('punti e game riflettono il motore senza conversioni errate', () {
    final snap = PadelMatchSnapshot.initial().copyWith(
      rawPointsA: 3, rawPointsB: 2, currentGamesA: 4,
    );
    final state = makeState(snap);
    expect(state['pointsA'], '40');
    expect(state['pointsB'], '30');
    expect(state['gamesA'], 4);
  });

  test('tie-break visualizza punti numerici', () {
    final snap = PadelMatchSnapshot.initial().copyWith(
      isTieBreak: true, isMatchTieBreak: true,
      tieBreakPointsA: 10, tieBreakPointsB: 9,
    );
    final state = makeState(snap);
    expect(state['pointsA'], '10');
    expect(state['pointsB'], '9');
    expect(state['isMatchTieBreak'], isTrue);
    expect(state['decidingTieBreakPoints'], 10);
  });

  test('storico set decisivo conserva i punti MTB', () {
    final snap = PadelMatchSnapshot.initial().copyWith(completedSets: const [
      SetScore(gamesA: 0, gamesB: 0, isMatchTieBreak: true,
        tieBreakPointsA: 11, tieBreakPointsB: 9, winner: Team.teamA),
    ], matchWinner: Team.teamA);
    final state = makeState(snap);
    expect((state['sets'] as List).single['matchTieBreak'], isTrue);
    expect((state['sets'] as List).single['tieBreakA'], 11);
    expect(state['winner'], 'A');
    expect(state['status'], 'finished');
  });

  test('partita inattiva o da recuperare non appare come live', () {
    expect(makeState(PadelMatchSnapshot.initial(), active: false)['status'], 'idle');
    expect(makeState(PadelMatchSnapshot.initial(), recovery: true)['status'], 'recovery');
  });

  test('nuovi campi Watch: cambio campo e permessi sicuri', () {
    final result = buildWatchMatchState(
      matchId: 'match-456', active: true, awaitingRecovery: false,
      snapshot: PadelMatchSnapshot.initial(),
      teamAName: 'Coppia A', teamBName: 'Coppia B',
      players: const ['Anna', 'Luca', 'Giulia', 'Marco'],
      servingPlayer: 'Anna', servingPlayerId: 1,
      goldenPoint: true, advantagesBeforeGoldenPoint: 2,
      shortSets: false, bestOfSets: 3,
      decidingMatchTieBreak: false, decidingTieBreakPoints: 10,
      elapsedSeconds: 80, timerRunning: false, canUndo: true,
      sidesSwapped: true, canChangeRules: false, canChangeServer: true,
    );
    expect(result['sidesSwapped'], true);
    expect(result['canChangeRules'], false);
    expect(result['canChangeServer'], true);
    expect(result['canUndo'], true);
    expect(result['rules'], 'Star Point');
  });

  test('pubblicazione usa solo il canale Watch senza comandi sportivi', () async {
    String? method;
    Map<dynamic, dynamic>? arguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      method = call.method;
      arguments = call.arguments as Map;
      return null;
    });
    await const WatchMatchSync().publish(makeState(PadelMatchSnapshot.initial()));
    expect(method, 'publishMatch');
    expect(arguments?['matchId'], 'match-123');
    expect(arguments?['status'], 'live');
  });

  test('senza plugin nativo nessuna eccezione raggiunge il motore', () async {
    await const WatchMatchSync().publish(makeState(PadelMatchSnapshot.initial()));
  });
}
