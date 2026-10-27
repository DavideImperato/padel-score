export type Team = 'teamA' | 'teamB';

export interface SetScore {
  gamesA: number;
  gamesB: number;
  tieBreakPointsA?: number;
  tieBreakPointsB?: number;
  isCompleted: boolean;
  isMatchTieBreak?: boolean;
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
  isMatchTieBreak?: boolean;
  tieBreakPointsA: number;
  tieBreakPointsB: number;
  tieBreakInitialRotationIndex?: number;
  deuceCount?: number; // Quante volte si è tornati in parità nel game corrente (per vantaggi prima del punto d'oro)
  matchWinner?: Team;
  lastEventMessage: string;
}

export interface MatchSettings {
  /** Identità anagrafica opzionale: i nomi manuali restano supportati. */
  playerIds?: [string | null, string | null, string | null, string | null];
  teamAName: string;
  teamBName: string;
  player1Name: string;
  player2Name: string;
  player3Name: string;
  player4Name: string;
  firstServerPlayerId: number; // 1, 2, 3 or 4
  isGoldenPoint: boolean;
  advantagesBeforeGoldenPoint: number; // 0 = subito punto d'oro, 1 = 1 vantaggio poi punto d'oro, 2 = 2 vantaggi poi punto d'oro
  bestOfSets: number; // 1, 3, or 5
  decidingMatchTieBreak?: boolean; // sostituisce l'ultimo set con un tie-break decisivo
  decidingTieBreakPoints?: 7 | 10; // FIP: 7 oppure super tie-break a 10; default 10
  gamesPerSet?: 4 | 6; // 4 = mini-set FIP, 6 = set normale (default)
  ttsSpeed: number; // 0.8 to 1.3
  ttsVolume: number; // 0 to 1
  isMuted?: boolean;
  isVoiceMuted: boolean;
  isSfxMuted: boolean;
}
