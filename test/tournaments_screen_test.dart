import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/screens/tournaments_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dalla lista si crea un torneo e si apre il dettaglio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: TournamentsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Organizza il tuo primo torneo'), findsOneWidget);
    await tester.tap(find.text('Crea torneo'));
    await tester.pumpAndSettle();
    expect(find.text('DATI TORNEO'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Coppa di Autunno');
    await tester.tap(find.text('Salva torneo'));
    await tester.pumpAndSettle();
    expect(find.text('Coppa di Autunno'), findsOneWidget);
    await tester.tap(find.text('Coppa di Autunno'));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna coppia iscritta. Aggiungi le coppie dalla rubrica.'), findsOneWidget);
    expect(find.text('Iscrivi coppia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
