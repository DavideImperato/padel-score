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

  testWidgets('7C-1: Home in finestra iPad stretta usa la colonna', (tester) async {
    // Simula una finestra iPadOS ridimensionata, non il display fisico.
    tester.view.physicalSize = const Size(560, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final voice = FakeTtsService();
    final preferences = await AppPreferences.load(voice);
    await preferences.changeName('Andrea');
    final provider = PadelScoreProvider(ttsService: voice);
    addTearDown(provider.dispose);
    addTearDown(preferences.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPreferences>.value(value: preferences),
        ChangeNotifierProvider<PadelScoreProvider>.value(value: provider),
      ],
      child: const MaterialApp(home: AppHomeScreen()),
    ));
    await tester.pumpAndSettle();

    final players = find.ancestor(
      of: find.text('GIOCATORI E COPPIE'), matching: find.byType(Card));
    final tournaments = find.ancestor(
      of: find.text('TORNEI'), matching: find.byType(Card));
    expect(players, findsOneWidget);
    expect(tournaments, findsOneWidget);
    final first = tester.getCenter(players);
    final second = tester.getCenter(tournaments);
    expect(first.dy, lessThan(second.dy));
    expect((first.dx - second.dx).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });
}
