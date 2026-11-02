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

  testWidgets('7C-1: Home su iPhone compatto senza overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
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

    expect(find.text('Ciao, Andrea!'), findsOneWidget);
    final start = find.ancestor(
      of: find.text('INIZIA PARTITA'), matching: find.byType(Card));
    final history = find.ancestor(
      of: find.text('STORICO PARTITE'), matching: find.byType(Card));
    expect(start, findsOneWidget);
    expect(history, findsOneWidget);
    expect(tester.getCenter(start).dx, lessThan(tester.getCenter(history).dx));
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
