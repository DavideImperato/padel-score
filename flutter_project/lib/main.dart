import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/padel_score_provider.dart';
import 'screens/app_home_screen.dart';
import 'services/app_orientation.dart';
import 'services/app_preferences.dart';
import 'services/tts_service.dart';
import 'widgets/padel_startup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Mostra subito il loader: prima runApp attendeva TTS e preferenze,
  // lasciando visibile la schermata nativa di avvio.
  runApp(const PadelStartupApp());
}

class PadelAppDependencies {
  const PadelAppDependencies({required this.ttsService, required this.preferences});

  final TtsService ttsService;
  final AppPreferences preferences;
}

Future<PadelAppDependencies> initializePadelApp() async {
  // Conserva gli orientamenti della Fase 7A: Home portrait, match landscape.
  await AppOrientation.home();
  try {
    await WakelockPlus.enable();
  } catch (_) {
    // Alcuni dispositivi/simulatori non supportano il wakelock.
  }
  final ttsService = TtsService();
  await ttsService.init();
  final appPreferences = await AppPreferences.load(ttsService);
  return PadelAppDependencies(ttsService: ttsService, preferences: appPreferences);
}

/// Consente di verificare l'avvio con un initializer controllato nei test.
class PadelStartupApp extends StatefulWidget {
  const PadelStartupApp({super.key, this.initialize = initializePadelApp});

  final Future<PadelAppDependencies> Function() initialize;

  @override
  State<PadelStartupApp> createState() => _PadelStartupAppState();
}

class _PadelStartupAppState extends State<PadelStartupApp> {
  // Lascia visibile almeno una parte del ciclo da 1,1 s della pallina.
  // Evita che una inizializzazione molto veloce sostituisca il loader
  // ancora prima che Flutter ne abbia mostrato il primo frame.
  static const Duration _minimumLoaderDuration = Duration(milliseconds: 850);
  PadelAppDependencies? _dependencies;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Esegui inizializzazione e tempo minimo in parallelo: se i servizi
      // impiegano più tempo, non viene aggiunta ulteriore attesa.
      final results = await Future.wait<Object?>([
        widget.initialize(),
        Future<Object?>.delayed(_minimumLoaderDuration, () => null),
      ]);
      final dependencies = results.first! as PadelAppDependencies;
      if (!mounted) return;
      setState(() {
        _dependencies = dependencies;
        _error = null;
      });
    } catch (error) {
      debugPrint('[PadelStartupApp] Errore avvio: $error');
      if (!mounted) return;
      setState(() => _error = 'Controlla il dispositivo e riprova.');
    }
  }

  void _retry() {
    setState(() => _error = null);
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: PadelStartupScreen(error: _error, onRetry: _retry),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PadelScoreProvider(ttsService: dependencies.ttsService),
        ),
        ChangeNotifierProvider<AppPreferences>.value(
          value: dependencies.preferences,
        ),
      ],
      child: const PadelScoreBotApp(),
    );
  }
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
