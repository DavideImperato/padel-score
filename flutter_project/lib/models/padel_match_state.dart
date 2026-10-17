import 'package:flutter/foundation.dart';

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
