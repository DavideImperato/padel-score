import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/models/padel_match_state.dart';
import 'package:padel_scorebot/screens/match_history_screen.dart';
import 'package:padel_scorebot/services/match_checkpoint.dart';
import 'package:padel_scorebot/services/match_history.dart';
import 'package:padel_scorebot/services/match_interrupted.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> finishedMatch() => {
        'version': 1,
        'id': 'finished-1',
        'completedAt': DateTime(2026, 10, 28).millisecondsSinceEpoch,
        'durationSeconds': 180,
        'teamAName': 'Rossi',
        'teamBName': 'Blu',
        'players': ['Mario', 'Elena', 'Luca', 'Anna'],
        'winner': 'teamA',
        'sets': [
          {
            'gamesA': 6,
            'gamesB': 4,
            'isCompleted': true,
            'isMatchTieBreak': false,
            'winner': 'teamA',
            'tieBreakPointsA': null,
            'tieBreakPointsB': null,
          },
        ],
        'bestOfSets': 1,
        'gamesPerSet': 6,
      };

  Map<String, dynamic> interruptedMatch() {
    final checkpoint = jsonDecode(MatchCheckpointCodec.encode({
      'matchId': 'paused-1',
      'settings': {
        'teamAName': 'Gialli',
        'teamBName': 'Verdi',
        'player1Name': 'A1',
        'player2Name': 'A2',
        'player3Name': 'B1',
        'player4Name': 'B2',
        'firstServerPlayerId': 1,
        'isGoldenPoint': true,
        'advantagesBeforeGoldenPoint': 0,
        'bestOfSets': 3,
        'shortSets': false,
        'decidingMatchTieBreak': false,
        'decidingTieBreakPoints': 10,
      },
      'snapshot': MatchCheckpointCodec.snapshotToJson(PadelMatchSnapshot.initial()),
      'history': [],
      'runtime': {
        'elapsedSeconds': 40,
        'isTimerRunning': false,
        'isSidesSwapped': false,
        'breakSecondsLeft': 0,
        'isBreakActive': false,
      },
    })) as Map<String, dynamic>;
    return {
      'version': 1,
      'id': 'paused-1',
      'interruptedAt': DateTime(2026, 10, 28).millisecondsSinceEpoch,
      'checkpoint': checkpoint,
    };
  }

  testWidgets('Passaggio Concluse/Interrotte con archivio interrotte vuoto',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final completed = finishedMatch();
    expect(MatchHistoryStore.validRecord(completed), isTrue);
    await prefs.setString(MatchHistoryStore.key, jsonEncode([completed]));

    await tester.pumpWidget(const MaterialApp(home: MatchHistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Rossi  vs  Blu'), findsOneWidget);

    await tester.tap(find.text('Interrotte'));
    await tester.pump(); // Primo frame: prima la snapshot precedente dava errore.
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Nessuna partita interrotta.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Concluse'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Rossi  vs  Blu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(await MatchHistoryStore.load(), hasLength(1));
    expect(await MatchInterruptedStore.load(), isEmpty);
  });

  testWidgets('Passaggio tra schede con entrambi gli archivi popolati',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final completed = finishedMatch();
    final paused = interruptedMatch();
    expect(MatchHistoryStore.validRecord(completed), isTrue);
    expect(MatchInterruptedStore.validRecord(paused), isTrue);
    await prefs.setString(MatchHistoryStore.key, jsonEncode([completed]));
    await prefs.setString(MatchInterruptedStore.key, jsonEncode([paused]));

    await tester.pumpWidget(const MaterialApp(home: MatchHistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Rossi  vs  Blu'), findsOneWidget);

    await tester.tap(find.text('Interrotte'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Gialli vs Verdi'), findsOneWidget);

    await tester.tap(find.text('Concluse'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Rossi  vs  Blu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(await MatchHistoryStore.load(), hasLength(1));
    expect(await MatchInterruptedStore.load(), hasLength(1));
  });
}
