import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/watch_command_gate.dart';
import 'support/fake_tts_service.dart';

Map<String, dynamic> command(String id, String matchId, String action) =>
    {'commandId': id, 'matchId': matchId, 'action': action};

PadelScoreProvider newMatch() {
  final provider = PadelScoreProvider(ttsService: FakeTtsService());
  provider.setupMatch(
    team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
    player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
    goldenPoint: true, bestOfSets: 3,
  );
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Watch e Bluetooth condividono lo stesso motore; duplicati non contano', () async {
    final provider = newMatch();
    final matchId = provider.watchMatchId;
    // Il punto Bluetooth puo' arrivare fra due comandi Watch in coda.
    final a = provider.handleWatchCommand(command('watch-a', matchId, 'point_a'));
    provider.addPoint(Team.teamB); // Telecomando o touch iPhone
    final b = provider.handleWatchCommand(command('watch-b', matchId, 'point_a'));
    expect((await a)['ok'], true);
    expect((await b)['ok'], true);
    expect(provider.snapshot.rawPointsA, 2);
    expect(provider.snapshot.rawPointsB, 1);
    final duplicate = await provider.handleWatchCommand(command('watch-a', matchId, 'point_a'));
    expect(duplicate['duplicate'], true);
    expect(provider.snapshot.rawPointsA, 2);
    provider.dispose();
  });

  test('Durante archiviazione nessuna sorgente puo modificare lo snapshot', () async {
    final provider = newMatch();
    provider.addPoint(Team.teamA);
    final before = provider.snapshot;
    final startSides = provider.isSidesSwapped;
    final saving = provider.interruptAndArchiveMatch();
    // Prima che la scrittura asincrona sia terminata, l'UI e il telecomando
    // potrebbero ancora ricevere input: devono essere ignorati.
    provider.addPoint(Team.teamB);
    provider.undo();
    provider.resetMatch();
    provider.toggleServingTeam();
    provider.switchSides();
    expect(provider.snapshot.rawPointsA, before.rawPointsA);
    expect(provider.snapshot.rawPointsB, before.rawPointsB);
    expect(provider.snapshot.servingRotationIndex, before.servingRotationIndex);
    expect(provider.isSidesSwapped, startSides);
    expect(await saving, true);
    provider.addPoint(Team.teamB);
    expect(provider.snapshot.rawPointsB, before.rawPointsB);
    provider.dispose();
  });

  test('Dopo il cambio partita i comandi vecchi non entrano nella nuova', () async {
    final provider = newMatch();
    final oldId = provider.watchMatchId;
    final gate = WatchCommandGate();
    final prior = await gate.accept(command('x', oldId, 'point_a'),
      currentMatchId: () => 'partita-nuova',
      execute: (_) async => {'ok': true});
    expect(prior['code'], 'stale_match');
    expect((await provider.handleWatchCommand(command('old', 'altra-partita', 'point_b')))['code'],
        'stale_match');
    expect(provider.snapshot.rawPointsB, 0);
    provider.dispose();
  });

  test('Una coda rapida mantiene ordine e deduplicazione', () async {
    final gate = WatchCommandGate();
    final seen = <String>[];
    Future<Map<String, dynamic>> execute(String action) async {
      await Future<void>.delayed(Duration.zero);
      seen.add(action);
      return {'ok': true};
    }
    final operations = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < 40; i++) {
      final name = i.isEven ? 'point_a' : 'point_b';
      operations.add(gate.accept(command('item-$i', 'm', name),
          currentMatchId: () => 'm', execute: execute));
    }
    // Un comando duplicato resta unico anche mentre il primo e' in coda.
    operations.add(gate.accept(command('item-20', 'm', 'point_a'),
        currentMatchId: () => 'm', execute: execute));
    final answers = await Future.wait(operations);
    expect(seen.length, 40);
    expect(seen[0], 'point_a');
    expect(seen[1], 'point_b');
    expect(answers.last['duplicate'], true);
  });
}
