import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/watch_command_gate.dart';
import 'support/fake_tts_service.dart';

Map<String, dynamic> command(String id, String matchId, String action) =>
    {'commandId': id, 'matchId': matchId, 'action': action};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('idempotenza: due messaggi con stesso ID eseguono un solo punto', () async {
    final gate = WatchCommandGate();
    var points = 0;
    Future<Map<String, dynamic>> apply(String action) async {
      points++;
      return {'ok': true, 'code': action};
    }
    final first = await gate.accept(command('id1', 'match1', 'point_a'),
        currentMatchId: () => 'match1', execute: apply);
    final duplicate = await gate.accept(command('id1', 'match1', 'point_a'),
        currentMatchId: () => 'match1', execute: apply);
    expect(first['ok'], true);
    expect(duplicate['duplicate'], true);
    expect(points, 1);
  });

  test('comandi ravvicinati sono serializzati nello stesso ordine', () async {
    final gate = WatchCommandGate();
    final applied = <String>[];
    Future<Map<String, dynamic>> run(String action) async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      applied.add(action);
      return {'ok': true};
    }
    final futures = [
      gate.accept(command('a', 'm', 'point_a'), currentMatchId: () => 'm', execute: run),
      gate.accept(command('b', 'm', 'point_b'), currentMatchId: () => 'm', execute: run),
      gate.accept(command('c', 'm', 'undo'), currentMatchId: () => 'm', execute: run),
    ];
    await Future.wait(futures);
    expect(applied, ['point_a', 'point_b', 'undo']);
  });

  test('comando stale, non valido e di altra partita respinti', () async {
    final gate = WatchCommandGate();
    var executed = false;
    Future<Map<String, dynamic>> run(String _) async {
      executed = true;
      return {'ok': true};
    }
    expect((await gate.accept(command('a', 'old', 'undo'),
        currentMatchId: () => 'new', execute: run))['code'], 'stale_match');
    expect((await gate.accept(command('b', 'new', 'reset_everything'),
        currentMatchId: () => 'new', execute: run))['code'], 'invalid_command');
    expect(executed, false);
  });

  test('Watch usa il provider del motore: punti, Undo, pausa, termine', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 3);
    final id = p.watchMatchId;
    expect((await p.handleWatchCommand(command('one', id, 'point_a')))['ok'], true);
    expect(p.snapshot.rawPointsA, 1);
    expect((await p.handleWatchCommand(command('one', id, 'point_a')))['duplicate'], true);
    expect(p.snapshot.rawPointsA, 1);
    expect((await p.handleWatchCommand(command('two', id, 'undo')))['ok'], true);
    expect(p.snapshot.rawPointsA, 0);
    expect((await p.handleWatchCommand(command('three', id, 'pause_match')))['ok'], true);
    expect(p.isTimerRunning, false);
    expect((await p.handleWatchCommand(command('four', id, 'resume_match')))['ok'], true);
    expect(p.isTimerRunning, true);
    expect((await p.handleWatchCommand(command('five', id, 'end_match')))['ok'], true);
    expect(p.hasActiveMatch, false);
    expect(p.watchEndSequence, 1);
    expect((await p.handleWatchCommand(command('six', id, 'point_b')))['ok'], false);
    p.dispose();
  });

  test('Cambia campo dal Watch e` solo visivo e mantiene il punteggio', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 3);
    final id = p.watchMatchId;
    expect(p.isSidesSwapped, false);
    final result = await p.handleWatchCommand(command('sides-1', id, 'switch_sides'));
    expect(result['ok'], true);
    expect(p.isSidesSwapped, true);
    expect(p.snapshot.rawPointsA, 0);
    expect(p.snapshot.rawPointsB, 0);
    expect((await p.handleWatchCommand(command('sides-1', id, 'switch_sides')))['duplicate'], true);
    expect(p.isSidesSwapped, true);
    p.dispose();
  });

  test('Cambia battitore soltanto prima di cominciare il game', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 3);
    final id = p.watchMatchId;
    final firstServer = p.currentServerPlayerId;
    expect((await p.handleWatchCommand(command('server-1', id, 'change_server')))['ok'], true);
    expect(p.currentServerPlayerId, isNot(firstServer));
    p.addPoint(Team.teamA);
    final invalid = await p.handleWatchCommand(command('server-2', id, 'change_server'));
    expect(invalid['code'], 'server_change_between_games_only');
    p.dispose();
  });

  test('Regola Watch: cambia prima del primo punto, poi resta bloccata', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 3);
    final id = p.watchMatchId;
    expect((await p.handleWatchCommand(command('rule-1', id, 'rule_star')))['ok'], true);
    expect(p.isGoldenPoint, true);
    expect(p.advantagesBeforeGoldenPoint, 2);
    expect((await p.handleWatchCommand(command('rule-2', id, 'rule_traditional')))['ok'], true);
    expect(p.isGoldenPoint, false);
    p.addPoint(Team.teamB);
    final invalid = await p.handleWatchCommand(command('rule-3', id, 'rule_golden'));
    expect(invalid['code'], 'rule_locked_after_first_point');
    expect(p.isGoldenPoint, false);
    p.dispose();
  });

  test('Avvio Watch usa configurazione esistente e cambia matchId', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    final old = p.watchMatchId;
    final result = await p.handleWatchCommand(command('start1', old, 'start_match'));
    expect(result['ok'], true);
    expect(p.hasActiveMatch, true);
    expect(p.watchStartSequence, 1);
    expect(p.watchMatchId, isNot(old));
    expect((await p.handleWatchCommand(command('bad', old, 'point_a')))['code'], 'stale_match');
    await p.flushCheckpoint();
    p.dispose();
  });
}
