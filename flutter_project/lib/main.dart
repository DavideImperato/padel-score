import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/padel_score_provider.dart';
import 'screens/app_home_screen.dart';
import 'services/app_orientation.dart';
import 'services/app_preferences.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppOrientation.home();
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  final ttsService = TtsService();
  await ttsService.init();
  final appPreferences = await AppPreferences.load(ttsService);

  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => PadelScoreProvider(ttsService: ttsService)),
    ChangeNotifierProvider<AppPreferences>.value(value: appPreferences),
  ], child: const PadelScoreBotApp()));
}

class PadelScoreBotApp extends StatelessWidget {
  const PadelScoreBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppPreferences>().darkMode;
    return MaterialApp(
      title: 'Padel Score Board',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [homeRouteObserver],
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: dark ? const Color(0xFF101D3A) : const Color(0xFFF1F5FA),
        colorScheme: dark
          ? const ColorScheme.dark(primary: Color(0xFFCCFF00), secondary: Color(0xFF00E5FF), surface: Color(0xFF0F172A))
          : const ColorScheme.light(primary: Color(0xFF376800), secondary: Color(0xFF007C8A), surface: Colors.white),
        fontFamily: 'Roboto',
      ),
      home: const AppHomeScreen(),
    );
  }
}
