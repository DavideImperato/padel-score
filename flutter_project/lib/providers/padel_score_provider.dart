import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/padel_match_state.dart';
import '../services/tts_service.dart';
import '../services/match_checkpoint.dart';
import '../services/match_history.dart';
import '../services/match_point_analytics.dart';
import '../services/match_interrupted.dart';
import '../services/tournament_match_link.dart';
import '../services/tournament_store.dart';
import '../services/watch_match_sync.dart';
import '../services/watch_command_gate.dart';

class PadelScoreProvider extends ChangeNotifier {
  final TtsService _ttsService;

  // Snapshot corrente e cronologia per Undo
  PadelMatchSnapshot _currentSnapshot = PadelMatchSnapshot.initial();
  final List<PadelMatchSnapshot> _history = [];
  final List<Map<String, dynamic>> _pointEvents = [];
  List<Map<String, dynamic>> get pointEvents =>
      List.unmodifiable(_pointEvents.map((event) => Map<String, dynamic>.from(event)));
  bool get hasCompletePointEvents => _pointTrackingComplete;
  bool _processingPoint = false;
  bool _pointTrackingComplete = true;

  // Squadre e 4 Giocatori
  String _teamAName = 'Gli Smashtori';
  String _teamBName = 'I Timemasters';

  String _player1Name = 'Mario Rossi';
  String _player2Name = 'Luigi Verdi';
  String _player3Name = 'Paolo Bianchi';
  String _player4Name = 'Marco Neri';
  List<String?> _playerIds = [null, null, null, null];

  // Identificativo del primo battitore (1, 2, 3 o 4)
  int _firstServerPlayerId = 1;

  // Impostazioni regolamento
  bool _isGoldenPoint = true;
  int _advantagesBeforeGoldenPoint = 0; // 0 = subito punto d'oro, 1 = 1 vantaggio poi punto d'oro, 2 = Star Point FIP 2026
  int _bestOfSets = 3;
  bool _decidingMatchTieBreak = false;
  int _decidingTieBreakPoints = 10; // Tie-break decisivo: 7 oppure 10 punti
  bool _shortSets = false; // Mini-set FIP: 4 game, tie-break sul 4-4

  // Checkpoint offline: serializza in coda le scritture, senza invertire i punti rapidi.
  Map<String, dynamic>? _tournamentLink;
  Map<String, dynamic>? get tournamentLink => _tournamentLink == null ? null : Map<String, dynamic>.from(_tournamentLink!);
  String? _lastTournamentSyncError;
  String? get lastTournamentSyncError => _lastTournamentSyncError;
  bool _activeCheckpoint = false;
  bool _finalizingMatch = false;
  String _matchArchiveId = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
  Map<String, dynamic>? _pendingRecovery;
  Future<void> _writeQueue = Future<void>.value();
  final WatchMatchSync _watchSync = const WatchMatchSync();
  final WatchCommandGate _watchCommands = WatchCommandGate();
  int _watchStartSequence = 0;
  int _watchEndSequence = 0;
  int get watchStartSequence => _watchStartSequence;
  int get watchEndSequence => _watchEndSequence;
  bool get hasActiveMatch => _activeCheckpoint;
  String get watchMatchId => _matchArchiveId;
  Future<Map<String, dynamic>> handleWatchCommand(Map<dynamic, dynamic> message) =>
      _handleWatchCommand(message);

  Future<Map<String, dynamic>> _handleWatchCommand(Map<dynamic, dynamic> message) =>
      _watchCommands.accept(message, currentMatchId: () => _matchArchiveId,
          execute: _executeWatchAction);

