import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/main.dart';
import 'package:padel_scorebot/screens/app_home_screen.dart';
import 'package:padel_scorebot/services/app_preferences.dart';
import 'package:padel_scorebot/widgets/padel_ball_loader.dart';
import 'package:padel_scorebot/widgets/padel_startup_screen.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({AppPreferences.nameKey: 'Tester'});
  });

  testWidgets('il loader precede la Home e sparisce dopo l’inizializzazione',
      (tester) async {
    final tts = FakeTtsService();
    final preferences = await AppPreferences.load(tts);
    final gate = Completer<PadelAppDependencies>();

    await tester.pumpWidget(PadelStartupApp(initialize: () => gate.future));
    expect(find.byType(PadelBallLoader), findsOneWidget);
    expect(find.text('Caricamento in corso...'), findsOneWidget);
    expect(find.byType(AppHomeScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 550));
    expect(tester.takeException(), isNull);

    gate.complete(PadelAppDependencies(ttsService: tts, preferences: preferences));
    await tester.pump();
    // I servizi sono pronti, ma il loader rimane visibile almeno 850 ms.
    expect(find.byType(PadelBallLoader), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byType(PadelBallLoader), findsNothing);
    expect(find.byType(AppHomeScreen), findsOneWidget);
  });

  testWidgets('l’errore mostra Riprova senza bloccare il caricamento',
      (tester) async {
    final tts = FakeTtsService();
    final preferences = await AppPreferences.load(tts);
    var attempts = 0;
    Future<PadelAppDependencies> initializer() async {
      attempts++;
      if (attempts == 1) throw StateError('Errore simulato');
      return PadelAppDependencies(ttsService: tts, preferences: preferences);
    }

    await tester.pumpWidget(PadelStartupApp(initialize: initializer));
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump();
    expect(find.text('Riprova'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(AppHomeScreen), findsOneWidget);
  });

  testWidgets('inizializzazione immediata: loader visibile prima della Home',
      (tester) async {
    final tts = FakeTtsService();
    final preferences = await AppPreferences.load(tts);
    final dependencies = PadelAppDependencies(
      ttsService: tts,
      preferences: preferences,
    );

    await tester.pumpWidget(PadelStartupApp(
      initialize: () async => dependencies,
    ));
    expect(find.byType(PadelBallLoader), findsOneWidget);
    expect(find.byType(AppHomeScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(PadelBallLoader), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.byType(PadelBallLoader), findsNothing);
    expect(find.byType(AppHomeScreen), findsOneWidget);
  });

  testWidgets('riduci movimento: pallina visibile senza animazione',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: PadelStartupScreen(),
      ),
    ));
    expect(find.byType(PadelBallLoader), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Caricamento in corso...'), findsOneWidget);
  });
}
