import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/padel_score_provider.dart';
import 'screens/match_setup_screen.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Forza orientamento Landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 2. Mantiene lo schermo sempre acceso per tutta la durata del match a bordo campo
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  // 3. Inizializza TTS offline in lingua italiana
  final ttsService = TtsService();
  await ttsService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PadelScoreProvider(ttsService: ttsService),
        ),
      ],
      child: const PadelScoreBotApp(),
    ),
  );
}

class PadelScoreBotApp extends StatelessWidget {
  const PadelScoreBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Padel ScoreBot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101D3A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFCCFF00),   // Giallo Fluorescente Padel
          secondary: Color(0xFF00E5FF), // Ciano Elettrico
          surface: Color(0xFF0F172A),
        ),
        fontFamily: 'Roboto',
      ),
      // Avvia l'app dalla Schermata Iniziale di Setup Match
      home: const MatchSetupScreen(),
    );
  }
}