  Future<Map<String, dynamic>> _executeWatchAction(String action) async {
    if (_finalizingMatch) return {'ok': false, 'code': 'match_busy'};
    if (action == 'start_match') {
      if (_pendingRecovery != null) return {'ok': false, 'code': 'recovery_required'};
      if (_activeCheckpoint) {
        if (_currentSnapshot.matchWinner != null) {
          return {'ok': false, 'code': 'already_finished'};
        }
        updateClock(_elapsedSeconds, true,
            breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
        notifyListeners();
        return {'ok': true, 'code': 'resumed'};
      }
      // Nuovo match con le impostazioni e i nomi gia` configurati su iPhone.
      setupMatch(team1: _teamAName, team2: _teamBName,
        player1: _player1Name, player2: _player2Name,
        player3: _player3Name, player4: _player4Name,
        firstServerPlayerId: _firstServerPlayerId,
        goldenPoint: _isGoldenPoint,
        advantagesBeforeGoldenPoint: _advantagesBeforeGoldenPoint,
        bestOfSets: _bestOfSets, shortSets: _shortSets,
        decidingMatchTieBreak: _decidingMatchTieBreak,
        decidingTieBreakPoints: _decidingTieBreakPoints, playerIds: _playerIds);
      _watchStartSequence++;
      super.notifyListeners();
      return {'ok': true, 'code': 'started'};
    }
    if (action == 'share_result') {
      if (!_activeCheckpoint || _currentSnapshot.matchWinner == null) {
        return {'ok': false, 'code': 'not_finished'};
      }
      _watchShareSequence++;
      notifyListeners();
      return {'ok': true, 'code': 'share_requested'};
    }
    if (action == 'new_match') {
      if (!_activeCheckpoint || _currentSnapshot.matchWinner == null) {
        return {'ok': false, 'code': 'not_finished'};
      }
      final saved = await archiveFinishedMatch();
      if (!saved) return {'ok': false, 'code': 'save_failed'};
      if (_tournamentLink != null) {
        _watchEndSequence++;
        notifyListeners();
        return {'ok': true, 'code': 'archived'};
      }
      // Una partita nuova usa i nomi e le regole confermati sul telefono.
      // Non riassegnare punti e non ripetere il comando in caso di timeout.
      setupMatch(team1: _teamAName, team2: _teamBName,
        player1: _player1Name, player2: _player2Name,
        player3: _player3Name, player4: _player4Name,
        firstServerPlayerId: _firstServerPlayerId,
        goldenPoint: _isGoldenPoint,
        advantagesBeforeGoldenPoint: _advantagesBeforeGoldenPoint,
        bestOfSets: _bestOfSets, shortSets: _shortSets,
        decidingMatchTieBreak: _decidingMatchTieBreak,
        decidingTieBreakPoints: _decidingTieBreakPoints, playerIds: _playerIds);
      _watchStartSequence++;
      notifyListeners();
      return {'ok': true, 'code': 'new_match_started'};
    }
    if (!_activeCheckpoint) return {'ok': false, 'code': 'no_active_match'};
    if (action == 'end_match') {
      final saved = _currentSnapshot.matchWinner == null
          ? await interruptAndArchiveMatch()
          : await archiveFinishedMatch();
      if (!saved) return {'ok': false, 'code': 'save_failed'};
      _watchEndSequence++;
      super.notifyListeners();
      return {'ok': true, 'code': 'archived'};
    }
    // Undo puo` correggere anche l'ultimo punto che ha concluso il match,
    // finche` il risultato non e` stato archiviato.
    if (action == 'undo') {
      if (!canUndo) return {'ok': false, 'code': 'nothing_to_undo'};
      undo();
      return {'ok': true, 'code': 'undone'};
    }
    if (_currentSnapshot.matchWinner != null) {
      return {'ok': false, 'code': 'already_finished'};
    }
    switch (action) {
      case 'switch_sides':
        // Cambia esclusivamente il lato visualizzato; il risultato non cambia.
        switchSides();
        return {'ok': true, 'code': 'sides_switched'};
      case 'change_server':
        // Non permettere di sostituire il battitore nel corso del game.
        if (_currentSnapshot.isTieBreak || _currentSnapshot.rawPointsA != 0 ||
            _currentSnapshot.rawPointsB != 0) {
          return {'ok': false, 'code': 'server_change_between_games_only'};
        }
        toggleServingTeam();
        return {'ok': true, 'code': 'server_changed'};
      case 'rule_golden':
      case 'rule_star':
      case 'rule_one_advantage':
      case 'rule_traditional':
        // La modalita` non fa parte degli snapshot Undo. Cambiarla dopo il
        // primo punto renderebbe incoerenti le azioni di annullamento.
        if (_history.isNotEmpty || _currentSnapshot.completedSets.isNotEmpty ||
            _currentSnapshot.currentGamesA != 0 ||
            _currentSnapshot.currentGamesB != 0 ||
            _currentSnapshot.rawPointsA != 0 ||
            _currentSnapshot.rawPointsB != 0 ||
            _currentSnapshot.isTieBreak) {
          return {'ok': false, 'code': 'rule_locked_after_first_point'};
        }
        if (action == 'rule_traditional') {
          setGoldenPoint(false);
        } else {
          setGoldenPoint(true, action == 'rule_star' ? 2 :
              (action == 'rule_one_advantage' ? 1 : 0));
        }
        return {'ok': true, 'code': 'rule_updated'};
      case 'point_a':
        addPoint(Team.teamA);
        return {'ok': true, 'code': 'point_a'};
      case 'point_b':
        addPoint(Team.teamB);
        return {'ok': true, 'code': 'point_b'};
      case 'pause_match':
      case 'resume_match':
        updateClock(_elapsedSeconds, action == 'resume_match',
            breakSeconds: _breakSecondsLeft, breakActive: _isBreakActive);
        notifyListeners();
        return {'ok': true, 'code': action == 'pause_match' ? 'paused' : 'resumed'};
    }
    return {'ok': false, 'code': 'unsupported_action'};
  }

  bool _lastClockRunningOnWatch = true;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = true;
  int _breakSecondsLeft = 0;
  bool _isBreakActive = false;

  bool get hasSavedMatch => _pendingRecovery != null;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isTimerRunning => _isTimerRunning;
  int get breakSecondsLeft => _breakSecondsLeft;
  bool get isBreakActive => _isBreakActive;

  Map<String, dynamic> _currentCheckpoint() => {
    'matchId': _matchArchiveId,
    'settings': {
      'teamAName': _teamAName, 'teamBName': _teamBName,
      'player1Name': _player1Name, 'player2Name': _player2Name,
      'player3Name': _player3Name, 'player4Name': _player4Name,
      'playerIds': _playerIds,
      'firstServerPlayerId': _firstServerPlayerId,
      'isGoldenPoint': _isGoldenPoint,
      'advantagesBeforeGoldenPoint': _advantagesBeforeGoldenPoint,
      'bestOfSets': _bestOfSets, 'shortSets': _shortSets,
      'decidingMatchTieBreak': _decidingMatchTieBreak,
      'decidingTieBreakPoints': _decidingTieBreakPoints,
    },
    'snapshot': MatchCheckpointCodec.snapshotToJson(_currentSnapshot),
    'history': _history.map(MatchCheckpointCodec.snapshotToJson).toList(),
    'pointEvents': _pointEvents,
    'pointTrackingComplete': _pointTrackingComplete,
    if (_tournamentLink != null) 'tournamentLink': _tournamentLink,
    'runtime': {
      'elapsedSeconds': _elapsedSeconds, 'isTimerRunning': _isTimerRunning,
      'isSidesSwapped': _isSidesSwapped,
      'breakSecondsLeft': _breakSecondsLeft, 'isBreakActive': _isBreakActive,
    },
  };

  Future<void> flushCheckpoint() => _writeQueue;

  /// Conserva il risultato una sola volta, dopo conferma dell'utente.
  /// L'operazione rispetta la coda del checkpoint, poi lo elimina.
  Future<bool> archiveFinishedMatch() async {
    if (_currentSnapshot.matchWinner == null || _finalizingMatch) return false;
    _finalizingMatch = true;
    final record = MatchHistoryStore.buildRecord(
      id: _matchArchiveId, snapshot: _currentSnapshot,
      durationSeconds: _elapsedSeconds,
      teamAName: _teamAName, teamBName: _teamBName,
      players: [_player1Name, _player2Name, _player3Name, _player4Name],
      playerIds: _playerIds,
      bestOfSets: _bestOfSets, gamesPerSet: _shortSets ? 4 : 6,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      pointEvents: _pointTrackingComplete ? _pointEvents : null,
      tournamentLink: _tournamentLink,
    );
    _activeCheckpoint = false;
    var saved = false;
    _writeQueue = _writeQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        saved = await MatchHistoryStore.saveRecord(prefs, record);
        if (saved) await prefs.remove(MatchCheckpointCodec.key);
      } catch (_) { saved = false; }
    });
    await _writeQueue;
    if (!saved) {
      _activeCheckpoint = true;
    } else if (_tournamentLink != null) {
      // Lo storico viene archiviato prima del torneo: se il secondo salvataggio
      // fallisce, la partita resta recuperabile per la riconciliazione.
      _lastTournamentSyncError = await TournamentStore.applyFinishedRecord(record);
    }
    _finalizingMatch = false;
    _publishWatchState();
    return saved;
  }

  /// Move the current unfinished match into the offline paused archive.
  /// Wait for previous point writes before changing the active checkpoint.
  Future<bool> interruptAndArchiveMatch() async {
    if (_currentSnapshot.matchWinner != null || _finalizingMatch) return false;
    _finalizingMatch = true;
    final snapshot = _currentCheckpoint();
    _activeCheckpoint = false;
    var saved = false;
    _writeQueue = _writeQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        saved = await MatchInterruptedStore.save(prefs, snapshot);
        if (saved) saved = await prefs.remove(MatchCheckpointCodec.key);
      } catch (_) { saved = false; }
    });
    await _writeQueue;
    if (!saved) _activeCheckpoint = true;
    _finalizingMatch = false;
    _publishWatchState();
    return saved;
  }

  /// Re-create an active checkpoint before removing the paused archive entry.
  Future<bool> resumeInterruptedMatch(String id) async {
    if (_activeCheckpoint || _pendingRecovery != null || _finalizingMatch) return false;
    try {
      await _writeQueue;
      final prefs = await SharedPreferences.getInstance();
      final list = MatchInterruptedStore.decode(prefs.getString(MatchInterruptedStore.key));
      if (list == null) return false;
      final items = list.where((item) => item['id'] == id);
      if (items.isEmpty) return false;
      final data = Map<String, dynamic>.from(items.first['checkpoint'] as Map);
      final encoded = MatchCheckpointCodec.encode(data);
      final decoded = MatchCheckpointCodec.decode(encoded);
      if (decoded == null || !(await prefs.setString(MatchCheckpointCodec.key, encoded))) return false;
      _pendingRecovery = decoded;
      if (!resumeSavedMatch()) return false;
      await flushCheckpoint();
      await MatchInterruptedStore.delete(id); // If deletion fails, active match is still safe.
      return true;
    } catch (_) { return false; }
  }

  void _scheduleCheckpoint() {
    if (!_activeCheckpoint) return;
    final encoded = MatchCheckpointCodec.encode(_currentCheckpoint());
    _writeQueue = _writeQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(MatchCheckpointCodec.key, encoded);
      } catch (_) { /* storage non disponibile: partita continua in memoria */ }
    });
  }

  /// Il provider iPhone e` l'unica fonte del risultato.
  /// Invio non bloccante: se il Watch e` assente, il punteggio continua.
  void _publishWatchState() {
    final payload = buildWatchMatchState(
      matchId: _matchArchiveId,
      active: _activeCheckpoint,
      awaitingRecovery: _pendingRecovery != null,
      snapshot: _currentSnapshot,
      teamAName: _teamAName,
      teamBName: _teamBName,
      players: [_player1Name, _player2Name, _player3Name, _player4Name],
      servingPlayer: currentServingPlayerName,
      servingPlayerId: currentServerPlayerId,
      goldenPoint: _isGoldenPoint,
      advantagesBeforeGoldenPoint: _advantagesBeforeGoldenPoint,
      shortSets: _shortSets,
      bestOfSets: _bestOfSets,
      decidingMatchTieBreak: _decidingMatchTieBreak,
      decidingTieBreakPoints: _decidingTieBreakPoints,
      elapsedSeconds: _elapsedSeconds,
      timerRunning: _isTimerRunning,
      canUndo: canUndo,
      tournamentMatch: _tournamentLink != null,
      sidesSwapped: _isSidesSwapped,
      canChangeRules: _activeCheckpoint &&
          _currentSnapshot.matchWinner == null && _history.isEmpty &&
          _currentSnapshot.completedSets.isEmpty &&
          _currentSnapshot.currentGamesA == 0 &&
          _currentSnapshot.currentGamesB == 0 &&
          _currentSnapshot.rawPointsA == 0 && _currentSnapshot.rawPointsB == 0 &&
          !_currentSnapshot.isTieBreak,
      canChangeServer: _activeCheckpoint &&
          _currentSnapshot.matchWinner == null && !_currentSnapshot.isTieBreak &&
          _currentSnapshot.rawPointsA == 0 && _currentSnapshot.rawPointsB == 0,
    );
    unawaited(_watchSync.publish(payload));
  }

  @override
  void notifyListeners() {
    if (_processingPoint) return;
    _scheduleCheckpoint();
    _publishWatchState();
    super.notifyListeners();
  }

  /// Aggiorna l'orologio senza ricostruire l'intero tabellone ad ogni secondo.
  void updateClock(int seconds, bool running, {int breakSeconds = 0, bool breakActive = false}) {
    _elapsedSeconds = seconds;
    _isTimerRunning = running;
    _breakSecondsLeft = breakSeconds;
    _isBreakActive = breakActive;
    _scheduleCheckpoint();
    // 15 s bastano per il cronometro Watch, ma le pause si notificano subito.
    if (seconds % 15 == 0 || running != _lastClockRunningOnWatch) {
      _publishWatchState();
    }
    _lastClockRunningOnWatch = running;
  }

  /// Ripristino esplicito: nessun annuncio TTS e nessun nuovo punto.
  bool resumeSavedMatch() {
    final checkpoint = _pendingRecovery;
    if (checkpoint == null) return false;
    try {
      final config = Map<String, dynamic>.from(checkpoint['settings'] as Map);
      final runtime = Map<String, dynamic>.from(checkpoint['runtime'] as Map);
      final snap = MatchCheckpointCodec.snapshotFromJson(Map<String, dynamic>.from(checkpoint['snapshot'] as Map));
      final history = (checkpoint['history'] as List).map((e) => MatchCheckpointCodec.snapshotFromJson(Map<String, dynamic>.from(e as Map))).toList();
      _configurationVersion++;
      _matchArchiveId = checkpoint['matchId'] is String && (checkpoint['matchId'] as String).isNotEmpty
          ? checkpoint['matchId'] as String : 'flutter-${DateTime.now().microsecondsSinceEpoch}';
      _teamAName = config['teamAName'] as String;
      _teamBName = config['teamBName'] as String;
      _player1Name = config['player1Name'] as String;
      _player2Name = config['player2Name'] as String;
      _player3Name = config['player3Name'] as String;
      _player4Name = config['player4Name'] as String;
      _playerIds = _validPlayerIds(config['playerIds']);
      _firstServerPlayerId = config['firstServerPlayerId'] as int;
      _isGoldenPoint = config['isGoldenPoint'] as bool;
      _advantagesBeforeGoldenPoint = config['advantagesBeforeGoldenPoint'] as int;
      _bestOfSets = config['bestOfSets'] as int;
      _shortSets = config['shortSets'] as bool;
      _decidingMatchTieBreak = config['decidingMatchTieBreak'] as bool;
      _decidingTieBreakPoints = config['decidingTieBreakPoints'] as int;
      _currentSnapshot = snap;
      _history..clear()..addAll(history);
      // I vecchi checkpoint non hanno eventi: nessun dato viene inventato.
      final restoredEvents = MatchPointAnalytics.decode(checkpoint['pointEvents']);
      _pointTrackingComplete = checkpoint.containsKey('pointEvents') &&
          checkpoint['pointTrackingComplete'] != false && restoredEvents != null;
      _pointEvents..clear()..addAll(restoredEvents ?? []);
      _tournamentLink = TournamentMatchLink.valid(checkpoint['tournamentLink'])
          ? Map<String, dynamic>.from(checkpoint['tournamentLink'] as Map) : null;
      _lastTournamentSyncError = null;
      _elapsedSeconds = runtime['elapsedSeconds'] as int;
      _isTimerRunning = runtime['isTimerRunning'] == true && snap.matchWinner == null;
      _isSidesSwapped = runtime['isSidesSwapped'] == true;
      _breakSecondsLeft = runtime['breakSecondsLeft'] as int;
      _isBreakActive = runtime['isBreakActive'] == true && _breakSecondsLeft > 0;
      _pendingRecovery = null;
      _activeCheckpoint = true;
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }

  void discardSavedMatch() {
    _pendingRecovery = null;
    _tournamentLink = null;
    _activeCheckpoint = false;
    _writeQueue = _writeQueue.then((_) async {
      try { await (await SharedPreferences.getInstance()).remove(MatchCheckpointCodec.key); } catch (_) {}
    });
    _publishWatchState();
    super.notifyListeners();
  }

  // Evita che il caricamento asincrono delle preferenze sostituisca
  // le impostazioni o lo snapshot dopo una nuova partita.
  int _configurationVersion = 0;

  // Stato UI visivo indipendente per cambio campo (inversione lati senza alterare dati sportivi)
  bool _isSidesSwapped = false;

  PadelScoreProvider({TtsService? ttsService})
      : _ttsService = ttsService ?? TtsService() {
    _watchSync.registerCommandHandler(_handleWatchCommand);
    _loadPreferences();
  }

  @override
  void dispose() {
    _watchSync.unregisterCommandHandler();
    super.dispose();
  }

  // Getters
  PadelMatchSnapshot get snapshot => _currentSnapshot;
  String get teamAName => _teamAName;
  String get teamBName => _teamBName;
  String get player1Name => _player1Name;
  String get player2Name => _player2Name;
  String get player3Name => _player3Name;
  String get player4Name => _player4Name;
  List<String?> get playerIds => List.unmodifiable(_playerIds);
  static List<String?> _validPlayerIds(dynamic value) {
    if (value is! List || value.length != 4 || !value.every((v) => v == null || (v is String && v.isNotEmpty && v.length <= 100))) {
      return [null, null, null, null];
    }
    return value.cast<String?>().toList();
  }
  int get firstServerPlayerId => _firstServerPlayerId;
  bool get isGoldenPoint => _isGoldenPoint;
  int get advantagesBeforeGoldenPoint => _advantagesBeforeGoldenPoint;
  int get bestOfSets => _bestOfSets;
  bool get shortSets => _shortSets;
  bool get decidingMatchTieBreak => _decidingMatchTieBreak;
  int get decidingTieBreakPoints => _decidingTieBreakPoints;
  bool get canUndo => _history.isNotEmpty;
  bool get isMuted => _ttsService.isMuted;
  /// I nomi dei giocatori e i risultati sono condivisi solo se richiesto.
  int _watchShareSequence = 0;
  int get watchShareSequence => _watchShareSequence;

  static String _setCountSpoken(int count) {
    const words = ['zero', 'uno', 'due', 'tre', 'quattro', 'cinque'];
    return count >= 0 && count < words.length ? words[count] : count.toString();
  }

  bool get isMatchOver => _currentSnapshot.matchWinner != null;
  bool get isSidesSwapped => _isSidesSwapped;

  String getTeamName(Team team) => team == Team.teamA ? _teamAName : _teamBName;

  /// Restituisce l'ID del giocatore attualmente al servizio
  int get currentServerPlayerId {
    return getCurrentServerPlayerId(_currentSnapshot, _firstServerPlayerId);
  }

  /// Restituisce il nome visualizzato del battitore in base al suo ID stabile (1..4)
  String getPlayerNameById(int playerId) {
    switch (playerId) {
      case 1:
        return _player1Name.trim().isEmpty ? 'Giocatore 1' : _player1Name.trim();
      case 2:
        return _player2Name.trim().isEmpty ? 'Giocatore 2' : _player2Name.trim();
      case 3:
        return _player3Name.trim().isEmpty ? 'Giocatore 3' : _player3Name.trim();
      case 4:
        return _player4Name.trim().isEmpty ? 'Giocatore 4' : _player4Name.trim();
      default:
        return 'Giocatore $playerId';
    }
  }

  /// Restituisce il nome del giocatore attualmente al servizio
  String get currentServingPlayerName {
    return getPlayerNameById(currentServerPlayerId);
  }

  /// Setup completo del match dalla schermata iniziale
  void setupMatch({
    required String team1,
    required String team2,
    required String player1,
    required String player2,
    required String player3,
    required String player4,
    required int firstServerPlayerId, // 1, 2, 3 o 4
    required bool goldenPoint,
    int advantagesBeforeGoldenPoint = 0,
    required int bestOfSets,
    bool shortSets = false,
    bool decidingMatchTieBreak = false,
    int decidingTieBreakPoints = 10,
    List<String?>? playerIds,
    Map<String, dynamic>? tournamentLink,
  }) {
    if (tournamentLink != null && !TournamentMatchLink.valid(tournamentLink)) {
      throw ArgumentError.value(tournamentLink, 'tournamentLink', 'Collegamento torneo non valido');
    }
    _tournamentLink = tournamentLink == null ? null : Map<String, dynamic>.from(tournamentLink);
    _lastTournamentSyncError = null;
    _configurationVersion++;
    _pendingRecovery = null;
    _matchArchiveId = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
    _activeCheckpoint = true;
    _elapsedSeconds = 0;
    _isTimerRunning = true;
    _breakSecondsLeft = 0;
    _isBreakActive = false;
    _teamAName = team1.trim().isEmpty ? 'Squadra 1' : team1.trim();
    _teamBName = team2.trim().isEmpty ? 'Squadra 2' : team2.trim();
    _player1Name = player1.trim().isEmpty ? 'Giocatore 1' : player1.trim();
    _player2Name = player2.trim().isEmpty ? 'Giocatore 2' : player2.trim();
    _player3Name = player3.trim().isEmpty ? 'Giocatore 3' : player3.trim();
    _player4Name = player4.trim().isEmpty ? 'Giocatore 4' : player4.trim();
    _playerIds = _validPlayerIds(playerIds);
    _firstServerPlayerId = (firstServerPlayerId >= 1 && firstServerPlayerId <= 4)
        ? firstServerPlayerId
        : 1;
    _isGoldenPoint = goldenPoint;
    _advantagesBeforeGoldenPoint = advantagesBeforeGoldenPoint;
    _bestOfSets = bestOfSets;
    _shortSets = shortSets;
    _decidingMatchTieBreak = bestOfSets > 1 && decidingMatchTieBreak;
    _decidingTieBreakPoints = decidingTieBreakPoints == 7 ? 7 : 10;
    _isSidesSwapped = false;

    final Team initialTeam = getTeamForPlayerId(_firstServerPlayerId);

    _history.clear();
    _pointEvents.clear();
    _pointTrackingComplete = true;
    _currentSnapshot = PadelMatchSnapshot.initial(
      initialServer: initialTeam,
      initialRotationIndex: 0,
    );

    _savePreferences();
    notifyListeners();

    // Annuncio arbitrale di inizio match
    _ttsService.speak(
      'Inizio partita. $_teamAName contro $_teamBName. Serve $currentServingPlayerName.',
    );
  }

  Future<void> _loadPreferences() async {
    final versionAtStart = _configurationVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (versionAtStart != _configurationVersion) return;
      _isGoldenPoint = prefs.getBool('isGoldenPoint') ?? true;
      _advantagesBeforeGoldenPoint = prefs.getInt('advantagesBeforeGoldenPoint') ?? 0;
      _shortSets = prefs.getBool('shortSets') ?? false;
      _decidingMatchTieBreak = prefs.getBool('decidingMatchTieBreak') ?? false;
      _decidingTieBreakPoints = prefs.getInt('decidingTieBreakPoints') == 7 ? 7 : 10;
      _bestOfSets = prefs.getInt('bestOfSets') ?? 3;
      _teamAName = prefs.getString('teamAName') ?? 'Gli Smashtori';
      _teamBName = prefs.getString('teamBName') ?? 'I Timemasters';
      _player1Name = prefs.getString('player1Name') ?? 'Mario Rossi';
      _player2Name = prefs.getString('player2Name') ?? 'Luigi Verdi';
      _player3Name = prefs.getString('player3Name') ?? 'Paolo Bianchi';
      _player4Name = prefs.getString('player4Name') ?? 'Marco Neri';
      _playerIds = _validPlayerIds(prefs.getStringList('matchPlayerIds')?.map((s) => s.isEmpty ? null : s).toList());
      _firstServerPlayerId = prefs.getInt('firstServerPlayerId') ?? 1;

      final initialTeam = getTeamForPlayerId(_firstServerPlayerId);
      _currentSnapshot = PadelMatchSnapshot.initial(
        initialServer: initialTeam,
        initialRotationIndex: 0,
      );
      _pendingRecovery = MatchCheckpointCodec.decode(prefs.getString(MatchCheckpointCodec.key));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGoldenPoint', _isGoldenPoint);
      await prefs.setInt('advantagesBeforeGoldenPoint', _advantagesBeforeGoldenPoint);
      await prefs.setBool('shortSets', _shortSets);
      await prefs.setBool('decidingMatchTieBreak', _decidingMatchTieBreak);
      await prefs.setInt('decidingTieBreakPoints', _decidingTieBreakPoints);
      await prefs.setInt('bestOfSets', _bestOfSets);
      await prefs.setString('teamAName', _teamAName);
      await prefs.setString('teamBName', _teamBName);
      await prefs.setString('player1Name', _player1Name);
      await prefs.setString('player2Name', _player2Name);
      await prefs.setString('player3Name', _player3Name);
      await prefs.setString('player4Name', _player4Name);
      await prefs.setStringList('matchPlayerIds', _playerIds.map((s) => s ?? '').toList());
      await prefs.setInt('firstServerPlayerId', _firstServerPlayerId);
    } catch (_) {}
  }

  // ===========================================================================
  // LOGICA DI PUNTEGGIO PADEL (ALLINEATA AL REGOLAMENTO FIP 2026 E AL MOTORE REACT)
  // ===========================================================================

  void addPoint(Team scoringTeam) {
    // Watch, touchscreen e Bluetooth passano da qui: durante la chiusura
    // asincrona nessuna sorgente deve cambiare il risultato archiviato.
    if (!_activeCheckpoint || _finalizingMatch || isMatchOver) return;
    _configurationVersion++;

    final before = _currentSnapshot;
    final serverPlayerId = currentServerPlayerId;
    final wasGolden = before.isGoldenPointSituation(
        _isGoldenPoint, _advantagesBeforeGoldenPoint);
    _history.add(before);
    // I metodi del motore notificano il risultato prima di uscire: tratteniamo
    // una sola notifica fino a quando e` stato incluso anche l'evento del punto.
    _processingPoint = true;
    try {
      if (before.isTieBreak) {
        _processTieBreakPoint(scoringTeam);
      } else {
        _processStandardPoint(scoringTeam);
      }
    } finally {
      _processingPoint = false;
    }
    if (!identical(before, _currentSnapshot) && _pointTrackingComplete) {
      if (_pointEvents.length >= MatchPointAnalytics.maxEvents) {
        // Non presentare statistiche parziali come se fossero complete.
        _pointTrackingComplete = false;
      } else {
        _pointEvents.add(MatchPointAnalytics.event(
          index: _pointEvents.length + 1,
          undoDepth: _history.length,
          elapsedSeconds: _elapsedSeconds,
          scoringTeam: scoringTeam,
          serverPlayerId: serverPlayerId,
          before: before,
          after: _currentSnapshot,
          goldenPoint: wasGolden,
        ));
      }
    }
    notifyListeners();
  }

  void _processStandardPoint(Team scoringTeam) {
    int pA = _currentSnapshot.rawPointsA;
    int pB = _currentSnapshot.rawPointsB;
    int deuceCount = _currentSnapshot.deuceCount;

    // Situazione Punto d'Oro o Star Point
    final bool isGoldenPointNow = _isGoldenPoint &&
        pA == 3 &&
        pB == 3 &&
        deuceCount >= _advantagesBeforeGoldenPoint;

    if (scoringTeam == Team.teamA) {
      if (pA < 3) {
        pA++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      } else if (pA == 3 && pB < 3) {
        _winGame(Team.teamA);
      } else if (pA == 3 && pB == 3) {
        if (isGoldenPointNow) {
          _winGame(Team.teamA);
        } else {
          pA = 4; // Vantaggio Squadra A
          _commitPointChange(pA, pB, deuceCount, scoringTeam);
        }
      } else if (pA == 4 && pB == 3) {
        _winGame(Team.teamA);
      } else if (pA == 3 && pB == 4) {
        pB = 3; // Ritorno a 40 pari
        deuceCount++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      }
    } else {
      if (pB < 3) {
        pB++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      } else if (pB == 3 && pA < 3) {
        _winGame(Team.teamB);
      } else if (pA == 3 && pB == 3) {
        if (isGoldenPointNow) {
          _winGame(Team.teamB);
        } else {
          pB = 4; // Vantaggio Squadra B
          _commitPointChange(pA, pB, deuceCount, scoringTeam);
        }
      } else if (pB == 4 && pA == 3) {
        _winGame(Team.teamB);
      } else if (pB == 3 && pA == 4) {
        pA = 3; // Ritorno a 40 pari
        deuceCount++;
        _commitPointChange(pA, pB, deuceCount, scoringTeam);
      }
    }
  }

  void _commitPointChange(int newPA, int newPB, int newDeuceCount, Team scorer) {
    _currentSnapshot = _currentSnapshot.copyWith(
      rawPointsA: newPA,
      rawPointsB: newPB,
      deuceCount: newDeuceCount,
      lastEventMessage: 'Punto ${getTeamName(scorer)}',
    );
    notifyListeners();
    _announceRefereePointScore();
  }

  void _winGame(Team winner) {
    int gA = _currentSnapshot.currentGamesA;
    int gB = _currentSnapshot.currentGamesB;

    if (winner == Team.teamA) {
      gA++;
    } else {
      gB++;
    }

    final rotation = getRotationOrder(_firstServerPlayerId);
    final int nextRotationIndex = _currentSnapshot.servingRotationIndex + 1;
    final int nextServerId = rotation[nextRotationIndex % rotation.length];
    final Team nextServerTeam = getTeamForPlayerId(nextServerId);

    final int gamesTarget = _shortSets ? 4 : 6;
    // Mini-set: 4-4; set standard: 6-6.
    if (gA == gamesTarget && gB == gamesTarget) {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
        deuceCount: 0,
        currentGamesA: gamesTarget,
        currentGamesB: gamesTarget,
        isTieBreak: true,
        isMatchTieBreak: false,
        tieBreakPointsA: 0,
        tieBreakPointsB: 0,
        servingTeam: nextServerTeam,
        servingRotationIndex: nextRotationIndex,
        tieBreakInitialRotationIndex: nextRotationIndex,
        lastEventMessage: 'Tie-break!',
      );
      notifyListeners();
      _ttsService.speak('${_shortSets ? 'Quattro' : 'Sei'} pari. Tie-break. Serve $currentServingPlayerName.');
      return;
    }

    final bool setWonA = (gA >= gamesTarget && (gA - gB) >= 2);
    final bool setWonB = (gB >= gamesTarget && (gB - gA) >= 2);

    if (setWonA || setWonB) {
      _winSet(setWonA ? Team.teamA : Team.teamB, gA, gB, null, null);
    } else {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
        deuceCount: 0,
        currentGamesA: gA,
        currentGamesB: gB,
        servingTeam: nextServerTeam,
        servingRotationIndex: nextRotationIndex,
        lastEventMessage: 'Game ${getTeamName(winner)}',
      );
      notifyListeners();

      _ttsService.speak(
        'Game per la squadra ${getTeamName(winner)}. $gA a $gB. Serve $currentServingPlayerName.',
      );
    }
  }

  void _processTieBreakPoint(Team scoringTeam) {
    int tbA = _currentSnapshot.tieBreakPointsA;
    int tbB = _currentSnapshot.tieBreakPointsB;

    if (scoringTeam == Team.teamA) {
      tbA++;
    } else {
      tbB++;
    }

    final int totalPoints = tbA + tbB;

    final target = _currentSnapshot.isMatchTieBreak ? _decidingTieBreakPoints : 7;
    final bool tbWonA = (tbA >= target && (tbA - tbB) >= 2);
    final bool tbWonB = (tbB >= target && (tbB - tbA) >= 2);

    if (tbWonA || tbWonB) {
      final Team setWinner = tbWonA ? Team.teamA : Team.teamB;
      if (_currentSnapshot.isMatchTieBreak) {
        _winMatchTieBreak(setWinner, tbA, tbB);
        return;
      }
      final int limit = _shortSets ? 4 : 6;
      _winSet(setWinner, tbWonA ? limit + 1 : limit, tbWonB ? limit + 1 : limit, tbA, tbB);
    } else {
      // Rotazione battitore durante tiebreak con sequenza 1-2-2-2...
      final rotation = getRotationOrder(_firstServerPlayerId);
      final int initialIdx =
          _currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex;
      final int shift = ((totalPoints + 1) ~/ 2);
      final int nextPlayerId = rotation[(initialIdx + shift) % rotation.length];
      final Team nextTeam = getTeamForPlayerId(nextPlayerId);

      _currentSnapshot = _currentSnapshot.copyWith(
        tieBreakPointsA: tbA,
        tieBreakPointsB: tbB,
        servingTeam: nextTeam,
        lastEventMessage: 'Tie-break $tbA - $tbB',
      );
      notifyListeners();
      _ttsService.speak('$tbA a $tbB. Serve $currentServingPlayerName.');
    }
  }

  // Il set decisivo è registrato con i punti reali, senza game inventati.
  void _winMatchTieBreak(Team winner, int tbA, int tbB) {
    final sets = List<SetScore>.from(_currentSnapshot.completedSets)
      ..add(SetScore(gamesA: 0, gamesB: 0, tieBreakPointsA: tbA,
          tieBreakPointsB: tbB, isMatchTieBreak: true,
          isCompleted: true, winner: winner));
    _currentSnapshot = _currentSnapshot.copyWith(
      completedSets: sets, matchWinner: winner,
      rawPointsA: 0, rawPointsB: 0, deuceCount: 0,
      isTieBreak: false, isMatchTieBreak: false,
      tieBreakPointsA: 0, tieBreakPointsB: 0,
      tieBreakInitialRotationIndex: null,
      lastEventMessage: 'Match tie-break $tbA-$tbB. Partita vinta da ${getTeamName(winner)}!',
    );
    notifyListeners();
    _ttsService.speak('Match tie-break $tbA a $tbB. Partita vinta da ${getTeamName(winner)}!');
  }

  void _winSet(Team setWinner, int gA, int gB, int? tbA, int? tbB) {
    final completedSet = SetScore(
      gamesA: gA,
      gamesB: gB,
      tieBreakPointsA: tbA,
      tieBreakPointsB: tbB,
      isCompleted: true,
      winner: setWinner,
    );

    final updatedSets = List<SetScore>.from(_currentSnapshot.completedSets)..add(completedSet);
    final setNumber = updatedSets.length;
    final int setsWonA = updatedSets.where((s) => s.winner == Team.teamA).length;
    final int setsWonB = updatedSets.where((s) => s.winner == Team.teamB).length;
    final int setsToWin = (_bestOfSets / 2).ceil();

    Team? matchWinner;
    if (setsWonA >= setsToWin) matchWinner = Team.teamA;
    if (setsWonB >= setsToWin) matchWinner = Team.teamB;

    final rotation = getRotationOrder(_firstServerPlayerId);
    int nextRotIndex;

    if (_currentSnapshot.isTieBreak) {
      // Regola Ufficiale FIP Tie-Break:
      // La coppia che ha iniziato a servire nel tie-break riceverà nel primo game del set successivo.
      // Il servizio del primo game del nuovo set tocca alla squadra opposta che segue nella rotazione.
      final int tbStartRot =
          _currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex;
      nextRotIndex = tbStartRot + 1;
    } else {
      // Regola Ufficiale FIP Set standard:
      // Continua la naturale alternanza di servizio in base ai game totali giocati.
      nextRotIndex = _currentSnapshot.servingRotationIndex + 1;
    }

    final int nextServerPlayerId = rotation[nextRotIndex % rotation.length];
    final Team nextSetServerTeam = getTeamForPlayerId(nextServerPlayerId);

    final bool startDecidingTieBreak = matchWinner == null &&
        _decidingMatchTieBreak && _bestOfSets > 1 &&
        updatedSets.length == _bestOfSets - 1 && setsWonA == setsWonB;

    _currentSnapshot = _currentSnapshot.copyWith(
      rawPointsA: 0,
      rawPointsB: 0,
      deuceCount: 0,
      currentGamesA: 0,
      currentGamesB: 0,
      completedSets: updatedSets,
      servingTeam: nextSetServerTeam,
      servingRotationIndex: nextRotIndex,
      initialSetServer: nextSetServerTeam,
      isTieBreak: startDecidingTieBreak,
      isMatchTieBreak: startDecidingTieBreak,
      tieBreakPointsA: 0,
      tieBreakPointsB: 0,
      tieBreakInitialRotationIndex: startDecidingTieBreak ? nextRotIndex : null,
      matchWinner: matchWinner,
      lastEventMessage: matchWinner != null
          ? 'Partita vinta da ${getTeamName(matchWinner)}!'
          : 'Set vinto da ${getTeamName(setWinner)}',
    );
    notifyListeners();

    final String setOrdinal = setNumber == 1 ? 'primo' : (setNumber == 2 ? 'secondo' : (setNumber == 3 ? 'terzo' : (setNumber == 4 ? 'quarto' : 'quinto')));
    if (matchWinner != null) {
      _ttsService.speak(
        'Game, partita vinta da ${getTeamName(matchWinner)}! Risultato finale. Parziali vinti: ${_setCountSpoken(setsWonA)} a ${_setCountSpoken(setsWonB)}.',
      );
    } else if (startDecidingTieBreak) {
      _ttsService.speak('Set per ${getTeamName(setWinner)}. Inizia il match tie-break decisivo a dieci punti. Serve $currentServingPlayerName.');
    } else {
      _ttsService.speak(
        'Game e $setOrdinal set per la squadra ${getTeamName(setWinner)}. $gA game a $gB.',
      );
    }
  }

  /// Annuncio arbitrale fluido e naturale
  void _announceRefereePointScore() {
    int pA = _currentSnapshot.rawPointsA;
    int pB = _currentSnapshot.rawPointsB;
    int deuceCount = _currentSnapshot.deuceCount;

    // CASI DI PARITÀ
    if (pA == pB) {
      if (pA == 0) {
        _ttsService.speak('Zero pari.');
      } else if (pA == 1) {
        _ttsService.speak('Quindici pari.');
      } else if (pA == 2) {
        _ttsService.speak('Trenta pari.');
      } else if (pA == 3) {
        if (_isGoldenPoint && deuceCount >= _advantagesBeforeGoldenPoint) {
          _ttsService.speak(_advantagesBeforeGoldenPoint == 2
              ? 'Quaranta pari. Star Point.'
              : 'Quaranta pari. Punto d\'oro.');
        } else {
          _ttsService.speak('Quaranta pari. Parità.');
        }
      }
      return;
    }

    // CASI DI VANTAGGIO
    if (pA == 4) {
      _ttsService.speak('Vantaggio per la squadra $_teamAName.');
      return;
    }
    if (pB == 4) {
      _ttsService.speak('Vantaggio per la squadra $_teamBName.');
      return;
    }

    // PUNTI NORMALI
    final String labelA = _pointToItalian(pA);
    final String labelB = _pointToItalian(pB);
    final String server = currentServingPlayerName;

    _ttsService.speak('$labelA a $labelB. Serve $server.');
  }

  String _pointToItalian(int p) {
    switch (p) {
      case 0:
        return 'Zero';
      case 1:
        return 'Quindici';
      case 2:
        return 'Trenta';
      case 3:
        return 'Quaranta';
      default:
        return 'Zero';
    }
  }

  void announceTimeUp() {
    _ttsService.speak('Tempo scaduto, riprendere il gioco!');
  }

  void undo() {
    if (!_activeCheckpoint || _finalizingMatch) return;
    if (_history.isEmpty) return;
    if (_pointEvents.isNotEmpty &&
        _pointEvents.last['undoDepth'] == _history.length) {
      _pointEvents.removeLast();
    }
    _currentSnapshot = _history.removeLast();
    notifyListeners();
    _ttsService.speak('Punto annullato.');
  }

  void resetMatch() {
    if (!_activeCheckpoint || _finalizingMatch) return;
    _history.clear();
    _pointEvents.clear();
    _pointTrackingComplete = true;
    _isSidesSwapped = false;
    _elapsedSeconds = 0;
    _isTimerRunning = true;
    _breakSecondsLeft = 0;
    _isBreakActive = false;
    final initialTeam = getTeamForPlayerId(_firstServerPlayerId);
    _currentSnapshot = PadelMatchSnapshot.initial(
      initialServer: initialTeam,
      initialRotationIndex: 0,
    );
    notifyListeners();
    _ttsService.speak('Partita resettata. Serve $currentServingPlayerName.');
  }

  void toggleServingTeam() {
    if (!_activeCheckpoint || _finalizingMatch || isMatchOver) return;
    _history.add(_currentSnapshot);
    final nextRot = _currentSnapshot.servingRotationIndex + 1;
    final rotation = getRotationOrder(_firstServerPlayerId);
    final nextPlayerId = rotation[nextRot % rotation.length];
    final newServerTeam = getTeamForPlayerId(nextPlayerId);
    _currentSnapshot = _currentSnapshot.copyWith(
      servingTeam: newServerTeam,
      servingRotationIndex: nextRot,
    );
    notifyListeners();
    _ttsService.speak('Cambio battitore. Serve $currentServingPlayerName.');
  }

  /// Inverte esclusivamente la visualizzazione dei lati del tabellone.
  /// Non altera in alcun modo punteggio, game, set, battitore o storico sportivo.
  void switchSides() {
    if (!_activeCheckpoint || _finalizingMatch) return;
    _isSidesSwapped = !_isSidesSwapped;
    notifyListeners();
    _ttsService.speak('Cambio campo.');
  }

  void setGoldenPoint(bool enabled, [int advantagesBefore = 0]) {
    // Compatibilità API: le modalità si scelgono nella schermata di setup.
    _configurationVersion++;
    _isGoldenPoint = enabled;
    _advantagesBeforeGoldenPoint = advantagesBefore;
    _savePreferences();
    notifyListeners();
    _ttsService.speak(!enabled
        ? 'Vantaggi tradizionali attivati.'
        : advantagesBefore == 2
            ? 'Star Point attivato.'
            : 'Punto d\'oro attivato.');
  }

  void toggleMute() {
    _ttsService.setMuted(!_ttsService.isMuted);
    SharedPreferences.getInstance().then((prefs) =>
      prefs.setBool('padel_voice_enabled_v1', !_ttsService.isMuted));
    notifyListeners();
  }
}
