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

  // Ordine di battuta a 4 giocatori (ciclo ufficiale FIP)
  // [Giocatore Squadra 1, Giocatore Squadra 2, Compagno Sq 1, Compagno Sq 2]
  List<String> _rotationOrder = [];

  // Impostazioni regolamento
  bool _isGoldenPoint = true;
  int _bestOfSets = 3;

  PadelScoreProvider({TtsService? ttsService})
      : _ttsService = ttsService ?? TtsService() {
    _updateRotationList(initialServerPlayerId: 1);
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
  bool get isGoldenPoint => _isGoldenPoint;
  int get bestOfSets => _bestOfSets;
  bool get canUndo => _history.isNotEmpty;
  bool get isMuted => _ttsService.isMuted;
  bool get isMatchOver => _currentSnapshot.matchWinner != null;

  String getTeamName(Team team) => team == Team.teamA ? _teamAName : _teamBName;

  /// Restituisce il nome del giocatore attualmente al servizio
  String get currentServingPlayerName {
    if (_rotationOrder.isEmpty) return _player1Name;

    if (_currentSnapshot.isTieBreak) {
      // Nel Tie-Break la rotazione è:
      // Punto 1: battitore iniziale tiebreak (rotIndex)
      // Punti 2 & 3: rotIndex + 1
      // Punti 4 & 5: rotIndex + 2
      // Punti 6 & 7: rotIndex + 3...
      final int initialIdx = _currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex;
      final int totalPoints = _currentSnapshot.tieBreakPointsA + _currentSnapshot.tieBreakPointsB;
      final int shift = totalPoints == 0 ? 0 : ((totalPoints + 1) ~/ 2);
      final int actualIdx = (initialIdx + shift) % _rotationOrder.length;
      return _rotationOrder[actualIdx];
    }

    final int index = _currentSnapshot.servingRotationIndex % _rotationOrder.length;
    return _rotationOrder[index];
  }

  /// Configura la rotazione dei 4 giocatori partendo da chi è stato scelto per servire per primo
  void _updateRotationList({int initialServerPlayerId = 1}) {
    // Definizione dei 4 giocatori
    // Sq. 1: P1, P2
    // Sq. 2: P3, P4
    switch (initialServerPlayerId) {
      case 1: // Inizia Giocatore 1 (Sq. 1)
        _rotationOrder = [_player1Name, _player3Name, _player2Name, _player4Name];
        break;
      case 2: // Inizia Giocatore 2 (Sq. 1)
        _rotationOrder = [_player2Name, _player3Name, _player1Name, _player4Name];
        break;
      case 3: // Inizia Giocatore 3 (Sq. 2)
        _rotationOrder = [_player3Name, _player1Name, _player4Name, _player2Name];
        break;
      case 4: // Inizia Giocatore 4 (Sq. 2)
        _rotationOrder = [_player4Name, _player1Name, _player3Name, _player2Name];
        break;
      default:
        _rotationOrder = [_player1Name, _player3Name, _player2Name, _player4Name];
    }
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
    required int bestOfSets,
  }) {
    _teamAName = team1.trim().isEmpty ? 'Squadra 1' : team1.trim();
    _teamBName = team2.trim().isEmpty ? 'Squadra 2' : team2.trim();
    _player1Name = player1.trim().isEmpty ? 'Giocatore 1' : player1.trim();
    _player2Name = player2.trim().isEmpty ? 'Giocatore 2' : player2.trim();
    _player3Name = player3.trim().isEmpty ? 'Giocatore 3' : player3.trim();
    _player4Name = player4.trim().isEmpty ? 'Giocatore 4' : player4.trim();
    _isGoldenPoint = goldenPoint;
    _bestOfSets = bestOfSets;

    _updateRotationList(initialServerPlayerId: firstServerPlayerId);

    final Team initialTeam = (firstServerPlayerId == 1 || firstServerPlayerId == 2)
        ? Team.teamA
        : Team.teamB;

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
      _teamAName = prefs.getString('teamAName') ?? 'Gli Smashtori';
      _teamBName = prefs.getString('teamBName') ?? 'I Timemasters';
      _player1Name = prefs.getString('player1Name') ?? 'Mario Rossi';
      _player2Name = prefs.getString('player2Name') ?? 'Luigi Verdi';
      _player3Name = prefs.getString('player3Name') ?? 'Paolo Bianchi';
      _player4Name = prefs.getString('player4Name') ?? 'Marco Neri';
      _updateRotationList(initialServerPlayerId: 1);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGoldenPoint', _isGoldenPoint);
      await prefs.setString('teamAName', _teamAName);
      await prefs.setString('teamBName', _teamBName);
      await prefs.setString('player1Name', _player1Name);
      await prefs.setString('player2Name', _player2Name);
      await prefs.setString('player3Name', _player3Name);
      await prefs.setString('player4Name', _player4Name);
    } catch (_) {}
  }

  // ===========================================================================
  // LOGICA DI PUNTEGGIO PADEL
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

    if (scoringTeam == Team.teamA) {
      if (pA < 3) {
        pA++;
        _commitPointChange(pA, pB, scoringTeam);
      } else if (pA == 3 && pB < 3) {
        _winGame(Team.teamA);
      } else if (pA == 3 && pB == 3) {
        if (_isGoldenPoint) {
          _winGame(Team.teamA);
        } else {
          pA = 4; // Vantaggio Sq A
          _commitPointChange(pA, pB, scoringTeam);
        }
      } else if (pA == 4 && pB == 3) {
        _winGame(Team.teamA);
      } else if (pA == 3 && pB == 4) {
        pB = 3; // Torna a 40 pari
        _commitPointChange(pA, pB, scoringTeam);
      }
    } else {
      if (pB < 3) {
        pB++;
        _commitPointChange(pA, pB, scoringTeam);
      } else if (pB == 3 && pA < 3) {
        _winGame(Team.teamB);
      } else if (pA == 3 && pB == 3) {
        if (_isGoldenPoint) {
          _winGame(Team.teamB);
        } else {
          pB = 4; // Vantaggio Sq B
          _commitPointChange(pA, pB, scoringTeam);
        }
      } else if (pB == 4 && pA == 3) {
        _winGame(Team.teamB);
      } else if (pB == 3 && pA == 4) {
        pA = 3;
        _commitPointChange(pA, pB, scoringTeam);
      }
    }
  }

  void _commitPointChange(int newPA, int newPB, Team scorer) {
    _currentSnapshot = _currentSnapshot.copyWith(
      rawPointsA: newPA,
      rawPointsB: newPB,
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

    // Avanza rigorosamente di 1 posizione nella rotazione a 4 giocatori!
    final int nextRotationIndex = _currentSnapshot.servingRotationIndex + 1;
    final Team nextServerTeam = _currentSnapshot.servingTeam.opposite;

    // Sul 6-6 scatta il Tie-Break
    if (gA == 6 && gB == 6) {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
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

    // Controllo vittoria set (6 con 2 di margine)
    bool setWonA = (gA >= 6 && (gA - gB) >= 2);
    bool setWonB = (gB >= 6 && (gB - gA) >= 2);

    if (setWonA || setWonB) {
      _winSet(setWonA ? Team.teamA : Team.teamB, gA, gB, null, null, nextRotationIndex);
    } else {
      _currentSnapshot = _currentSnapshot.copyWith(
        rawPointsA: 0,
        rawPointsB: 0,
        currentGamesA: gA,
        currentGamesB: gB,
        servingTeam: nextServerTeam,
        servingRotationIndex: nextRotationIndex,
        lastEventMessage: 'Game ${getTeamName(winner)}',
      );
      notifyListeners();

      // Annuncio fluido arbitrale:
      // "Game per la squadra Gli Smashtori. Tre a due. Serve Mario Rossi."
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
    bool tbWonA = (tbA >= 7 && (tbA - tbB) >= 2);
    bool tbWonB = (tbB >= 7 && (tbB - tbA) >= 2);

    if (tbWonA || tbWonB) {
      final Team setWinner = tbWonA ? Team.teamA : Team.teamB;
      final int nextRot = (_currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex) + 1;
      _winSet(setWinner, tbWonA ? 7 : 6, tbWonB ? 7 : 6, tbA, tbB, nextRot);
    } else {
      // Rotazione battitore durante tiebreak (1-2-2-2...)
      final int initialIdx = _currentSnapshot.tieBreakInitialRotationIndex ?? _currentSnapshot.servingRotationIndex;
      final int shift = ((totalPoints + 1) ~/ 2);
      final int nextRot = (initialIdx + shift);

      // Determina la squadra del battitore
      final String nextPlayer = _rotationOrder[nextRot % _rotationOrder.length];
      final bool isTeamAPlayer = (nextPlayer == _player1Name || nextPlayer == _player2Name);
      final Team nextTeam = isTeamAPlayer ? Team.teamA : Team.teamB;

      _currentSnapshot = _currentSnapshot.copyWith(
        tieBreakPointsA: tbA,
        tieBreakPointsB: tbB,
        servingTeam: nextTeam,
        lastEventMessage: 'Tie-break $tbA - $tbB',
      );
      notifyListeners();

      // Annuncio Tie-Break: "Tre a due. Serve Marco Neri."
      _ttsService.speak('$tbA a $tbB. Serve $currentServingPlayerName.');
    }
  }

  void _winSet(Team setWinner, int gA, int gB, int? tbA, int? tbB, int nextRotIndex) {
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

    final Team nextSetServerTeam = _currentSnapshot.initialSetServer.opposite;

    _currentSnapshot = _currentSnapshot.copyWith(
      rawPointsA: 0,
      rawPointsB: 0,
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

    String setOrdinal = setNumber == 1 ? 'primo' : (setNumber == 2 ? 'secondo' : 'terzo');
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

    // CASI DI PARITÀ
    if (pA == pB) {
      if (pA == 0) {
        _ttsService.speak('Zero pari.');
      } else if (pA == 1) {
        _ttsService.speak('Quindici pari.');
      } else if (pA == 2) {
        _ttsService.speak('Trenta pari.');
      } else if (pA == 3) {
        if (_isGoldenPoint) {
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

    // PUNTI NORMALI (es. "Quindici a zero. Serve Mario Rossi.")
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
    _currentSnapshot = PadelMatchSnapshot.initial(
      initialServer: Team.teamA,
      initialRotationIndex: 0,
    );
    notifyListeners();
    _ttsService.speak('Partita resettata. Serve $currentServingPlayerName.');
  }

  void toggleServingTeam() {
    _history.add(_currentSnapshot);
    final nextRot = _currentSnapshot.servingRotationIndex + 1;
    final newServerTeam = _currentSnapshot.servingTeam.opposite;
    _currentSnapshot = _currentSnapshot.copyWith(
      servingTeam: newServerTeam,
      servingRotationIndex: nextRot,
    );
    notifyListeners();
    _ttsService.speak('Cambio battitore. Serve $currentServingPlayerName.');
  }

  void switchSides() {
    final tempName = _teamAName;
    _teamAName = _teamBName;
    _teamBName = tempName;

    final prev = _currentSnapshot;
    _currentSnapshot = PadelMatchSnapshot(
      rawPointsA: prev.rawPointsB,
      rawPointsB: prev.rawPointsA,
      currentGamesA: prev.currentGamesB,
      currentGamesB: prev.currentGamesA,
      completedSets: prev.completedSets.map((s) => SetScore(
        gamesA: s.gamesB,
        gamesB: s.gamesA,
        tieBreakPointsA: s.tieBreakPointsB,
        tieBreakPointsB: s.tieBreakPointsA,
        isCompleted: s.isCompleted,
        winner: s.winner == null ? null : (s.winner == Team.teamA ? Team.teamB : Team.teamA),
      )).toList(),
      servingTeam: prev.servingTeam.opposite,
      servingRotationIndex: prev.servingRotationIndex,
      initialSetServer: prev.initialSetServer.opposite,
      isTieBreak: prev.isTieBreak,
      tieBreakPointsA: prev.tieBreakPointsB,
      tieBreakPointsB: prev.tieBreakPointsA,
      tieBreakInitialRotationIndex: prev.tieBreakInitialRotationIndex,
      matchWinner: prev.matchWinner == null ? null : (prev.matchWinner == Team.teamA ? Team.teamB : Team.teamA),
      lastEventMessage: 'Cambio campo',
    );
    notifyListeners();
    _ttsService.speak('Cambio campo.');
  }

  void setGoldenPoint(bool enabled) {
    _isGoldenPoint = enabled;
    _savePreferences();
    notifyListeners();
    _ttsService.speak(enabled ? 'Punto d\'oro attivato.' : 'Vantaggi tradizionali attivati.');
  }

  void toggleMute() {
    _ttsService.setMuted(!_ttsService.isMuted);
    notifyListeners();
  }
}
