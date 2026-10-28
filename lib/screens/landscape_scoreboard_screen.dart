import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/padel_match_state.dart';
import '../providers/padel_score_provider.dart';
import '../services/bluetooth_key_service.dart';
import 'match_setup_screen.dart';
import 'match_result_statistics_screen.dart';
import '../services/app_orientation.dart';
import '../widgets/scoreboard_team_layout.dart';
import '../services/match_history.dart';
import '../widgets/match_result_share_sheet.dart';

class LandscapeScoreboardScreen extends StatefulWidget {
  const LandscapeScoreboardScreen({super.key});

  @override
  State<LandscapeScoreboardScreen> createState() => _LandscapeScoreboardScreenState();
}

class _LandscapeScoreboardScreenState extends State<LandscapeScoreboardScreen> {
  late BluetoothKeyService _keyService;

  // Cronometro durata del match
  bool _isArchiving = false;
  late PadelScoreProvider _provider;
  BuildContext? _winnerDialogContext;
  bool _winnerPopupShown = false;
  String? _winnerPopupMatchId;
  int _watchShareSeen = 0;
  int _watchEndSeen = 0;
  bool _watchExitScheduled = false;

  void _onProviderChanged() {
    if (!mounted) return;
    // Pausa/riprendi impartiti dal Watch aggiornano anche il timer della UI.
    if (_isTimerRunning != _provider.isTimerRunning) {
      setState(() => _isTimerRunning = _provider.isTimerRunning);
    }
    if (_provider.watchShareSequence != _watchShareSeen) {
      _watchShareSeen = _provider.watchShareSequence;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _provider.isMatchOver) unawaited(_shareFinishedMatch(_provider));
      });
    }
    if (!_provider.isMatchOver && _winnerDialogContext != null) {
      final popup = _winnerDialogContext;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (popup != null && popup.mounted && ModalRoute.of(popup)?.isCurrent == true) {
          Navigator.of(popup).pop();
        }
      });
    }
    _scheduleWinnerPopupIfNeeded();
    if (_provider.watchEndSequence != _watchEndSeen && !_watchExitScheduled) {
      _watchEndSeen = _provider.watchEndSequence;
      _watchExitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_provider.tournamentLink != null) {
          unawaited(_returnToTournament());
        } else {
          Navigator.of(context).popUntil((route) => route is PageRoute);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
          );
        }
      });
    }
  }

  Future<void> _returnToTournament() async {
    final dialogContext = _winnerDialogContext;
    if (dialogContext != null && dialogContext.mounted &&
        ModalRoute.of(dialogContext)?.isCurrent == true) {
      final route = ModalRoute.of(dialogContext);
      Navigator.of(dialogContext).pop();
      if (route != null) await route.completed;
    }
    await AppOrientation.home();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

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
    // L'orientamento è richiesto dal percorso di navigazione tramite
    // AppOrientation.match(). Su iPadOS la finestra può restare verticale:
    // ScoreboardTeamLayout adatta il punteggio senza perdere i comandi.

    // Nasconde la barra di navigazione e di stato per massima immersività
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 2. Inizializzazione del servizio telecomando Bluetooth con debounce e feedback visivo
    final provider = context.read<PadelScoreProvider>();
    _provider = provider;
    _watchEndSeen = provider.watchEndSequence;
    _watchShareSeen = provider.watchShareSequence;
    provider.addListener(_onProviderChanged);
    // Anche un match terminato e ripristinato mostra le azioni principali.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleWinnerPopupIfNeeded());
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
    _provider.removeListener(_onProviderChanged);
    // Il ritorno al verticale è gestito dalla Home: il setup resta landscape.
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
        backgroundColor: const Color(0xFF101D3A),
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
                        return ScoreboardTeamLayout(
                          swapSides: provider.isSidesSwapped,
                          teamA: _buildTeamColumn(
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
                          teamB: _buildTeamColumn(
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
                      },
                    ),
                  ),

                  // Barra Inferiore: Storico Set Completo
                  _buildSetsHistoryBar(provider, snapshot),
                ],
              ),

              // Le azioni sono raccolte nel menu della barra superiore: niente
              // pulsanti flottanti che coprono game, giocatori o risultato.

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

  /// HUD compatto e responsivo: nessun contenuto può uscire dallo schermo.
  Widget _buildHeaderBar(
    BuildContext context,
    PadelScoreProvider provider,
    PadelMatchSnapshot snapshot,
  ) {
    final currentSetNumber = snapshot.completedSets.length + 1;
    final mode = !provider.isGoldenPoint
        ? 'VANTAGGI'
        : provider.advantagesBeforeGoldenPoint == 2
            ? 'STAR POINT'
            : 'PUNTO D’ORO';
    final setLabel = provider.isMatchOver
        ? 'PARTITA TERMINATA'
        : snapshot.isMatchTieBreak
            ? 'MATCH TIE-BREAK'
            : snapshot.isTieBreak
                ? 'TIE-BREAK · SET $currentSetNumber'
                : 'SET $currentSetNumber';
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        return Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Row(
            children: [
              IconButton(
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                visualDensity: VisualDensity.compact,
                tooltip: provider.tournamentLink == null ? 'Torna al setup' : 'Salva e torna al torneo',
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white70),
                onPressed: () {
                  if (provider.tournamentLink == null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MatchSetupScreen()));
                  } else if (provider.isMatchOver) {
                    unawaited(_archiveFinishedMatch(provider));
                  } else {
                    unawaited(_archiveInterruptedMatch(provider));
                  }
                },
              ),
              if (!narrow) ...[
                const SizedBox(width: 6),
                Text(mode,
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: Color(0xFFFACC15),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Tooltip(
                message: _isTimerRunning ? 'Metti in pausa il cronometro' : 'Riprendi il cronometro',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() => _isTimerRunning = !_isTimerRunning);
                    provider.updateClock(_elapsedSeconds, _isTimerRunning,
                      breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_isTimerRunning ? Icons.timer_outlined : Icons.pause_circle_outline,
                        size: 18, color: _isTimerRunning ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      const SizedBox(width: 5),
                      Text(_formatTime(_elapsedSeconds),
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Center(
                  child: Text(setLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w800, letterSpacing: .7)),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                visualDensity: VisualDensity.compact,
                tooltip: 'Annulla ultimo punto',
                onPressed: provider.canUndo ? () {
                  HapticFeedback.mediumImpact();
                  provider.undo();
                } : null,
                icon: Icon(Icons.undo_rounded, size: 22,
                  color: provider.canUndo ? Colors.white : Colors.white24),
              ),
              PopupMenuButton<String>(
                tooltip: 'Altre azioni e impostazioni',
                icon: const Icon(Icons.more_vert_rounded, size: 24, color: Colors.white),
                onSelected: (action) => _handleScoreboardAction(action, provider),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'serve', child: Text('Cambia battitore')),
                  const PopupMenuItem(value: 'sides', child: Text('Cambia campo · Pausa 90s')),
                  PopupMenuItem(value: 'mute',
                    child: Text(provider.isMuted ? 'Attiva voce' : 'Disattiva voce')),
                  const PopupMenuDivider(),
                  if (provider.isMatchOver)
                    const PopupMenuItem(value: 'result', child: Text('Riepilogo finale')),
                  if (provider.isMatchOver)
                    const PopupMenuItem(value: 'stats', child: Text('Analisi della partita')),
                  if (provider.isMatchOver)
                    const PopupMenuItem(value: 'share', child: Text('Condividi risultato')),
                  if (provider.isMatchOver)
                    const PopupMenuItem(value: 'archive', child: Text('Salva risultato e chiudi'))
                  else
                    const PopupMenuItem(value: 'interrupt', child: Text('Salva e interrompi')),
                  const PopupMenuItem(value: 'reset', child: Text('Azzera partita')),
                  PopupMenuItem(value: 'setup', child: Text(
                    provider.tournamentLink == null ? 'Torna al setup' : 'Salva e torna al torneo')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleScoreboardAction(String action, PadelScoreProvider provider) {
    switch (action) {
      case 'serve':
        provider.toggleServingTeam();
        return;
      case 'sides':
        provider.switchSides();
        _startBreakTimer(duration: 90);
        return;
      case 'mute':
        provider.toggleMute();
        return;
      case 'interrupt':
        unawaited(_archiveInterruptedMatch(provider));
        return;
      case 'result':
        unawaited(_showWinnerPopup(provider));
        return;
      case 'stats':
        unawaited(_openFinishedStatistics(provider));
        return;
      case 'share':
        unawaited(_shareFinishedMatch(provider));
        return;
      case 'archive':
        unawaited(_archiveFinishedMatch(provider));
        return;
      case 'reset':
        _confirmResetDialog(context, provider);
        return;
      case 'setup':
        if (provider.tournamentLink != null) {
          if (provider.isMatchOver) {
            unawaited(_archiveFinishedMatch(provider));
          } else {
            unawaited(_archiveInterruptedMatch(provider));
          }
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
          );
        }
        return;
    }
  }

  Future<void> _archiveInterruptedMatch(PadelScoreProvider provider) async {
    if (_isArchiving || provider.isMatchOver) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Interrompere la partita?'),
        content: const Text('Potrai riprenderla dallo storico delle partite interrotte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salva e interrompi')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _isArchiving = true);
    provider.updateClock(_elapsedSeconds, false,
      breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
    final saved = await provider.interruptAndArchiveMatch();
    if (!mounted) return;
    if (saved) {
      if (provider.tournamentLink != null) {
        await _returnToTournament();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
        );
      }
    } else {
      setState(() => _isArchiving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Salvataggio non riuscito: partita ancora recuperabile.'),
      ));
    }
  }

  Future<void> _shareFinishedMatch(PadelScoreProvider provider) async {
    if (_isArchiving || !provider.isMatchOver) return;
    final record = MatchHistoryStore.buildRecord(
      id: provider.watchMatchId,
      snapshot: provider.snapshot,
      durationSeconds: _elapsedSeconds,
      teamAName: provider.teamAName,
      teamBName: provider.teamBName,
      players: [provider.player1Name, provider.player2Name,
        provider.player3Name, provider.player4Name],
      playerIds: provider.playerIds,
      bestOfSets: provider.bestOfSets,
      gamesPerSet: provider.shortSets ? 4 : 6,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      pointEvents: provider.hasCompletePointEvents ? provider.pointEvents : null,
      tournamentLink: provider.tournamentLink,
    );
    if (!mounted) return;
    await MatchResultShareSheet.show(context, record);
  }

  void _scheduleWinnerPopupIfNeeded() {
    if (!mounted || _watchExitScheduled || _isArchiving) return;
    final p = _provider;
    if (!p.isMatchOver) {
      _winnerPopupShown = false;
      _winnerPopupMatchId = null;
      return;
    }
    if (_winnerPopupShown && _winnerPopupMatchId == p.watchMatchId) return;
    _winnerPopupShown = true;
    _winnerPopupMatchId = p.watchMatchId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && p.isMatchOver && !_isArchiving) unawaited(_showWinnerPopup(p));
    });
  }

  Map<String, dynamic> _finishedRecord(PadelScoreProvider provider) =>
      MatchHistoryStore.buildRecord(
        id: provider.watchMatchId, snapshot: provider.snapshot,
        durationSeconds: _elapsedSeconds,
        teamAName: provider.teamAName, teamBName: provider.teamBName,
        players: [provider.player1Name, provider.player2Name,
          provider.player3Name, provider.player4Name],
        playerIds: provider.playerIds,
        bestOfSets: provider.bestOfSets,
        gamesPerSet: provider.shortSets ? 4 : 6,
        completedAt: DateTime.now().millisecondsSinceEpoch,
        pointEvents: provider.hasCompletePointEvents ? provider.pointEvents : null,
        tournamentLink: provider.tournamentLink,
      );

  Future<void> _openFinishedStatistics(PadelScoreProvider provider) async {
    if (!mounted || !provider.isMatchOver) return;
    final data = _finishedRecord(provider);
    await AppOrientation.home();
    if (!mounted) return;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchResultStatisticsScreen(record: data),
      ));
    } finally {
      if (mounted) await AppOrientation.match();
    }
  }

  Future<void> _showWinnerPopup(PadelScoreProvider provider) async {
    if (!mounted || !provider.isMatchOver) return;
    final winner = provider.snapshot.matchWinner!;
    final winName = provider.getTeamName(winner);
    final winSets = provider.snapshot.completedSets.where((s) => s.winner == winner).length;
    final loseSets = provider.snapshot.completedSets.length - winSets;
    await showDialog<void>(context: context, barrierDismissible: true,
      builder: (dialogContext) {
        _winnerDialogContext = dialogContext;
        return Dialog(
        backgroundColor: const Color(0xFF142341),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(tooltip: 'Chiudi riepilogo', onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18)),
              ]),
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFCCFF00), size: 30),
              Text('VINCONO $winName', textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 20, fontWeight: FontWeight.w900)),
              Text('$winSets – $loseSets', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Prima del salvataggio puoi ancora correggere con Undo.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 13),
              Row(children: [
                Expanded(child: FilledButton.tonal(
                  onPressed: () => unawaited(_shareFinishedMatch(provider)),
                  child: const Text('Condividi', maxLines: 1, overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 7),
                Expanded(child: FilledButton.tonal(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _openFinishedStatistics(provider);
                  }, child: const Text('Statistiche', maxLines: 1, overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 7),
                Expanded(child: FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    unawaited(_archiveFinishedMatch(provider));
                  }, child: Text(provider.tournamentLink != null ? 'Torna al torneo' : '+ Nuovo incontro',
                    maxLines: 2, textAlign: TextAlign.center))),
              ]),
            ],
          )),
        ),
      );
      },
    );
    _winnerDialogContext = null;
  }

  Future<void> _archiveFinishedMatch(PadelScoreProvider provider) async {
    if (_isArchiving || !provider.isMatchOver) return;
    setState(() => _isArchiving = true);
    provider.updateClock(_elapsedSeconds, false,
      breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
    final saved = await provider.archiveFinishedMatch();
    if (!mounted) return;
    if (saved) {
      if (provider.tournamentLink != null) {
        if (provider.lastTournamentSyncError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Partita salvata nello Storico. Torneo: ${provider.lastTournamentSyncError}')));
        }
        await _returnToTournament();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MatchSetupScreen()),
        );
      }
    } else {
      setState(() => _isArchiving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Salvataggio non riuscito. Riprova prima di uscire.'),
      ));
    }
  }

  /// Il punteggio resta il focus: numeri ad altezza adattiva, team e servizio
  /// compatti, game come dettaglio. Nessun overlay sul numero centrale.
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
    final serveName = provider.currentServingPlayerName;
    return Material(
      color: const Color(0xFF101D3A),
      child: InkWell(
        onTap: onTap,
        splashColor: accentColor.withValues(alpha: 0.16),
        highlightColor: accentColor.withValues(alpha: 0.07),
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 235;
            final horizontal = box.maxWidth < 340 ? 10.0 : 22.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(horizontal, compact ? 6 : 10, horizontal, 5),
              child: Column(
                children: [
                  // Squadra e coppia sono visibili ma non rubano spazio ai punti.
                  Text(
                    teamName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 14 : 19,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '$player1  ·  $player2',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      color: const Color(0xFFACBCD0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  // Nessun badge luminoso ingombrante: solo un marcatore sobrio.
                  SizedBox(
                    height: compact ? 14 : 18,
                    child: isServing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.circle, size: 6, color: accentColor),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'SERVE $serveName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFE5ECF5),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  // FittedBox usa tutto lo spazio disponibile, inclusi schermi
                  // piccoli: evita tagli per punteggi lunghi e tie-break.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, scoreBox) {
                        return Center(
                          child: SizedBox(
                            width: scoreBox.maxWidth,
                            height: scoreBox.maxHeight,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Text(
                                scoreText,
                                maxLines: 1,
                                style: TextStyle(
                                  color: scoreText == 'AV'
                                      ? const Color(0xFFFFD26B)
                                      : const Color(0xFFF7F9FF),
                                  fontSize: 300,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -10,
                                  height: 0.94,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: compact ? 24 : 29,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isTieBreak ? 'TIE-BREAK' : 'GAME',
                          style: const TextStyle(
                            color: Color(0xFFAEBBD0),
                            fontSize: 11,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '$gamesWon',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: compact ? 19 : 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Risultati sintetici scorrevoli: non interferiscono con i punti.
  Widget _buildSetsHistoryBar(PadelScoreProvider provider, PadelMatchSnapshot snapshot) {
    final sets = snapshot.completedSets;
    return Container(
      height: 32,
      width: double.infinity,
      color: const Color(0xFF0B132B),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const SizedBox(width: 12),
          const Icon(Icons.scoreboard_outlined, size: 15, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          ...sets.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text('SET ${entry.key + 1}: ${entry.value}',
              style: const TextStyle(color: Color(0xFFCBD5E1),
                fontSize: 12, fontWeight: FontWeight.w700)),
          )),
          Text(
            provider.isMatchOver
                ? 'PARTITA CONCLUSA'
                : 'SET ${sets.length + 1}: ${snapshot.currentGamesA}–${snapshot.currentGamesB}',
            style: const TextStyle(color: Color(0xFFCCFF00),
              fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 12),
        ]),
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

  /// Avvisi brevi sopra il punteggio; niente cartelloni con ombre.
  Widget _buildMatchStatusBanner(PadelScoreProvider provider, PadelMatchSnapshot snapshot) {
    String message;
    Color tint;
    if (provider.isMatchOver) {
      message = 'PARTITA CONCLUSA · ${provider.getTeamName(snapshot.matchWinner!)}';
      tint = const Color(0xFF33D6A0);
    } else if (snapshot.isTieBreak) {
      message = snapshot.isMatchTieBreak
          ? 'MATCH TIE-BREAK · ${provider.decidingTieBreakPoints} PUNTI'
          : 'TIE-BREAK';
      tint = const Color(0xFFE5B9FF);
    } else {
      message = provider.advantagesBeforeGoldenPoint == 2
          ? 'STAR POINT DECISIVO'
          : 'PUNTO D’ORO DECISIVO';
      tint = const Color(0xFFFFD65A);
    }
    return Positioned(
      top: 47,
      left: 8,
      right: 8,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF101A30).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tint.withValues(alpha: 0.65)),
            ),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint, fontSize: 10, fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
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
