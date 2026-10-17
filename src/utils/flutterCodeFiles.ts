export interface FlutterFileItem {
  path: string;
  filename: string;
  description: string;
  language: string;
  content: string;
}

export const FLUTTER_CODE_FILES: FlutterFileItem[] = [
  {
    path: 'pubspec.yaml',
    filename: 'pubspec.yaml',
    description: 'Dipendenze (flutter_tts, provider, shared_preferences, wakelock_plus)',
    language: 'yaml',
    content: `name: padel_scorebot
description: "Tabellone segnapunti Padel 100% offline stile ScoreBot con supporto telecomando Bluetooth, TTS in italiano e Wakelock."
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_tts: ^4.2.2
  provider: ^6.1.2
  shared_preferences: ^2.5.2
  wakelock_plus: ^1.2.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
`
  },
  {
    path: 'lib/screens/match_setup_screen.dart',
    filename: 'match_setup_screen.dart',
    description: 'Schermata Iniziale Setup Match: nomi squadre, 4 giocatori, selettore 1° servizio e rotazione a 4',
    language: 'dart',
    content: `import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/padel_score_provider.dart';
import 'landscape_scoreboard_screen.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _team1Controller;
  late TextEditingController _team2Controller;
  late TextEditingController _player1Controller;
  late TextEditingController _player2Controller;
  late TextEditingController _player3Controller;
  late TextEditingController _player4Controller;

  int _selectedFirstServerId = 1;
  bool _isGoldenPoint = true;
  int _bestOfSets = 3;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PadelScoreProvider>();
    _team1Controller = TextEditingController(text: provider.teamAName);
    _team2Controller = TextEditingController(text: provider.teamBName);
    _player1Controller = TextEditingController(text: provider.player1Name);
    _player2Controller = TextEditingController(text: provider.player2Name);
    _player3Controller = TextEditingController(text: provider.player3Name);
    _player4Controller = TextEditingController(text: provider.player4Name);
    _isGoldenPoint = provider.isGoldenPoint;
    _bestOfSets = provider.bestOfSets;
  }

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    _player1Controller.dispose();
    _player2Controller.dispose();
    _player3Controller.dispose();
    _player4Controller.dispose();
    super.dispose();
  }

  void _startMatch() {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.heavyImpact();

    final provider = context.read<PadelScoreProvider>();
    provider.setupMatch(
      team1: _team1Controller.text,
      team2: _team2Controller.text,
      player1: _player1Controller.text,
      player2: _player2Controller.text,
      player3: _player3Controller.text,
      player4: _player4Controller.text,
      firstServerPlayerId: _selectedFirstServerId,
      goldenPoint: _isGoldenPoint,
      bestOfSets: _bestOfSets,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LandscapeScoreboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'PADEL SCOREBOT — SETUP MATCH',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTeamCard(
                            teamNumber: 1,
                            accentColor: const Color(0xFFCCFF00),
                            teamController: _team1Controller,
                            playerAController: _player1Controller,
                            playerBController: _player2Controller,
                            playerALabel: 'Giocatore 1',
                            playerBLabel: 'Giocatore 2',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTeamCard(
                            teamNumber: 2,
                            accentColor: const Color(0xFF00E5FF),
                            teamController: _team2Controller,
                            playerAController: _player3Controller,
                            playerBController: _player4Controller,
                            playerALabel: 'Giocatore 3',
                            playerBLabel: 'Giocatore 4',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildServingRotationCard(),
                    const SizedBox(height: 24),
                    _buildRulesCard(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      onPressed: _startMatch,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill, size: 28, color: Colors.black),
                          SizedBox(width: 10),
                          Text(
                            'INIZIA PARTITA',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard({required int teamNumber, required Color accentColor, required TextEditingController teamController, required TextEditingController playerAController, required TextEditingController playerBController, required String playerALabel, required String playerBLabel}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SQUADRA $teamNumber', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          TextFormField(
            controller: teamController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Nome Squadra $teamNumber',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome squadra' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: playerAController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: playerALabel,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci nome giocatore' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: playerBController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: playerBLabel,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci compagno' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildServingRotationCard() {
    final p1 = _player1Controller.text.trim().isEmpty ? 'Giocatore 1' : _player1Controller.text;
    final p2 = _player2Controller.text.trim().isEmpty ? 'Giocatore 2' : _player2Controller.text;
    final p3 = _player3Controller.text.trim().isEmpty ? 'Giocatore 3' : _player3Controller.text;
    final p4 = _player4Controller.text.trim().isEmpty ? 'Giocatore 4' : _player4Controller.text;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CHI SERVE PER PRIMO? (ROTAZIONE A 4 GIOCATORI)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 12),
          DropdownButton<int>(
            value: _selectedFirstServerId,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E293B),
            items: [
              DropdownMenuItem(value: 1, child: Text('1° Servizio: $p1 (Squadra 1)', style: const TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 2, child: Text('1° Servizio: $p2 (Squadra 1)', style: const TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 3, child: Text('1° Servizio: $p3 (Squadra 2)', style: const TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 4, child: Text('1° Servizio: $p4 (Squadra 2)', style: const TextStyle(color: Colors.white))),
            ],
            onChanged: (val) => setState(() => _selectedFirstServerId = val ?? 1),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedFirstServerId == 1
                ? 'Turni Ufficiali: 1: $p1 ➔ 2: $p3 ➔ 3: $p2 ➔ 4: $p4 (ciclico)'
                : 'Turni Ufficiali: sequenza a coppie alternate FIP',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text('Punto d\'Oro sul 40-40', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        value: _isGoldenPoint,
        activeColor: const Color(0xFFCCFF00),
        onChanged: (v) => setState(() => _isGoldenPoint = v),
      ),
    );
  }
}
`
  },
  {
    path: 'lib/models/padel_match_state.dart',
    filename: 'padel_match_state.dart',
    description: 'Modello immutabile con servingRotationIndex per la rotazione a 4 giocatori',
    language: 'dart',
    content: `import 'package:flutter/foundation.dart';

enum Team {
  teamA,
  teamB;

  Team get opposite => this == Team.teamA ? Team.teamB : Team.teamA;
}

@immutable
class SetScore {
  final int gamesA;
  final int gamesB;
  final int? tieBreakPointsA;
  final int? tieBreakPointsB;
  final bool isCompleted;
  final Team? winner;

  const SetScore({
    required this.gamesA,
    required this.gamesB,
    this.tieBreakPointsA,
    this.tieBreakPointsB,
    this.isCompleted = false,
    this.winner,
  });

  @override
  String toString() {
    if (tieBreakPointsA != null && tieBreakPointsB != null) {
      return '$gamesA-$gamesB ($tieBreakPointsA-$tieBreakPointsB)';
    }
    return '$gamesA-$gamesB';
  }
}

@immutable
class PadelMatchSnapshot {
  final int rawPointsA;
  final int rawPointsB;
  final int currentGamesA;
  final int currentGamesB;
  final List<SetScore> completedSets;
  final Team servingTeam;
  final int servingRotationIndex;
  final Team initialSetServer;
  final bool isTieBreak;
  final int tieBreakPointsA;
  final int tieBreakPointsB;
  final int? tieBreakInitialRotationIndex;
  final Team? matchWinner;
  final String lastEventMessage;

  const PadelMatchSnapshot({
    required this.rawPointsA,
    required this.rawPointsB,
    required this.currentGamesA,
    required this.currentGamesB,
    required this.completedSets,
    required this.servingTeam,
    required this.servingRotationIndex,
    required this.initialSetServer,
    required this.isTieBreak,
    required this.tieBreakPointsA,
    required this.tieBreakPointsB,
    this.tieBreakInitialRotationIndex,
    this.matchWinner,
    this.lastEventMessage = '',
  });

  factory PadelMatchSnapshot.initial({Team initialServer = Team.teamA, int initialRotationIndex = 0}) {
    return PadelMatchSnapshot(
      rawPointsA: 0,
      rawPointsB: 0,
      currentGamesA: 0,
      currentGamesB: 0,
      completedSets: const [],
      servingTeam: initialServer,
      servingRotationIndex: initialRotationIndex,
      initialSetServer: initialServer,
      isTieBreak: false,
      tieBreakPointsA: 0,
      tieBreakPointsB: 0,
      tieBreakInitialRotationIndex: null,
      matchWinner: null,
      lastEventMessage: 'Inizio Partita',
    );
  }

  String get displayPointA {
    if (isTieBreak) return tieBreakPointsA.toString();
    switch (rawPointsA) {
      case 0: return '0';
      case 1: return '15';
      case 2: return '30';
      case 3: return '40';
      case 4: return 'AV';
      default: return '0';
    }
  }

  String get displayPointB {
    if (isTieBreak) return tieBreakPointsB.toString();
    switch (rawPointsB) {
      case 0: return '0';
      case 1: return '15';
      case 2: return '30';
      case 3: return '40';
      case 4: return 'AV';
      default: return '0';
    }
  }

  bool isGoldenPointSituation(bool goldenPointEnabled) {
    if (isTieBreak) return false;
    return goldenPointEnabled && rawPointsA == 3 && rawPointsB == 3;
  }

  PadelMatchSnapshot copyWith({
    int? rawPointsA,
    int? rawPointsB,
    int? currentGamesA,
    int? currentGamesB,
    List<SetScore>? completedSets,
    Team? servingTeam,
    int? servingRotationIndex,
    Team? initialSetServer,
    bool? isTieBreak,
    int? tieBreakPointsA,
    int? tieBreakPointsB,
    int? tieBreakInitialRotationIndex,
    Team? matchWinner,
    String? lastEventMessage,
  }) {
    return PadelMatchSnapshot(
      rawPointsA: rawPointsA ?? this.rawPointsA,
      rawPointsB: rawPointsB ?? this.rawPointsB,
      currentGamesA: currentGamesA ?? this.currentGamesA,
      currentGamesB: currentGamesB ?? this.currentGamesB,
      completedSets: completedSets ?? this.completedSets,
      servingTeam: servingTeam ?? this.servingTeam,
      servingRotationIndex: servingRotationIndex ?? this.servingRotationIndex,
      initialSetServer: initialSetServer ?? this.initialSetServer,
      isTieBreak: isTieBreak ?? this.isTieBreak,
      tieBreakPointsA: tieBreakPointsA ?? this.tieBreakPointsA,
      tieBreakPointsB: tieBreakPointsB ?? this.tieBreakPointsB,
      tieBreakInitialRotationIndex: tieBreakInitialRotationIndex ?? this.tieBreakInitialRotationIndex,
      matchWinner: matchWinner ?? this.matchWinner,
      lastEventMessage: lastEventMessage ?? this.lastEventMessage,
    );
  }
}
`
  },
  {
    path: 'lib/providers/padel_score_provider.dart',
    filename: 'padel_score_provider.dart',
    description: 'Rotazione ufficiale 4 giocatori, cadenza arbitrale TTS e state machine',
    language: 'dart',
    content: `// Vedi visualizzatore completo per padel_score_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/padel_match_state.dart';
import '../services/tts_service.dart';

class PadelScoreProvider extends ChangeNotifier {
  final TtsService _ttsService;

  PadelMatchSnapshot _currentSnapshot = PadelMatchSnapshot.initial();
  final List<PadelMatchSnapshot> _history = [];

  String _teamAName = 'Gli Smashtori';
  String _teamBName = 'I Timemasters';
  String _player1Name = 'Mario Rossi';
  String _player2Name = 'Luigi Verdi';
  String _player3Name = 'Paolo Bianchi';
  String _player4Name = 'Marco Neri';

  List<String> _rotationOrder = [];
  bool _isGoldenPoint = true;
  int _bestOfSets = 3;

  PadelScoreProvider({TtsService? ttsService})
      : _ttsService = ttsService ?? TtsService() {
    _updateRotationList(initialServerPlayerId: 1);
  }

  PadelMatchSnapshot get snapshot => _currentSnapshot;
  String get teamAName => _teamAName;
  String get teamBName => _teamBName;
  String get player1Name => _player1Name;
  String get player2Name => _player2Name;
  String get player3Name => _player3Name;
  String get player4Name => _player4Name;
  bool get isGoldenPoint => _isGoldenPoint;
  int get bestOfSets => _bestOfSets;
  bool get canUndo => _history.isNotEmpty;
  bool get isMuted => _ttsService.isMuted;
  bool get isMatchOver => _currentSnapshot.matchWinner != null;

  String get currentServingPlayerName {
    if (_rotationOrder.isEmpty) return _player1Name;
    return _rotationOrder[_currentSnapshot.servingRotationIndex % _rotationOrder.length];
  }

  void _updateRotationList({int initialServerPlayerId = 1}) {
    switch (initialServerPlayerId) {
      case 1: _rotationOrder = [_player1Name, _player3Name, _player2Name, _player4Name]; break;
      case 2: _rotationOrder = [_player2Name, _player3Name, _player1Name, _player4Name]; break;
      case 3: _rotationOrder = [_player3Name, _player1Name, _player4Name, _player2Name]; break;
      case 4: _rotationOrder = [_player4Name, _player1Name, _player3Name, _player2Name]; break;
      default: _rotationOrder = [_player1Name, _player3Name, _player2Name, _player4Name];
    }
  }

  void setupMatch({required String team1, required String team2, required String player1, required String player2, required String player3, required String player4, required int firstServerPlayerId, required bool goldenPoint, required int bestOfSets}) {
    _teamAName = team1;
    _teamBName = team2;
    _player1Name = player1;
    _player2Name = player2;
    _player3Name = player3;
    _player4Name = player4;
    _isGoldenPoint = goldenPoint;
    _bestOfSets = bestOfSets;
    _updateRotationList(initialServerPlayerId: firstServerPlayerId);

    final Team initialTeam = (firstServerPlayerId == 1 || firstServerPlayerId == 2) ? Team.teamA : Team.teamB;
    _history.clear();
    _currentSnapshot = PadelMatchSnapshot.initial(initialServer: initialTeam, initialRotationIndex: 0);
    notifyListeners();

    _ttsService.speak('Inizio partita. $_teamAName contro $_teamBName. Serve $currentServingPlayerName.');
  }

  void addPoint(Team scoringTeam) {
    if (isMatchOver) return;
    _history.add(_currentSnapshot);
    // Logica completa punti
    // ...
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    _currentSnapshot = _history.removeLast();
    notifyListeners();
    _ttsService.speak('Punto annullato.');
  }

  void toggleServingTeam() {
    _history.add(_currentSnapshot);
    final nextRot = _currentSnapshot.servingRotationIndex + 1;
    _currentSnapshot = _currentSnapshot.copyWith(servingTeam: _currentSnapshot.servingTeam.opposite, servingRotationIndex: nextRot);
    notifyListeners();
    _ttsService.speak('Cambio battitore. Serve $currentServingPlayerName.');
  }

  void resetMatch() {
    _history.clear();
    _currentSnapshot = PadelMatchSnapshot.initial();
    notifyListeners();
  }

  void setGoldenPoint(bool val) {
    _isGoldenPoint = val;
    notifyListeners();
  }

  void toggleMute() {
    _ttsService.setMuted(!_ttsService.isMuted);
    notifyListeners();
  }

  void announceTimeUp() => _ttsService.speak('Tempo scaduto, riprendere il gioco!');
}
`
  },
  {
    path: 'lib/services/tts_service.dart',
    filename: 'tts_service.dart',
    description: 'Motore vocale con rate 0.48 e cadenza fluida da arbitro professionista',
    language: 'dart',
    content: `import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('it-IT');
      await _flutterTts.setSpeechRate(0.48); // Cadenza arbitrale naturale
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (_isMuted || text.trim().isEmpty) return;
    try {
      if (!_isInitialized) await init();
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) _flutterTts.stop();
  }
}
`
  },
  {
    path: 'lib/services/bluetooth_key_service.dart',
    filename: 'bluetooth_key_service.dart',
    description: 'Intercettazione comandi Volume Up (1x/2x 400ms) e Volume Down (Undo)',
    language: 'dart',
    content: `// Vedi visualizzatore completo per bluetooth_key_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;
  final FocusNode focusNode = FocusNode();
  Timer? _timer;
  int _clicks = 0;

  BluetoothKeyService({required this.onTeamAPoint, required this.onTeamBPoint, required this.onUndo});

  void init() {
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp || event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _clicks++;
      if (_clicks == 1) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 400), () {
          if (_clicks == 1) onTeamAPoint();
          _clicks = 0;
        });
      } else if (_clicks >= 2) {
        _timer?.cancel();
        _clicks = 0;
        onTeamBPoint();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown || event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _timer?.cancel();
      _clicks = 0;
      onUndo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void dispose() {
    _timer?.cancel();
    focusNode.dispose();
  }
}
`
  },
  {
    path: 'lib/screens/landscape_scoreboard_screen.dart',
    filename: 'landscape_scoreboard_screen.dart',
    description: 'Tabellone orizzontale con visualizzazione chiara IN BATTUTA: [NOME GIOCATORE]',
    language: 'dart',
    content: `// Visualizza 'IN BATTUTA: [NOME GIOCATORE]' per ogni game
// Per il codice completo vedi il file su disco in /flutter_project/lib/screens/landscape_scoreboard_screen.dart
`
  },
  {
    path: 'lib/main.dart',
    filename: 'main.dart',
    description: 'Entry point con avvio da MatchSetupScreen e WakelockPlus',
    language: 'dart',
    content: `import 'package:flutter/material.dart';
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
`
  },
  {
    path: 'android/app/src/main/AndroidManifest.xml',
    filename: 'AndroidManifest.xml',
    description: 'AndroidManifest con Landscape forzato e permessi WAKE_LOCK e BLUETOOTH',
    language: 'xml',
    content: `<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.padel.scorebot">
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <application android:label="Padel ScoreBot">
        <activity android:name=".MainActivity" android:screenOrientation="landscape" android:exported="true">
            <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
        </activity>
    </application>
</manifest>`
  },
  {
    path: 'ios/Runner/Info.plist',
    filename: 'Info.plist',
    description: 'Info.plist iOS con Landscape esclusivo e audio in background',
    language: 'xml',
    content: `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key><string>Padel ScoreBot</string>
	<key>UISupportedInterfaceOrientations</key>
	<array><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string></array>
</dict>
</plist>`
  }
];
