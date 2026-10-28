// Test isolato: non condividere il mock di SharedPreferences tra scenari UI.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/screens/tournament_draw_screen.dart';
import '../lib/services/tournament_draw.dart';
import '../lib/services/tournament_store.dart';

// Le attese asincrone dipendono dai frame simulati del singolo widget test.
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    await _pumpUntil(tester,
        () => find.text('Risultato incontro').evaluate().isEmpty);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Se il dialogo resta aperto, il risultato non viene accettato:
    // intercettiamo prima l'errore di validazione invece di cercare
    // soltanto il risultato nell'archivio.
    final visibleMessages = tester.widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((message) => message.contains('Risultato') ||
            message.contains('valido') || message.contains('salvataggio'))
        .toList();
    expect(find.text('Risultato incontro'), findsNothing,
        reason: 'La finestra non si chiude dopo Salva. Messaggi: $visibleMessages');

    // La chiusura del DialogRoute e il salvataggio su SharedPreferences
    // possono completarsi su turni asincroni diversi: attendiamo entrambi.
    Map<String, dynamic>? stored;
    Map? savedResult;
    for (var attempt = 0; attempt < 20; attempt++) {
      stored = await TournamentStore.load();
      final tournaments = stored?['tournaments'] as List?;
      if (tournaments != null && tournaments.isNotEmpty) {
        final draw = (tournaments.single as Map)['draw'] as Map;
        savedResult = ((draw['matches'] as List).single as Map)['result'] as Map?;
      }
      if (savedResult != null) break;
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(stored, isNotNull);
    final errorsOnScreen = tester.widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((message) => message.contains('non valido') ||
            message.contains('non riuscito') || message.contains('non disponibile') ||
            message.contains('non leggibile'))
        .toList();
    expect(savedResult, isNotNull,
        reason: 'Risultato non salvato nel torneo. Errori UI: $errorsOnScreen');
    expect(savedResult!['sets'], [[6, 4], [6, 4]]);

    // Il risultato deve essere visibile anche nel tabellone (non basta
    // che sia presente in memoria). La lista puo' essere fuori viewport.
    await tester.pumpAndSettle();
    final scoreLabel = find.text('6–4  ·  6–4');
    await tester.scrollUntilVisible(scoreLabel, 100,
      scrollable: find.byType(Scrollable).first, maxScrolls: 15);
    expect(scoreLabel, findsOneWidget);

    // Modificare nuovamente il risultato deve essere stabile.
    await tester.tap(find.text('Incontro 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifica risultato'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await _pumpUntil(tester,
        () => find.text('Risultato incontro').evaluate().isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Risultato incontro'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
