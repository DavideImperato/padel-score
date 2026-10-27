import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/match_history_advanced.dart';

void main() {
  final a = DateTime(2026, 10, 20, 14).millisecondsSinceEpoch;
  final b = DateTime(2026, 10, 26, 11).millisecondsSinceEpoch;
  Map<String, dynamic> match(String id, int date, List<String?>? ids) => {
    'id': id, 'completedAt': date, 'teamAName': 'Rossi', 'teamBName': 'Blu',
    'players': ['Mario', 'Elena', 'Luca', 'Anna'], if (ids != null) 'playerIds': ids,
    'winner':'teamA','durationSeconds':125,
    'sets':[{'gamesA':6,'gamesB':4,'isCompleted':true,'isMatchTieBreak':false}],
  };
  final items = [match('first', a, ['p1','p2','p3','p4']), match('other', b, ['p1','p3','p2','p4']), match('old', b, null)];
  final interrupted = [{'id':'pause', 'interruptedAt':a, 'checkpoint':{
    'settings':{'teamAName':'Rossi','teamBName':'Blu','player1Name':'Mario','player2Name':'Elena','player3Name':'Luca','player4Name':'Anna','playerIds':['p1','p2','p3','p4']},
    'snapshot':{'completedSets':[],'currentGamesA':1,'currentGamesB':2,'isTieBreak':false},
    'runtime':{'elapsedSeconds':65},
  }}];

  test('Ricerca, identità stabile e coppie sullo stesso lato', () {
    expect(MatchHistoryAdvanced.finished(items, query:'rossi').length, 3);
    expect(MatchHistoryAdvanced.finished(items, query:'Giorgio', currentNames:{'p1':'Giorgio'}).length, 2);
    expect(MatchHistoryAdvanced.finished(items, playerId:'p1').length, 2);
    expect(MatchHistoryAdvanced.finished(items, pairIds:['p2','p1']).map((m)=>m['id']).toList(), ['first']);
    expect(MatchHistoryAdvanced.finished(items, pairIds:['p3','p4']).map((m)=>m['id']).toList(), ['first']);
    expect(MatchHistoryAdvanced.finished(items, pairIds:['p1']).isEmpty, isTrue);
    expect(MatchHistoryAdvanced.finished(items, query:'nessuno'), isEmpty);
  });
  test('Intervallo inclusivo, partite interrotte indipendenti', () {
    expect(MatchHistoryAdvanced.finished(items, from:DateTime(2026,10,21)).length, 2);
    expect(MatchHistoryAdvanced.finished(items, to:DateTime(2026,10,20)).length, 1);
    expect(MatchHistoryAdvanced.finished(items, from:DateTime(2026,10,26), to:DateTime(2026,10,26)).length, 2);
    expect(MatchHistoryAdvanced.interrupted(interrupted, playerId:'p1').length, 1);
    expect(MatchHistoryAdvanced.interrupted(interrupted, to:DateTime(2026,10,19)), isEmpty);
  });
  test('Esportazione CSV soltanto dei record filtrati, formule neutralizzate', () {
    final first = {...items.first, 'teamAName':'=1+1', 'players':['+cmd','-cmd','@test','virgola;"citazione"']};
    final csv = MatchHistoryAdvanced.csv(finished:[first], interrupted:interrupted);
    expect(csv.codeUnitAt(0), 0xFEFF);
    expect(csv, contains("\"'=1+1\""));
    expect(csv, contains("\"'+cmd\""));
    expect(csv, contains('"virgola;""citazione"""'));
    expect(csv, contains('"Interrotta"'));
    expect(csv, contains('"6-4"'));
    expect(csv, contains('"In corso 1-2"'));
    expect(csv.split('\r\n').where((line)=>line.isNotEmpty).length, 3);
    expect(items.first['teamAName'], 'Rossi');
  });
}
