export type Team = 'teamA' | 'teamB';

export interface SetScore {
  gamesA: number;
  gamesB: number;
  tieBreakPointsA?: number;
  tieBreakPointsB?: number;
  isCompleted: boolean;
  winner?: Team;
}

export interface PadelMatchSnapshot {
  rawPointsA: number; // 0=0, 1=15, 2=30, 3=40, 4=AV
  rawPointsB: number;
  currentGamesA: number;
  currentGamesB: number;
  completedSets: SetScore[];
  servingTeam: Team;
  servingRotationIndex: number;
  initialSetServer: Team;
  isTieBreak: boolean;
  tieBreakPointsA: number;
  tieBreakPointsB: number;
  tieBreakInitialRotationIndex?: number;
  matchWinner?: Team;
  lastEventMessage: string;
}

export interface MatchSettings {
  teamAName: string;
  teamBName: string;
  player1Name: string;
  player2Name: string;
  player3Name: string;
  player4Name: string;
  firstServerPlayerId: number; // 1, 2, 3 or 4
  isGoldenPoint: boolean;
  bestOfSets: number; // 1, 3, or 5
  ttsSpeed: number; // 0.8 to 1.3
  ttsVolume: number; // 0 to 1
  isMuted: boolean;
}
