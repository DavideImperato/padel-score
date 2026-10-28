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
  testWidgets('salvataggio rifiutato: il dialogo rimane aperto e mostra il motivo',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final tournament = <String, dynamic>{
      'id': 'knockout-error', 'name': 'Torneo da modificare',
      'format': 'knockout', 'venue': '', 'date': '', 'createdAt': 123,
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
    await prefs.setString(TournamentStore.key,
        jsonEncode({'version': 1, 'tournaments': [tournament]}));
    await tester.pumpWidget(const MaterialApp(
      home: TournamentDrawScreen(tournamentId: 'knockout-error'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incontro 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inserisci risultato'));
    await tester.pumpAndSettle();

    // Il calendario può essere azzerato dall'archivio mentre il popup è aperto.
    // Non dobbiamo chiudere il dialogo fingendo che la scrittura sia riuscita.
    // Non bloccare il test in attesa del Future mentre FakeAsync è fermo:
    // la coda del negozio deve poter completarsi tramite pump.
    var resetCompleted = false;
    String? resetError;
    TournamentStore.resetDraw('knockout-error').then((error) {
      resetError = error;
      resetCompleted = true;
    });
    await _pumpUntil(tester, () => resetCompleted);
    expect(resetCompleted, isTrue, reason: 'Azzeramento calendario non completato');
    expect(resetError, isNull);
    await tester.tap(find.text('Salva'));
    await _pumpUntil(tester,
        () => find.text('Genera prima il calendario.').evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Risultato incontro'), findsOneWidget);
    expect(find.text('Genera prima il calendario.'), findsOneWidget);
    final stored = (await TournamentStore.load())!;
    expect((stored['tournaments'] as List).single['draw'], isNull);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
