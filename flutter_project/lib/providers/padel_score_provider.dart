// Vedi visualizzatore completo per padel_score_provider.dart
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
