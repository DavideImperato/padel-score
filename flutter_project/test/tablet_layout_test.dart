import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/screens/app_home_screen.dart';
import 'package:padel_scorebot/screens/match_setup_screen.dart';
import 'package:padel_scorebot/services/app_preferences.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setTabletSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('Home iPad: card in due colonne e sviluppatore presente', (tester) async {
    setTabletSize(tester);
    SharedPreferences.setMockInitialValues({});
    final voice = FakeTtsService();
    final prefs = await AppPreferences.load(voice);
    await prefs.changeName('Andrea');
    final provider = PadelScoreProvider(ttsService: voice);
    addTearDown(provider.dispose);
    addTearDown(prefs.dispose);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<PadelScoreProvider>.value(value: provider),
    ], child: const MaterialApp(home: AppHomeScreen())));
    await tester.pumpAndSettle();
    final yPlayers = tester.getTopLeft(find.text('GIOCATORI E COPPIE')).dy;
    final yTournament = tester.getTopLeft(find.text('TORNEI')).dy;
    expect((yPlayers - yTournament).abs(), lessThan(2));
    expect(find.text('Sviluppatore: Davide Imperato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Setup iPad: le squadre sono affiancate', (tester) async {
    setTabletSize(tester);
    SharedPreferences.setMockInitialValues({});
    final provider = PadelScoreProvider(ttsService: FakeTtsService());
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<PadelScoreProvider>.value(
      value: provider,
      child: const MaterialApp(home: MatchSetupScreen()),
    ));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('SQUADRA 1'));
    final second = tester.getTopLeft(find.text('SQUADRA 2'));
    expect((first.dy - second.dy).abs(), lessThan(2));
    expect(first.dx, lessThan(second.dx));
    expect(tester.takeException(), isNull);
  });
}
