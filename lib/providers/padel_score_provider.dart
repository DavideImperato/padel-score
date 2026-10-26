import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/padel_match_state.dart';
import '../services/tts_service.dart';

class PadelScoreProvider extends ChangeNotifier {
  final TtsService _ttsService;

  // Snapshot corrente e cronologia per Undo
  PadelMatchSnapshot _currentSnapshot = PadelMatchSnapshot.initial();
  final List<PadelMatchSnapshot> _history = [];

  // Squadre e 4 Giocatori
  String _teamAName = 'Gli Smashtori';
  String _teamBName = 'I Timemasters';

  String _player1Name = 'Mario Rossi';
  String _player2Name = 'Luigi Verdi';
  String _player3Name = 'Paolo Bianchi';
  String _player4Name = 'Marco Neri';

  // Identificativo del primo battitore (1, 2, 3 o 4)
  int _firstServerPlayerId = 1;

  // Impostazioni regolamento
  bool _isGoldenPoint = true;
  int _advantagesBeforeGoldenPoint = 0; // 0 = subito punto d'oro, 1 = 1 vantaggio poi punto d'oro, 2 = Star Point FIP 2026
  int _bestOfSets = 3;

  // Stato UI visivo indipendente per cambio campo (inversione lati senza alterare dati sportivi)
  bool _isSidesSwapped = false;

  PadelScoreProvider({TtsService? ttsService})
      : _ttsService = ttsService ?? TtsService() {
    _loadPreferences();
  }

