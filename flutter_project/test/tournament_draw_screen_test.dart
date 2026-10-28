// Test isolato: non condividere il mock di SharedPreferences tra scenari UI.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/screens/tournaments_screen.dart';
import '../lib/services/tournament_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dettaglio genera girone e apre classifica verticale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TournamentStore.key, jsonEncode({
      'version': 1,
      'tournaments': [{
        'id': 't1', 'name': 'Coppa di Test', 'format': 'groups',
        'venue': '', 'date': '', 'createdAt': 123,
        'entries': [
          for (var i = 0; i < 4; i++) {
            'pairId': 'p$i', 'pairName': 'Coppia $i',
            'playerIds': ['a$i', 'b$i'],
            'playerNames': ['A$i', 'B$i'], 'joinedAt': 123,
          },
        ],
      }],
    }));
    await tester.pumpWidget(const MaterialApp(home: TournamentDetailScreen(tournamentId: 't1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Genera gironi e calendario'), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Genera gironi e calendario'));
    await tester.pumpAndSettle();
    expect(find.text('Genera gironi'), findsOneWidget);
    await tester.tap(find.text('Genera').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Apri gironi e classifiche'), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Apri gironi e classifiche'));
    await tester.pumpAndSettle();
    expect(find.text('Gironi e classifiche'), findsOneWidget);
    expect(find.text('CLASSIFICA'), findsOneWidget);
    expect(find.text('GIRONE A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
