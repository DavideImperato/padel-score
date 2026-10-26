import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/screens/match_setup_screen.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Il setup mostra le tre modalità di punteggio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = PadelScoreProvider(ttsService: FakeTtsService());
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PadelScoreProvider>.value(
        value: provider,
        child: const MaterialApp(home: MatchSetupScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Vantaggi tradizionali'), findsOneWidget);
    expect(find.text('Punto d\'Oro'), findsOneWidget);
    expect(find.text('Star Point FIP 2026'), findsOneWidget);
  });
}
