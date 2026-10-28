import 'package:flutter_test/flutter_test.dart';
import '../lib/services/match_result_share.dart';

Map<String, dynamic> exampleResult() => {
  'teamAName': 'Gli Smashtori',
  'teamBName': 'I Timemasters',
  'players': ['Mario', 'Luigi', 'Paolo', 'Marco'],
  'winner': 'teamA',
  'completedAt': DateTime(2026, 10, 28, 12, 30).millisecondsSinceEpoch,
  'durationSeconds': 4521,
  'sets': [
    {'gamesA': 6, 'gamesB': 4, 'winner': 'teamA', 'isMatchTieBreak': false, 'tieBreakPointsA': null, 'tieBreakPointsB': null},
    {'gamesA': 3, 'gamesB': 6, 'winner': 'teamB', 'isMatchTieBreak': false, 'tieBreakPointsA': null, 'tieBreakPointsB': null},
    {'gamesA': 0, 'gamesB': 0, 'winner': 'teamA', 'isMatchTieBreak': true, 'tieBreakPointsA': 10, 'tieBreakPointsB': 8},
  ],
};

void main() {
  test('risultato social: set, vincitore e match tie-break', () {
    final result = MatchResultShare.fromRecord(exampleResult());
    expect(result.winner, 'Gli Smashtori');
    expect(result.wonSetsA, 2);
    expect(result.wonSetsB, 1);
    expect(result.setLines, ['SET 1   6–4', 'SET 2   3–6', 'SET 3   MTB 10–8']);
    expect(result.playerLineA, 'Mario / Luigi');
    expect(result.durationLabel, '01:15:21');
    expect(result.dateLabel, '28/10/2026');
    expect(result.accessibleSummary, contains('2 a 1'));
  });

  test('tie-break normale resta distinto dal match tie-break', () {
    final item = exampleResult();
    item['sets'] = [
      {'gamesA': 7, 'gamesB': 6, 'winner': 'teamA', 'isMatchTieBreak': false,
        'tieBreakPointsA': 8, 'tieBreakPointsB': 6}
    ];
    final result = MatchResultShare.fromRecord(item);
    expect(result.setLines.single, contains('(TB 8–6)'));
    expect(result.wonSetsA, 1);
  });

  test('le partite non concluse non producono card vittoria', () {
    final incomplete = exampleResult();
    incomplete['winner'] = null;
    expect(() => MatchResultShare.fromRecord(incomplete), throwsFormatException);
  });

  test('non condivide risultati senza set o senza giocatori', () {
    final empty = exampleResult();
    empty['sets'] = [];
    expect(() => MatchResultShare.fromRecord(empty), throwsFormatException);
    empty['sets'] = exampleResult()['sets'];
    empty['players'] = ['solo uno'];
    expect(() => MatchResultShare.fromRecord(empty), throwsFormatException);
  });
}