  // Getters
  PadelMatchSnapshot get snapshot => _currentSnapshot;
  String get teamAName => _teamAName;
  String get teamBName => _teamBName;
  String get player1Name => _player1Name;
  String get player2Name => _player2Name;
  String get player3Name => _player3Name;
  String get player4Name => _player4Name;
  int get firstServerPlayerId => _firstServerPlayerId;
  bool get isGoldenPoint => _isGoldenPoint;
  int get advantagesBeforeGoldenPoint => _advantagesBeforeGoldenPoint;
  int get bestOfSets => _bestOfSets;
  bool get canUndo => _history.isNotEmpty;
  bool get isMuted => _ttsService.isMuted;
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
  }) {
    _teamAName = team1.trim().isEmpty ? 'Squadra 1' : team1.trim();
    _teamBName = team2.trim().isEmpty ? 'Squadra 2' : team2.trim();
    _player1Name = player1.trim().isEmpty ? 'Giocatore 1' : player1.trim();
    _player2Name = player2.trim().isEmpty ? 'Giocatore 2' : player2.trim();
    _player3Name = player3.trim().isEmpty ? 'Giocatore 3' : player3.trim();
    _player4Name = player4.trim().isEmpty ? 'Giocatore 4' : player4.trim();
    _firstServerPlayerId = (firstServerPlayerId >= 1 && firstServerPlayerId <= 4)
        ? firstServerPlayerId
        : 1;
    _isGoldenPoint = goldenPoint;
    _advantagesBeforeGoldenPoint = advantagesBeforeGoldenPoint;
    _bestOfSets = bestOfSets;
    _isSidesSwapped = false;

    final Team initialTeam = getTeamForPlayerId(_firstServerPlayerId);

    _history.clear();
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
    try {
      final prefs = await SharedPreferences.getInstance();
      _isGoldenPoint = prefs.getBool('isGoldenPoint') ?? true;
      _advantagesBeforeGoldenPoint = prefs.getInt('advantagesBeforeGoldenPoint') ?? 0;
      _teamAName = prefs.getString('teamAName') ?? 'Gli Smashtori';
      _teamBName = prefs.getString('teamBName') ?? 'I Timemasters';
      _player1Name = prefs.getString('player1Name') ?? 'Mario Rossi';
      _player2Name = prefs.getString('player2Name') ?? 'Luigi Verdi';
      _player3Name = prefs.getString('player3Name') ?? 'Paolo Bianchi';
      _player4Name = prefs.getString('player4Name') ?? 'Marco Neri';
      _firstServerPlayerId = prefs.getInt('firstServerPlayerId') ?? 1;

      final initialTeam = getTeamForPlayerId(_firstServerPlayerId);
      _currentSnapshot = PadelMatchSnapshot.initial(
        initialServer: initialTeam,
        initialRotationIndex: 0,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGoldenPoint', _isGoldenPoint);
      await prefs.setInt('advantagesBeforeGoldenPoint', _advantagesBeforeGoldenPoint);
      await prefs.setString('teamAName', _teamAName);
      await prefs.setString('teamBName', _teamBName);
      await prefs.setString('player1Name', _player1Name);
      await prefs.setString('player2Name', _player2Name);
      await prefs.setString('player3Name', _player3Name);
      await prefs.setString('player4Name', _player4Name);
      await prefs.setInt('firstServerPlayerId', _firstServerPlayerId);
    } catch (_) {}
  }

  // ===========================================================================
  // LOGICA DI PUNTEGGIO PADEL (ALLINEATA AL REGOLAMENTO FIP 2026 E AL MOTORE REACT)
  // ===========================================================================

  void addPoint(Team scoringTeam) {
    if (isMatchOver) return;

    _history.add(_currentSnapshot);

    if (_currentSnapshot.isTieBreak) {
      _processTieBreakPoint(scoringTeam);
      return;
    }
    _processStandardPoint(scoringTeam);
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

    // Sul 6-6 scatta il Tie-Break
    if (gA == 6 && gB == 6) {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
        deuceCount: 0,
        currentGamesA: 6,
        currentGamesB: 6,
        isTieBreak: true,
        tieBreakPointsA: 0,
        tieBreakPointsB: 0,
        servingTeam: nextServerTeam,
        servingRotationIndex: nextRotationIndex,
        tieBreakInitialRotationIndex: nextRotationIndex,
        lastEventMessage: 'Tie-break!',
      );
      notifyListeners();
      _ttsService.speak('Sei pari. Tie-break. Serve $currentServingPlayerName.');
      return;
    }

    // Controllo vittoria set (6 con 2 di margine, oppure 7-5)
    final bool setWonA = (gA >= 6 && (gA - gB) >= 2);
    final bool setWonB = (gB >= 6 && (gB - gA) >= 2);

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

    // Controllo vittoria tie-break: 7 punti con 2 di scarto
    final bool tbWonA = (tbA >= 7 && (tbA - tbB) >= 2);
    final bool tbWonB = (tbB >= 7 && (tbB - tbA) >= 2);

    if (tbWonA || tbWonB) {
      final Team setWinner = tbWonA ? Team.teamA : Team.teamB;
      _winSet(setWinner, tbWonA ? 7 : 6, tbWonB ? 7 : 6, tbA, tbB);
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
      isTieBreak: false,
      tieBreakPointsA: 0,
      tieBreakPointsB: 0,
      tieBreakInitialRotationIndex: null,
      matchWinner: matchWinner,
      lastEventMessage: matchWinner != null
          ? 'Partita vinta da ${getTeamName(matchWinner)}!'
          : 'Set vinto da ${getTeamName(setWinner)}',
    );
    notifyListeners();

    final String setOrdinal = setNumber == 1 ? 'primo' : (setNumber == 2 ? 'secondo' : (setNumber == 3 ? 'terzo' : (setNumber == 4 ? 'quarto' : 'quinto')));
    if (matchWinner != null) {
      _ttsService.speak(
        'Game, set e partita per la squadra ${getTeamName(matchWinner)}! Risultato finale: $setsWonA set a $setsWonB.',
      );
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
          _ttsService.speak('Quaranta pari. Punto d\'oro.');
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
    if (_history.isEmpty) return;
    _currentSnapshot = _history.removeLast();
    notifyListeners();
    _ttsService.speak('Punto annullato.');
  }

  void resetMatch() {
    _history.clear();
    _isSidesSwapped = false;
    final initialTeam = getTeamForPlayerId(_firstServerPlayerId);
    _currentSnapshot = PadelMatchSnapshot.initial(
      initialServer: initialTeam,
      initialRotationIndex: 0,
    );
    notifyListeners();
    _ttsService.speak('Partita resettata. Serve $currentServingPlayerName.');
  }

  void toggleServingTeam() {
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
    _isSidesSwapped = !_isSidesSwapped;
    notifyListeners();
    _ttsService.speak('Cambio campo.');
  }

  void setGoldenPoint(bool enabled, [int advantagesBefore = 0]) {
    _isGoldenPoint = enabled;
    _advantagesBeforeGoldenPoint = advantagesBefore;
    _savePreferences();
    notifyListeners();
    _ttsService.speak(enabled ? 'Punto d\'oro attivato.' : 'Vantaggi tradizionali attivati.');
  }

  void toggleMute() {
    _ttsService.setMuted(!_ttsService.isMuted);
    notifyListeners();
  }
}
