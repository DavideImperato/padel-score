import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/match_statistics.dart';

void main() {
  final directory = <String, dynamic>{
    'version': 1,
    'players': [for (var i = 0; i < 4; i++) {'id': 'p$i', 'name': 'Giocatore $i', 'createdAt': 1}],
    'pairs': [
      {'id': 'duo-a', 'name': 'Verde', 'playerIds': ['p0', 'p1'], 'createdAt': 1},
      {'id': 'duo-b', 'name': 'Blu', 'playerIds': ['p2', 'p3'], 'createdAt': 1},
    ],
  };
  Map<String, dynamic> record(String id, int at, String winner, List<String?>? ids, {int gamesPerSet = 6}) => {
    'version': 1, 'id': id, 'completedAt': at, 'winner': winner, 'durationSeconds': 60,
    if (ids != null) 'playerIds': ids,
    'gamesPerSet': gamesPerSet,
    'sets': [
      {'winner': 'teamA'}, {'winner': 'teamB'}, {'winner': 'teamA'},
    ],
  };
  test('solo risultati conclusi con ID validi: statistiche giocatori e coppie', () {
    final records = [
      record('legacy', 1, 'teamA', null),
      record('first', 4, 'teamA', ['p0','p1','p2','p3']),
      record('second', 3, 'teamB', ['p1','p0','p2','p3'], gamesPerSet: 4),
      record('manual', 2, 'teamA', [null,null,null,null]),
    ];
    final stats = MatchStatistics.calculate(directory, records);
    expect(stats['totalCompleted'], 4);
    expect(stats['unlinkedMatches'], 2);
    final mario = (stats['players'] as List).firstWhere((r) => r['id'] == 'p0');
    expect(mario['played'], 2);
    expect(mario['wins'], 1);
    expect(mario['losses'], 1);
    expect(mario['winRate'], 50.0);
    expect(mario['setsWon'], 4);
    expect(mario['setsLost'], 2);
    expect(mario['lastFive'], ['W','L']);
    expect(mario['shortSets'], 1);
    expect(mario['standardSets'], 1);
    final pair = (stats['pairs'] as List).firstWhere((r) => r['id'] == 'duo-a');
    expect(pair['played'], 2);
    expect(pair['wins'], 1);
  });
  test('statistiche identificate da ID anche dopo rinomina e cancellazione risultato', () {
    final renamed = Map<String, dynamic>.from(directory);
    renamed['players'] = [for (final p in directory['players'] as List)
      {...p, if (p['id'] == 'p0') 'name': 'Mario Nuovo'}];
    final results = [record('first', 4, 'teamA', ['p0','p1','p2','p3'])];
    final stats = MatchStatistics.calculate(renamed, results);
    final p = (stats['players'] as List).firstWhere((r) => r['id'] == 'p0');
    expect(p['name'], 'Mario Nuovo');
    expect(p['played'], 1);
    final empty = MatchStatistics.calculate(renamed, []);
    expect((empty['players'] as List).every((r) => r['played'] == 0 && r['winRate'] == 0), true);
  });
  test('record con giocatori duplicati non attribuibile; coppia incompleta ignorata', () {
    final duplicated = MatchStatistics.calculate(directory, [record('x', 7, 'teamA', ['p0','p0','p2','p3'])]);
    expect(duplicated['unlinkedMatches'], 1);
    expect((duplicated['players'] as List).every((r) => r['played'] == 0), true);
    final partial = MatchStatistics.calculate(directory, [record('y', 8, 'teamA', ['p0',null,'p2',null])]);
    expect((partial['players'] as List).firstWhere((r) => r['id'] == 'p0')['played'], 1);
    expect((partial['pairs'] as List).every((r) => r['played'] == 0), true);
  });
  test('ultimi cinque ordinati, non tutto lo storico', () {
    final matches = [for (var i = 0; i < 7; i++) record('r$i', 100+i, i.isEven ? 'teamA':'teamB', ['p0','p1','p2','p3'])];
    final stats = MatchStatistics.calculate(directory, matches);
    final p = (stats['players'] as List).firstWhere((r) => r['id'] == 'p0');
    expect(p['played'], 7);
    expect(p['lastFive'], hasLength(5));
    expect(p['lastFive'][0], 'W');
  });
}
