import type { MatchSettings, PadelMatchSnapshot, Team } from '../types/padel';
import type { MatchStoreState } from './padelMatchStore';
import { decodePointEvents } from './matchPointAnalytics';

export const CHECKPOINT_KEY = 'padel_active_match_v1';
export const CHECKPOINT_VERSION = 1;

export interface MatchRuntime {
  matchSeconds: number;
  isTimerRunning: boolean;
  isSidesSwapped: boolean;
  breakSecondsLeft: number;
  isBreakActive: boolean;
  view: 'scoreboard' | 'summary';
  matchId?: string;
}
export interface MatchCheckpoint {
  version: 1;
  savedAt: number;
  settings: MatchSettings;
  state: MatchStoreState;
  runtime: MatchRuntime;
}
export interface CheckpointStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}
const record = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value);
const integer = (n: unknown, min = 0, max = 1000000): n is number =>
  typeof n === 'number' && Number.isSafeInteger(n) && n >= min && n <= max;
const team = (s: unknown): s is Team => s === 'teamA' || s === 'teamB';
const validSet = (s: unknown): boolean =>
  record(s) && integer(s.gamesA, 0, 10000) && integer(s.gamesB, 0, 10000) &&
  typeof s.isCompleted === 'boolean' &&
  (s.winner === undefined || team(s.winner)) &&
  (s.tieBreakPointsA === undefined || integer(s.tieBreakPointsA, 0, 10000)) &&
  (s.tieBreakPointsB === undefined || integer(s.tieBreakPointsB, 0, 10000));
export const validSnapshot = (s: unknown): s is PadelMatchSnapshot =>
  record(s) && integer(s.rawPointsA, 0, 4) && integer(s.rawPointsB, 0, 4) &&
  integer(s.currentGamesA, 0, 10000) && integer(s.currentGamesB, 0, 10000) &&
  Array.isArray(s.completedSets) && s.completedSets.length <= 5 && s.completedSets.every(validSet) &&
  team(s.servingTeam) && team(s.initialSetServer) &&
  integer(s.servingRotationIndex, 0, 1000000) &&
  typeof s.isTieBreak === 'boolean' &&
  integer(s.tieBreakPointsA, 0, 10000) && integer(s.tieBreakPointsB, 0, 10000) &&
  (s.tieBreakInitialRotationIndex == null || integer(s.tieBreakInitialRotationIndex)) &&
  (s.matchWinner === undefined || team(s.matchWinner)) &&
  typeof s.lastEventMessage === 'string';
const validSettings = (s: unknown): s is MatchSettings =>
  record(s) && ['teamAName','teamBName','player1Name','player2Name','player3Name','player4Name'].every(k=>typeof s[k] === 'string') &&
  integer(s.firstServerPlayerId, 1, 4) && typeof s.isGoldenPoint === 'boolean' &&
  integer(s.advantagesBeforeGoldenPoint, 0, 5) && [1,3,5].includes(s.bestOfSets as number) &&
  (s.gamesPerSet === undefined || s.gamesPerSet === 4 || s.gamesPerSet === 6) &&
  (s.decidingTieBreakPoints === undefined || [7,10].includes(s.decidingTieBreakPoints as number));
const validRuntime = (r: unknown): r is MatchRuntime =>
  record(r) && integer(r.matchSeconds, 0, 10_000_000) && typeof r.isTimerRunning === 'boolean' &&
  typeof r.isSidesSwapped === 'boolean' && integer(r.breakSecondsLeft, 0, 10000) &&
  typeof r.isBreakActive === 'boolean' && (r.view === 'scoreboard' || r.view === 'summary') &&
  (r.matchId === undefined || (typeof r.matchId === 'string' && r.matchId.length > 0 && r.matchId.length <= 128));
export function decodeCheckpoint(raw: string | null): MatchCheckpoint | null {
  if (!raw) return null;
  try {
    const data: unknown = JSON.parse(raw);
    if (!record(data) || data.version !== CHECKPOINT_VERSION || !integer(data.savedAt, 1, 9e15) ||
      !validSettings(data.settings) || !record(data.state) || !validSnapshot(data.state.snapshot) ||
      !Array.isArray(data.state.history) || data.state.history.length > 50000 ||
      !data.state.history.every(validSnapshot) || !validRuntime(data.runtime) ||
      (data.state.pointEvents !== undefined && decodePointEvents(data.state.pointEvents) === null) ||
      (data.state.pointTrackingComplete !== undefined && typeof data.state.pointTrackingComplete !== 'boolean') ||
      (data.state.pointTrackingComplete === true && data.state.pointEvents === undefined)) return null;
    return data as unknown as MatchCheckpoint;
  } catch { return null; }
}
export function loadCheckpoint(storage: CheckpointStorage): MatchCheckpoint | null {
  try { return decodeCheckpoint(storage.getItem(CHECKPOINT_KEY)); } catch { return null; }
}
export function saveCheckpoint(storage: CheckpointStorage, settings: MatchSettings, state: MatchStoreState, runtime: MatchRuntime): boolean {
  try {
    const data: MatchCheckpoint = { version: 1, savedAt: Date.now(), settings, state, runtime };
    storage.setItem(CHECKPOINT_KEY, JSON.stringify(data));
    return true;
  } catch { return false; } // e.g. private mode / storage quota
}
export function clearCheckpoint(storage: CheckpointStorage): void {
  try { storage.removeItem(CHECKPOINT_KEY); } catch {}
}
