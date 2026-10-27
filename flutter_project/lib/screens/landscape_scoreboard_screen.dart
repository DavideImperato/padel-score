import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/padel_match_state.dart';
import '../providers/padel_score_provider.dart';
import '../services/bluetooth_key_service.dart';
import 'match_setup_screen.dart';

class LandscapeScoreboardScreen extends StatefulWidget {
  const LandscapeScoreboardScreen({super.key});

  @override
  State<LandscapeScoreboardScreen> createState() => _LandscapeScoreboardScreenState();
}

class _LandscapeScoreboardScreenState extends State<LandscapeScoreboardScreen> {
  late BluetoothKeyService _keyService;

  // Cronometro durata del match
  bool _isArchiving = false;
  Timer? _matchTimer;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = true;

  // Timer Cambio Campo (90s regolamentari FIP / 120s a fine set)
  Timer? _breakTimer;
  int _breakSecondsLeft = 0;
  bool _isBreakActive = false;

  @override
  void initState() {
    super.initState();
    // 1. FORZATURA ORIENTAMENTO ESCLUSIVAMENTE ORIZZONTALE (LANDSCAPE)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Nasconde la barra di navigazione e di stato per massima immersività
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 2. Inizializzazione del servizio telecomando Bluetooth con debounce e feedback visivo
    final provider = context.read<PadelScoreProvider>();
    _elapsedSeconds = provider.elapsedSeconds;
    _isTimerRunning = provider.isTimerRunning;
    _breakSecondsLeft = provider.breakSecondsLeft;
    _isBreakActive = provider.isBreakActive;
    _keyService = BluetoothKeyService(
      onTeamAPoint: () {
        HapticFeedback.heavyImpact();
        provider.addPoint(Team.teamA);
      },
      onTeamBPoint: () {
        HapticFeedback.heavyImpact();
        provider.addPoint(Team.teamB);
      },
      onUndo: () {
        HapticFeedback.mediumImpact();
        provider.undo();
      },
      onFeedback: (type, label) {
        _showRemoteFeedback(type, label);
      },
    );

    _keyService.init();

    // 3. Avvio cronometro partita
    _startMatchTimer();
    if (_isBreakActive && _breakSecondsLeft > 0) {
      _startBreakTimer(duration: _breakSecondsLeft);
    }
  }

  // Feedback visivo a schermo per azioni da telecomando/tastiera
  String? _remoteFeedbackText;
  Color _remoteFeedbackColor = const Color(0xFFCCFF00);
  Timer? _feedbackDismissTimer;

