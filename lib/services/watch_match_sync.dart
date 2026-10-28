import 'package:flutter/services.dart';
import '../models/padel_match_state.dart';

/// Snapshot inviato dal motore iPhone; i comandi Watch ritornano via lo stesso canale.
class WatchMatchSync {
  static const MethodChannel _channel = MethodChannel('padel_score_board/watch_link');

  const WatchMatchSync();

  /// Il canale bidirezionale riceve comandi solo quando Flutter e` inizializzato.
  void registerCommandHandler(
      Future<Map<String, dynamic>> Function(Map<dynamic, dynamic>) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'watchCommand' || call.arguments is! Map) {
        throw MissingPluginException('Comando Watch non riconosciuto');
      }
      return handler(call.arguments as Map<dynamic, dynamic>);
    });
  }

  void unregisterCommandHandler() => _channel.setMethodCallHandler(null);

  Future<void> publish(Map<String, dynamic> state) async {
    try {
      await _channel.invokeMethod<void>('publishMatch', state);
    } on MissingPluginException {
      // Android, web e test non hanno il bridge nativo iOS.
    } on PlatformException {
      // La connessione Watch non deve mai bloccare o rallentare un punto.
    }
  }
}

/// Payload minimale: nessuno storico Undo e nessun dato personale persistito
/// sul Watch oltre ai nomi usati nella partita corrente.
Map<String, dynamic> buildWatchMatchState({
  required String matchId,
  required bool active,
  required bool awaitingRecovery,
  required PadelMatchSnapshot snapshot,
  required String teamAName,
  required String teamBName,
  required List<String> players,
  required String servingPlayer,
  required int servingPlayerId,
  required bool goldenPoint,
  required int advantagesBeforeGoldenPoint,
  required bool shortSets,
  required int bestOfSets,
  required bool decidingMatchTieBreak,
  required int decidingTieBreakPoints,
  required int elapsedSeconds,
  required bool timerRunning,
  required bool canUndo,
  bool sidesSwapped = false,
  bool canChangeRules = false,
  bool canChangeServer = false,
}) {
  final status = awaitingRecovery ? 'recovery' :
      (active ? (snapshot.matchWinner == null ? 'live' : 'finished') : 'idle');
  return <String, dynamic>{
    'version': 1,
    'matchId': matchId,
    'sentAt': DateTime.now().microsecondsSinceEpoch,
    'status': status,
    'teamA': teamAName,
    'teamB': teamBName,
    'players': players,
    'pointsA': snapshot.displayPointA,
    'pointsB': snapshot.displayPointB,
    'gamesA': snapshot.currentGamesA,
    'gamesB': snapshot.currentGamesB,
    'setsA': snapshot.completedSets.where((s) => s.winner == Team.teamA).length,
    'setsB': snapshot.completedSets.where((s) => s.winner == Team.teamB).length,
    'sets': snapshot.completedSets.map((s) => <String, dynamic>{
      'gamesA': s.gamesA,
      'gamesB': s.gamesB,
      'tieBreakA': s.tieBreakPointsA ?? -1,
      'tieBreakB': s.tieBreakPointsB ?? -1,
      'matchTieBreak': s.isMatchTieBreak,
    }).toList(),
    'isTieBreak': snapshot.isTieBreak,
    'isMatchTieBreak': snapshot.isMatchTieBreak,
    'servingPlayer': servingPlayer,
    'servingPlayerId': servingPlayerId,
    'servingTeam': servingPlayerId <= 2 ? 'A' : 'B',
    'winner': snapshot.matchWinner == Team.teamA ? 'A' :
        (snapshot.matchWinner == Team.teamB ? 'B' : ''),
    'rules': goldenPoint
        ? (advantagesBeforeGoldenPoint == 2 ? 'Star Point' :
           (advantagesBeforeGoldenPoint == 0 ? 'Punto d’oro' : 'Punto d’oro dopo vantaggi'))
        : 'Vantaggi tradizionali',
    'shortSets': shortSets,
    'bestOfSets': bestOfSets,
    'decidingMatchTieBreak': decidingMatchTieBreak,
    'decidingTieBreakPoints': decidingTieBreakPoints,
    'elapsedSeconds': elapsedSeconds,
    'timerRunning': timerRunning,
    'canUndo': canUndo,
    'sidesSwapped': sidesSwapped,
    'canChangeRules': canChangeRules,
    'canChangeServer': canChangeServer,
    'lastEvent': snapshot.lastEventMessage,
  };
}
