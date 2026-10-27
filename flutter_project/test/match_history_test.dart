import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/match_history.dart';
import 'package:padel_scorebot/services/match_checkpoint.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PadelScoreProvider> finishedMatch() async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 1);
    for (var i = 0; i < 24; i++) { p.addPoint(Team.teamA); }
    expect(p.snapshot.matchWinner, Team.teamA);
    p.updateClock(143, false);
    await p.flushCheckpoint();
    return p;
  }

  test('Archivia solo partita conclusa: set, giocatori, durata e checkpoint', () async {
    final p = await finishedMatch();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MatchCheckpointCodec.key), isNotNull);
    expect(await p.archiveFinishedMatch(), isTrue);
    expect(prefs.getString(MatchCheckpointCodec.key), isNull);
    final items = await MatchHistoryStore.load();
    expect(items.length, 1);
    expect(items.first['winner'], 'teamA');
    expect(items.first['durationSeconds'], 143);
    expect(items.first['players'], ['A1', 'A2', 'B1', 'B2']);
    expect((items.first['sets'] as List).first['gamesA'], 6);
    expect((items.first['sets'] as List).first['gamesB'], 0);
    p.dispose();
  });

  test('La stessa partita non genera due voci, eliminazione puntuale', () async {
    final p = await finishedMatch();
    final prefs = await SharedPreferences.getInstance();
    expect(await p.archiveFinishedMatch(), isTrue);
    final record = (await MatchHistoryStore.load()).first;
    expect(await MatchHistoryStore.saveRecord(prefs, record), isTrue);
    expect((await MatchHistoryStore.load()).length, 1);
    expect(await MatchHistoryStore.delete(record['id'] as String), isTrue);
    expect(await MatchHistoryStore.load(), isEmpty);
    p.dispose();
  });

  test('Non archivia partita non terminata e non sovrascrive storico corrotto', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    p.setupMatch(team1: 'A', team2: 'B', player1: '1', player2: '2',
      player3: '3', player4: '4', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 1);
    expect(await p.archiveFinishedMatch(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MatchHistoryStore.key, '{bad-data');
    final valid = MatchHistoryStore.buildRecord(id: 'x', snapshot: p.snapshot,
      durationSeconds: 0, teamAName: 'A', teamBName: 'B',
      players: ['1', '2', '3', '4'], bestOfSets: 1,
      gamesPerSet: 6, completedAt: 1);
    expect(await MatchHistoryStore.saveRecord(prefs, valid), isFalse);
    expect(prefs.getString(MatchHistoryStore.key), '{bad-data');
    expect(MatchHistoryStore.decode(jsonEncode([{'version': 99}])), isNull);
    p.dispose();
  });
}
