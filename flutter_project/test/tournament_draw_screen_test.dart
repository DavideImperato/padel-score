import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/screens/tournaments_screen.dart';
import '../lib/screens/tournament_draw_screen.dart';
import '../lib/services/tournament_draw.dart';
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

  testWidgets('salvare e riaprire un risultato non lascia overlay o dipendenze attive',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final tournament = <String, dynamic>{
      'id': 'knockout-1', 'name': 'Torneo prova', 'format': 'knockout',
      'venue': '', 'date': '', 'createdAt': 123,
      'entries': [
        for (var i = 0; i < 2; i++) {
          'pairId': 'p$i', 'pairName': 'Coppia $i',
          'playerIds': ['a$i', 'b$i'],
          'playerNames': ['A$i', 'B$i'], 'joinedAt': 123,
        },
      ],
    };
    tournament['draw'] = TournamentDraw.fresh(tournament, timestamp: 123);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TournamentStore.key, jsonEncode({
      'version': 1,
      'tournaments': [tournament],
    }));

    await tester.pumpWidget(const MaterialApp(
      home: TournamentDrawScreen(tournamentId: 'knockout-1'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Incontro 1'), findsOneWidget);

    await tester.tap(find.text('Incontro 1'));
    await tester.pumpAndSettle();
    expect(find.text('Gioca partita'), findsOneWidget);
    expect(find.text('Inserisci risultato'), findsOneWidget);
    await tester.tap(find.text('Inserisci risultato'));
    await tester.pumpAndSettle();
    expect(find.text('Risultato incontro'), findsOneWidget);
    // Cancella e riapri: la prima animazione deve essere stata completata.
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Incontro 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inserisci risultato'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('6–4  ·  6–4'), findsOneWidget);
    final stored = await TournamentStore.load();
    expect(stored, isNotNull);
    final draw = ((stored!['tournaments'] as List).single as Map)['draw'] as Map;
    final result = ((draw['matches'] as List).single as Map)['result'] as Map;
    expect(result['sets'], [[6, 4], [6, 4]]);

    // Modificare nuovamente il risultato deve essere stabile.
    await tester.tap(find.text('Incontro 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifica risultato'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
