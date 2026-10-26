import 'package:flutter/foundation.dart';

enum Team {
  teamA,
  teamB;

  Team get opposite => this == Team.teamA ? Team.teamB : Team.teamA;
}

typedef PlayerId = int; // 1, 2, 3, o 4

/// Associa stabilmente l'ID giocatore alla squadra di appartenenza (Regolamento FIP).
/// Giocatore 1 e 2 -> Squadra A
/// Giocatore 3 e 4 -> Squadra B
Team getTeamForPlayerId(int playerId) {
  return (playerId == 1 || playerId == 2) ? Team.teamA : Team.teamB;
}

/// Restituisce la sequenza ciclica di rotazione dei 4 battitori (ID stabili)
/// in base al primo battitore scelto (identica al motore TypeScript).
List<int> getRotationOrder(int firstServerPlayerId) {
  switch (firstServerPlayerId) {
    case 1:
      return const [1, 3, 2, 4];
    case 2:
      return const [2, 3, 1, 4];
    case 3:
      return const [3, 1, 4, 2];
    case 4:
      return const [4, 1, 3, 2];
    default:
      return const [1, 3, 2, 4];
  }
}

/// Determina l'ID del giocatore attualmente al servizio.
/// Nel Tie-break la sequenza è 1-2-2-2...
/// Nei game ordinari è ciclica sulla rotazione dei 4 battitori.
int getCurrentServerPlayerId(PadelMatchSnapshot snapshot, int firstServerPlayerId) {
  final rotation = getRotationOrder(firstServerPlayerId);
  if (snapshot.isTieBreak) {
    final int initialIdx =
        snapshot.tieBreakInitialRotationIndex ?? snapshot.servingRotationIndex;
    final int totalPoints = snapshot.tieBreakPointsA + snapshot.tieBreakPointsB;
    final int shift = totalPoints == 0 ? 0 : ((totalPoints + 1) ~/ 2);
    return rotation[(initialIdx + shift) % rotation.length];
  }
  return rotation[snapshot.servingRotationIndex % rotation.length];
}

/// Determina la squadra al servizio direttamente dall'ID del battitore attivo.
Team getCurrentServingTeam(PadelMatchSnapshot snapshot, int firstServerPlayerId) {
  final playerId = getCurrentServerPlayerId(snapshot, firstServerPlayerId);
  return getTeamForPlayerId(playerId);
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

  /// Conteggio ritorni a 40-40 nel game corrente (per Star Point FIP 2026)
  final int deuceCount;

  /// Game vinti nel set corrente
  final int currentGamesA;
  final int currentGamesB;

  /// Lista dei set completati finora
  final List<SetScore> completedSets;

  /// Squadra attualmente al servizio
  final Team servingTeam;

  /// Indice nella rotazione ciclica dei 4 battitori (0..3 cumulativo)
  final int servingRotationIndex;

  /// Chi ha iniziato a servire nel set corrente
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
    this.deuceCount = 0,
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
      deuceCount: 0,
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

  /// Verifica se è punto d'oro (40-40 con regola Punto d'Oro o Star Point)
  bool isGoldenPointSituation(bool goldenPointEnabled, [int advantagesBeforeGoldenPoint = 0]) {
    if (isTieBreak) return false;
    return goldenPointEnabled &&
        rawPointsA == 3 &&
        rawPointsB == 3 &&
        deuceCount >= advantagesBeforeGoldenPoint;
  }

  /// Verifica parità 40-40 (Deuce)
  bool get isDeuce => !isTieBreak && rawPointsA == 3 && rawPointsB == 3;

  /// Copia con override dei campi
  PadelMatchSnapshot copyWith({
    int? rawPointsA,
    int? rawPointsB,
    int? deuceCount,
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
      deuceCount: deuceCount ?? this.deuceCount,
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
