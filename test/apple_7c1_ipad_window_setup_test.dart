import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/providers/padel_score_provider.dart';
import 'package:padel_scorebot/screens/match_setup_screen.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('7C-1: Setup in finestra iPad stretta mantiene squadre in colonna', (tester) async {
    tester.view.physicalSize = const Size(560, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    expect(first.dy, lessThan(second.dy));
    expect((first.dx - second.dx).abs(), lessThan(2));
    expect(find.text('Configura partita'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
