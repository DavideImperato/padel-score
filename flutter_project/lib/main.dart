import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/padel_score_provider.dart';
import 'screens/match_setup_screen.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try { await WakelockPlus.enable(); } catch (_) {}
  final ttsService = TtsService();
  await ttsService.init();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PadelScoreProvider(ttsService: ttsService))],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MatchSetupScreen(),
      ),
    ),
  );
}
