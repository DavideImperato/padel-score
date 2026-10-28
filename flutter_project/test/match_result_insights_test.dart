import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/services/match_history.dart';
import 'package:padel_scorebot/services/match_result_analysis.dart';
import 'support/fake_tts_service.dart';

Map<String, dynamic> fixture() => {
  'version': 1,
  'id': 'match-1',
  'completedAt': 1793180000000,
  'durationSeconds': 4521,
  'teamAName': 'Gli Smashtori',
  'teamBName': 'I Timemasters',
  'winner': 'teamA',
  'players': ['Mario', 'Luigi', 'Paolo', 'Marco'],
  'bestOfSets': 3,
  'gamesPerSet': 6,
  'sets': [
    {'gamesA': 6, 'gamesB': 4, 'winner': 'teamA', 'isCompleted': true,
     'isMatchTieBreak': false, 'tieBreakPointsA': null, 'tieBreakPointsB': null},
    {'gamesA': 3, 'gamesB': 6, 'winner': 'teamB', 'isCompleted': true,
     'isMatchTieBreak': false, 'tieBreakPointsA': null, 'tieBreakPointsB': null},
    {'gamesA': 0, 'gamesB': 0, 'winner': 'teamA', 'isCompleted': true,
     'isMatchTieBreak': true, 'tieBreakPointsA': 10, 'tieBreakPointsB': 8},
  ],
};

Map<String, dynamic> command(String id, String matchId, String action) => {
  'commandId': id, 'matchId': matchId, 'action': action,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Il report calcola i set 2-1 e i game senza inventarne nel match tie-break', () {
    final data = fixture();
    expect(MatchHistoryStore.validRecord(data), true);
    final analysis = MatchResultAnalysis.fromRecord(data);
    expect(analysis['setsA'], 2);
    expect(analysis['setsB'], 1);
    expect(analysis['gamesA'], 9);
    expect(analysis['gamesB'], 10);
    expect(analysis['tieBreaks'], 1);
    expect((analysis['progression'] as List).last, {'set': 3, 'a': 2, 'b': 1});
  });

  test('Risultati senza set validi non possono produrre statistiche', () {
    final data = fixture()..['sets'] = [];
    expect(() => MatchResultAnalysis.fromRecord(data), throwsArgumentError);
  });

  test('Watch non puo condividere o avviare nuovo incontro senza vincitore', () async {
    SharedPreferences.setMockInitialValues({});
    final p = PadelScoreProvider(ttsService: FakeTtsService());
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 1);
    final id = p.watchMatchId;
    expect((await p.handleWatchCommand(command('share', id, 'share_result')))['code'], 'not_finished');
    expect((await p.handleWatchCommand(command('new', id, 'new_match')))['code'], 'not_finished');
    p.dispose();
  });

  test('Voce finale: cifra espressa in parole e nessuna abbreviazione SET', () async {
    SharedPreferences.setMockInitialValues({});
    final tts = FakeTtsService();
    final p = PadelScoreProvider(ttsService: tts);
    await Future<void>.delayed(Duration.zero);
    p.setupMatch(team1: 'A', team2: 'B', player1: 'A1', player2: 'A2',
      player3: 'B1', player4: 'B2', firstServerPlayerId: 1,
      goldenPoint: true, bestOfSets: 1);
    // 6 game consecutivi, quattro punti per game.
    for (var i = 0; i < 24; i++) {
      p.addPoint(Team.teamA);
    }
    expect(p.isMatchOver, true);
    final spoken = tts.spoken.last;
    expect(spoken, contains('Parziali vinti: uno a zero'));
    expect(spoken, isNot(contains('1 set a 0')));
    p.dispose();
  });
}