  void _showRemoteFeedback(String type, String message) {
    _feedbackDismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _remoteFeedbackText = message;
      if (type == 'teamA') {
        _remoteFeedbackColor = const Color(0xFFCCFF00); // Giallo Fluo
      } else if (type == 'teamB') {
        _remoteFeedbackColor = const Color(0xFF00E5FF); // Ciano Elettrico
      } else {
        _remoteFeedbackColor = const Color(0xFFF43F5E); // Rosa / Rosso Undo
      }
    });

    _feedbackDismissTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _remoteFeedbackText = null;
        });
      }
    });
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final provider = context.read<PadelScoreProvider>();
      if (provider.isMatchOver && _isTimerRunning) {
        setState(() => _isTimerRunning = false);
        provider.updateClock(_elapsedSeconds, false,
          breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
      } else if (_isTimerRunning) {
        setState(() => _elapsedSeconds++);
        provider.updateClock(_elapsedSeconds, true,
          breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
      }
    });
  }

  void _startBreakTimer({int duration = 90}) {
    HapticFeedback.vibrate();
    _breakTimer?.cancel();
    setState(() {
      _breakSecondsLeft = duration;
      _isBreakActive = true;
    });
    context.read<PadelScoreProvider>().updateClock(_elapsedSeconds, _isTimerRunning,
      breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_breakSecondsLeft > 1) {
        setState(() {
          _breakSecondsLeft--;
        });
        context.read<PadelScoreProvider>().updateClock(_elapsedSeconds, _isTimerRunning,
          breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
      } else {
        _stopBreakTimer();
        HapticFeedback.vibrate();
        context.read<PadelScoreProvider>().announceTimeUp();
      }
    });
  }

  void _stopBreakTimer() {
    _breakTimer?.cancel();
    if (mounted) {
      setState(() {
        _isBreakActive = false;
        _breakSecondsLeft = 0;
      });
      context.read<PadelScoreProvider>().updateClock(_elapsedSeconds, _isTimerRunning);
    }
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _breakTimer?.cancel();
    _feedbackDismissTimer?.cancel();
    _keyService.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PadelScoreProvider>();
    final snapshot = provider.snapshot;

    return KeyboardListener(
      focusNode: _keyService.focusNode,
      autofocus: true,
      onKeyEvent: (event) => _keyService.handleKeyEvent(_keyService.focusNode, event),
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: SafeArea(
          child: Stack(
            children: [
              // CORPO PRINCIPALE: DUE COLONNE (SQUADRA A vs SQUADRA B)
              Column(
                children: [
                  // Barra Superiore
                  _buildHeaderBar(context, provider, snapshot),

                  // Area Punteggio a 2 Macro Colonne
                  // Area Punteggio a 2 Macro Colonne (Invertibili visivamente al cambio campo)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final teamACol = Expanded(
                          child: _buildTeamColumn(
                            context: context,
                            provider: provider,
                            team: Team.teamA,
                            teamName: provider.teamAName,
                            player1: provider.player1Name,
                            player2: provider.player2Name,
                            scoreText: snapshot.displayPointA,
                            isServing: snapshot.servingTeam == Team.teamA,
                            gamesWon: snapshot.currentGamesA,
                            isTieBreak: snapshot.isTieBreak,
                            accentColor: const Color(0xFFCCFF00), // Giallo Fluorescente Padel
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              provider.addPoint(Team.teamA);
                            },
                          ),
                        );

                        final divider = Container(
                          width: 3,
                          color: const Color(0xFF1E293B),
                        );

                        final teamBCol = Expanded(
                          child: _buildTeamColumn(
                            context: context,
                            provider: provider,
                            team: Team.teamB,
                            teamName: provider.teamBName,
                            player1: provider.player3Name,
                            player2: provider.player4Name,
                            scoreText: snapshot.displayPointB,
                            isServing: snapshot.servingTeam == Team.teamB,
                            gamesWon: snapshot.currentGamesB,
                            isTieBreak: snapshot.isTieBreak,
                            accentColor: const Color(0xFF00E5FF), // Ciano Elettrico
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              provider.addPoint(Team.teamB);
                            },
                          ),
                        );

                        return Row(
                          children: provider.isSidesSwapped
                              ? [teamBCol, divider, teamACol]
                              : [teamACol, divider, teamBCol],
                        );
                      },
                    ),
                  ),

                  // Barra Inferiore: Storico Set Completo
                  _buildSetsHistoryBar(provider, snapshot),
                ],
              ),

              if (provider.isMatchOver)
                Positioned(
                  bottom: 56,
                  right: 24,
                  child: ElevatedButton.icon(
                    onPressed: _isArchiving ? null : () async {
                      setState(() => _isArchiving = true);
                      // Sincronizza il timer locale nel provider prima dell'archiviazione.
                      provider.updateClock(_elapsedSeconds, false,
                        breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
                      final ok = await provider.archiveFinishedMatch();
                      if (!mounted) return;
                      if (ok) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
                        );
                      } else {
                        setState(() => _isArchiving = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Salvataggio non riuscito. Riprova prima di uscire.'),
                        ));
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: Text(_isArchiving ? 'SALVATAGGIO…' : 'SALVA NELLO STORICO E CHIUDI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCCFF00),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),

              // OVERLAY CONTROLLI RAPIDI
              _buildTopFloatingControls(context, provider),

              // OVERLAY NOTIFICHE (Tie-Break, Punto d'Oro, Vittoria Match)
              if (snapshot.isTieBreak || snapshot.isGoldenPointSituation(provider.isGoldenPoint, provider.advantagesBeforeGoldenPoint) || provider.isMatchOver)
                _buildMatchStatusBanner(provider, snapshot),

              // OVERLAY TIMER CAMBIO CAMPO (90s / 120s FIP)
              if (_isBreakActive)
                _buildBreakTimerOverlay(),

              // OVERLAY FEEDBACK VISIVO TELECOMANDO BLUETOOTH (Punto A, Punto B, Undo)
              if (_remoteFeedbackText != null)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B14).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _remoteFeedbackColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _remoteFeedbackColor.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _remoteFeedbackColor == const Color(0xFFF43F5E)
                                ? Icons.undo_rounded
                                : Icons.radio_button_checked,
                            color: _remoteFeedbackColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _remoteFeedbackText!,
                            style: TextStyle(
                              color: _remoteFeedbackColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra superiore con indicatori modalità, cronometro, setup button e guida telecomando
  Widget _buildHeaderBar(
    BuildContext context,
    PadelScoreProvider provider,
    PadelMatchSnapshot snapshot,
  ) {
    final currentSetNumber = snapshot.completedSets.length + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tasto Ritorno a Setup + Regola Punto d'Oro + Cronometro
          Row(
            children: [
              // Pulsante per tornare al Setup o cambiare giocatori
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 16),
                tooltip: 'Torna al Setup Match',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),

              GestureDetector(
                // La modalità sportiva è informativa: si sceglie nel setup.
                onTap: null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: provider.isGoldenPoint ? const Color(0x22FACC15) : const Color(0x2238BDF8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: provider.isGoldenPoint ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.isGoldenPoint ? Icons.stars_rounded : Icons.swap_horiz_rounded,
                        size: 15,
                        color: provider.isGoldenPoint ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        !provider.isGoldenPoint
                            ? 'VANTAGGI CLASSICI'
                            : provider.advantagesBeforeGoldenPoint == 2
                                ? 'STAR POINT'
                                : 'PUNTO D\'ORO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: provider.isGoldenPoint ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Cronometro Match
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isTimerRunning = !_isTimerRunning;
                  });
                  provider.updateClock(_elapsedSeconds, _isTimerRunning,
                    breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTimerRunning ? Icons.timer_outlined : Icons.pause_circle_outline,
                        size: 13,
                        color: _isTimerRunning ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Indicatore Set Corrente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              snapshot.isTieBreak
                  ? (snapshot.isMatchTieBreak ? 'MATCH TIE-BREAK A ${provider.decidingTieBreakPoints}' : 'SET $currentSetNumber: TIE-BREAK')
                  : 'SET $currentSetNumber IN CORSO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Guida Telecomando & Tasto Pausa 90s
          Row(
            children: [
              GestureDetector(
                onTap: () => _startBreakTimer(duration: 90),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top, size: 13, color: Color(0xFF00E5FF)),
                      SizedBox(width: 4),
                      Text(
                        'Pausa 90s',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_connected, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 5),
                    Text(
                      'Vol+: Sq.1 (x1) | Sq.2 (x2) | Vol-: Undo',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Colonna Squadra ad alto contrasto per visibilità a 15 metri
  Widget _buildTeamColumn({
    required BuildContext context,
    required PadelScoreProvider provider,
    required Team team,
    required String teamName,
    required String player1,
    required String player2,
    required String scoreText,
    required bool isServing,
    required int gamesWon,
    required bool isTieBreak,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final servingPlayerName = provider.currentServingPlayerName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accentColor.withValues(alpha: 0.15),
        highlightColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. INTESTAZIONE: Nome Squadra + Nomi Coppia
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          teamName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$player1 & $player2',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 2. INDICATORE SERVIZIO ULTRA CHIARO: "IN BATTUTA: [NOME GIOCATORE]"
                  if (isServing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCCFF00).withValues(alpha: 0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_tennis, size: 16, color: Colors.black),
                          const SizedBox(width: 6),
                          Text(
                            'IN BATTUTA: ${servingPlayerName.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Placeholder invisibile per mantenere la perfetta centratura verticale
                    const SizedBox(height: 27),
                ],
              ),

              // 3. PUNTEGGIO GAME GIGANTE AL CENTRO (Visibile a 15 metri sotto il sole)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        scoreText,
                        style: TextStyle(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          color: scoreText == 'AV'
                              ? const Color(0xFFF59E0B)
                              : Colors.white,
                          height: 0.9,
                          shadows: [
                            Shadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Riquadro Game Vinti nel Set Corrente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'GAME NEL SET: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$gamesWon',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra inferiore con il riepilogo di tutti i Set giocati
  Widget _buildSetsHistoryBar(
    PadelScoreProvider provider,
    PadelMatchSnapshot snapshot,
  ) {
    final sets = snapshot.completedSets;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF0B132B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.scoreboard_outlined, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          const Text(
            'RISULTATO SET: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),

          if (sets.isEmpty)
            const Text(
              'Primo set in corso',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontStyle: FontStyle.italic),
            )
          else
            ...sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: set.winner == Team.teamA
                        ? const Color(0xFFCCFF00).withValues(alpha: 0.5)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Set ${index + 1}: ${set.toString()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),

          // Set corrente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x33CCFF00),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCCFF00)),
            ),
            child: Text(
              'Set ${sets.length + 1} (in corso): ${snapshot.currentGamesA} - ${snapshot.currentGamesB}',
              style: const TextStyle(
                color: Color(0xFFCCFF00),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Toolbar fluttuante rapida
  Widget _buildTopFloatingControls(BuildContext context, PadelScoreProvider provider) {
    return Positioned(
      bottom: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xDD0F172A),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UNDO
            IconButton(
              tooltip: 'Annulla ultimo punto (Undo)',
              icon: Icon(
                Icons.undo_rounded,
                color: provider.canUndo ? Colors.white : Colors.white24,
                size: 24,
              ),
              onPressed: provider.canUndo ? () {
                HapticFeedback.mediumImpact();
                provider.undo();
              } : null,
            ),

            // Scambia Battitore
            IconButton(
              tooltip: 'Avanza rotazione battitore',
              icon: const Icon(Icons.sports_tennis, color: Color(0xFFCCFF00), size: 22),
              onPressed: () => provider.toggleServingTeam(),
            ),

            // Scambia Campo
            IconButton(
              tooltip: 'Scambia campo (e avvia pausa 90s)',
              icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 24),
              onPressed: () {
                provider.switchSides();
                _startBreakTimer(duration: 90);
              },
            ),

            // Mute TTS
            IconButton(
              tooltip: provider.isMuted ? 'Attiva voce TTS' : 'Disattiva voce TTS',
              icon: Icon(
                provider.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: provider.isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                size: 24,
              ),
              onPressed: () => provider.toggleMute(),
            ),

            // Reset
            IconButton(
              tooltip: 'Nuova partita (Reset)',
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFEF4444), size: 24),
              onPressed: () => _confirmResetDialog(context, provider),
            ),

            // Modifica Setup
            IconButton(
              tooltip: 'Modifica Nomi e Setup',
              icon: const Icon(Icons.tune, color: Colors.white, size: 22),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Overlay conto alla rovescia Cambio Campo (90s)
  Widget _buildBreakTimerOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz, size: 48, color: Color(0xFF00E5FF)),
              const SizedBox(height: 12),
              const Text(
                'CAMBIO CAMPO (REGOLA FIP)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$_breakSecondsLeft',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 90,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Riprendi Gioco'),
                onPressed: _stopBreakTimer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner animato per eventi salienti
  Widget _buildMatchStatusBanner(PadelScoreProvider provider, PadelMatchSnapshot snapshot) {
    String message = '';
    Color bannerColor = const Color(0xFFF59E0B);

    if (provider.isMatchOver) {
      final winner = snapshot.matchWinner!;
      message = '🏆 VITTORIA MATCH: ${provider.getTeamName(winner).toUpperCase()}! 🏆';
      bannerColor = const Color(0xFF10B981);
    } else if (snapshot.isTieBreak) {
      message = snapshot.isMatchTieBreak
          ? '⚡ MATCH TIE-BREAK DECISIVO A ${provider.decidingTieBreakPoints} PUNTI ⚡'
          : '⚡ TIE-BREAK A 7 PUNTI ⚡';
      bannerColor = const Color(0xFF8B5CF6);
    } else if (snapshot.isGoldenPointSituation(provider.isGoldenPoint, provider.advantagesBeforeGoldenPoint)) {
      message = provider.advantagesBeforeGoldenPoint == 2
          ? '🔥 40 PARI: STAR POINT DECISIVO! 🔥'
          : '🔥 40 PARI: PUNTO D\'ORO DECISIVO! 🔥';
      bannerColor = const Color(0xFFEF4444);
    }

    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmResetDialog(BuildContext context, PadelScoreProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Resettare la Partita?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tutti i punti, i set e il cronometro verranno azzerati. Sei sicuro?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            child: const Text('Annulla', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Azzera Tutto', style: TextStyle(color: Colors.white)),
            onPressed: () {
              provider.resetMatch();
              _stopBreakTimer();
              setState(() {
                _elapsedSeconds = 0;
                _isTimerRunning = true;
              });
              provider.updateClock(0, true);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
