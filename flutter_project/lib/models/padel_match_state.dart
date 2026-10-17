import 'package:flutter/foundation.dart';

enum Team {
  teamA,
  teamB;

  Team get opposite => this == Team.teamA ? Team.teamB : Team.teamA;
}

/// Rappresenta il punteggio di un singolo set completato o in corso
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

  SetScore copyWith({
    int? gamesA,
    int? gamesB,
    int? tieBreakPointsA,
    int? tieBreakPointsB,
    bool? isCompleted,
    Team? winner,
  }) {
    return SetScore(
      gamesA: gamesA ?? this.gamesA,
      gamesB: gamesB ?? this.gamesB,
      tieBreakPointsA: tieBreakPointsA ?? this.tieBreakPointsA,
      tieBreakPointsB: tieBreakPointsB ?? this.tieBreakPointsB,
      isCompleted: isCompleted ?? this.isCompleted,
      winner: winner ?? this.winner,
    );
  }

  @override
  String toString() {
    if (tieBreakPointsA != null && tieBreakPointsB != null) {
      return '$gamesA-$gamesB ($tieBreakPointsA-$tieBreakPointsB)';
    }
    return '$gamesA-$gamesB';
  }
}

/// Snapshot immutabile dello stato della partita, fondamentale per il sistema Undo
@immutable
class PadelMatchSnapshot {
  /// Punti del game corrente: 0 -> 0, 1 -> 15, 2 -> 30, 3 -> 40, 4 -> Vantaggio (AV)
  final int rawPointsA;
  final int rawPointsB;

  /// Game vinti nel set corrente
  final int currentGamesA;
  final int currentGamesB;

  /// Lista dei set completati finora
  final List<SetScore> completedSets;

  /// Squadra attualmente al servizio
  final Team servingTeam;

  /// Indice nella rotazione dei 4 giocatori (0..3 o cumulativo)
  /// Regola ufficiale Padel:
  /// Turno 0: Giocatore 1 (Sq. 1)
  /// Turno 1: Giocatore 3 (Sq. 2)
  /// Turno 2: Giocatore 2 (Sq. 1)
  /// Turno 3: Giocatore 4 (Sq. 2)
  final int servingRotationIndex;

  /// Chi ha iniziato a servire nel set corrente (per alternanza set)
  final Team initialSetServer;

  /// Flag se siamo in Tie-Break
  final bool isTieBreak;

  /// Punti numerici del Tie-Break
  final int tieBreakPointsA;
  final int tieBreakPointsB;

  /// Indice di rotazione battitore all'inizio del Tie-Break
  final int? tieBreakInitialRotationIndex;

  /// Vincitore della partita (null se in corso)
  final Team? matchWinner;

  /// Messaggio descrittivo dell'ultimo evento
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

  /// Crea lo snapshot iniziale di una nuova partita
  factory PadelMatchSnapshot.initial({
    Team initialServer = Team.teamA,
    int initialRotationIndex = 0,
  }) {
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

  /// Stringa visuale del punteggio game (es. '0', '15', '30', '40', 'AV')
  String get displayPointA {
    if (isTieBreak) return tieBreakPointsA.toString();
    return _formatStandardPoint(rawPointsA);
  }

  String get displayPointB {
    if (isTieBreak) return tieBreakPointsB.toString();
    return _formatStandardPoint(rawPointsB);
  }

  static String _formatStandardPoint(int point) {
    switch (point) {
      case 0:
        return '0';
      case 1:
        return '15';
      case 2:
        return '30';
      case 3:
        return '40';
      case 4:
        return 'AV';
      default:
        return '0';
    }
  }

  /// Verifica se è punto d'oro (40-40 con regola Punto d'Oro)
  bool isGoldenPointSituation(bool goldenPointEnabled) {
    if (isTieBreak) return false;
    return goldenPointEnabled && rawPointsA == 3 && rawPointsB == 3;
  }

  /// Verifica parità 40-40 (Deuce)
  bool get isDeuce => !isTieBreak && rawPointsA == 3 && rawPointsB == 3;

  /// Copia con override dei campi
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
      completedSets: completedSets ?? List.unmodifiable(this.completedSets),
      servingTeam: servingTeam ?? this.servingTeam,
      servingRotationIndex: servingRotationIndex ?? this.servingRotationIndex,
      initialSetServer: initialSetServer ?? this.initialSetServer,
      isTieBreak: isTieBreak ?? this.isTieBreak,
      tieBreakPointsA: tieBreakPointsA ?? this.tieBreakPointsA,
      tieBreakPointsB: tieBreakPointsB ?? this.tieBreakPointsB,
      tieBreakInitialRotationIndex:
          tieBreakInitialRotationIndex ?? this.tieBreakInitialRotationIndex,
      matchWinner: matchWinner ?? this.matchWinner,
      lastEventMessage: lastEventMessage ?? this.lastEventMessage,
    );
  }
}
