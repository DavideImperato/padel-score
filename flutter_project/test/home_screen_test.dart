import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/screens/app_home_screen.dart';
import 'package:padel_scorebot/services/app_preferences.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Primo avvio richiede il nome e mostra le cinque destinazioni', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 940);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fakeVoice = FakeTtsService();
    final prefs = await AppPreferences.load(fakeVoice);
    final provider = PadelScoreProvider(ttsService: fakeVoice);
    addTearDown(provider.dispose);
    addTearDown(prefs.dispose);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<PadelScoreProvider>.value(value: provider),
    ], child: const MaterialApp(home: AppHomeScreen())));
    await tester.pump();
    expect(find.text('Benvenuto!'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Andrea');
    await tester.tap(find.text('CONTINUA'));
    await tester.pumpAndSettle();
    expect(find.text('Ciao, Andrea!'), findsOneWidget);
    expect(find.text('INIZIA PARTITA'), findsOneWidget);
    expect(find.text('STORICO PARTITE'), findsOneWidget);
    expect(find.text('GIOCATORI E COPPIE'), findsOneWidget);
    expect(find.text('STATISTICHE'), findsOneWidget);
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    // Il nome e' gia' nel logo: non deve esserci un secondo titolo.
    expect(find.text('PADEL SCORE BOARD'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
