import type { PadelMatchSnapshot, Team, MatchSettings } from '../types/padel';
import { getCurrentServerPlayerId } from './padelScoringEngine';

/** Compatible con il campo pointEvents della Fase 5D Flutter. */
export const MAX_POINT_EVENTS = 5000;
export interface PointEvent {
  index: number;
  undoDepth: number;
  elapsedSeconds: number;
  occurredAt: number;
  team: Team;
  serverPlayerId: number;
  setNumber: number;
  gamesA: number;
  gamesB: number;
  beforeA: string;
  beforeB: string;
  afterA: string;
  afterB: string;
  isTieBreak: boolean;
  isMatchTieBreak: boolean;
  isGoldenPoint: boolean;
  gameWon: boolean;
  setWon: boolean;
  matchWon: boolean;
}

const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const integer = (v: unknown, max: number): v is number => typeof v === 'number' && Number.isSafeInteger(v) && v >= 0 && v <= max;
const labels = ['0', '15', '30', '40', 'AV'];
function score(s: PadelMatchSnapshot, team: Team): string {
  return s.isTieBreak ? String(team === 'teamA' ? s.tieBreakPointsA : s.tieBreakPointsB) :
    labels[team === 'teamA' ? s.rawPointsA : s.rawPointsB] ?? '0';
}
export function makePointEvent(
  index: number, undoDepth: number, elapsedSeconds: number,
  team: Team, before: PadelMatchSnapshot, after: PadelMatchSnapshot, settings: MatchSettings,
  occurredAt = Date.now(),
): PointEvent {
  const setWon = after.completedSets.length > before.completedSets.length;
  const gameWon = setWon || after.currentGamesA !== before.currentGamesA || after.currentGamesB !== before.currentGamesB;
  const finishedSet = setWon ? after.completedSets[after.completedSets.length - 1] : undefined;
  const winningTieBreak = !!before.isTieBreak && !!finishedSet;
  return {
    index, undoDepth, elapsedSeconds, occurredAt, team,
    serverPlayerId: getCurrentServerPlayerId(before, settings.firstServerPlayerId),
    setNumber: before.completedSets.length + 1,
    gamesA: before.currentGamesA, gamesB: before.currentGamesB,
    beforeA: score(before, 'teamA'), beforeB: score(before, 'teamB'),
    afterA: winningTieBreak ? String(finishedSet.tieBreakPointsA ?? 0) : score(after, 'teamA'),
    afterB: winningTieBreak ? String(finishedSet.tieBreakPointsB ?? 0) : score(after, 'teamB'),
    isTieBreak: before.isTieBreak, isMatchTieBreak: !!before.isMatchTieBreak,
    isGoldenPoint: !!settings.isGoldenPoint && !before.isTieBreak && before.rawPointsA === 3 && before.rawPointsB === 3 &&
      (before.deuceCount ?? 0) >= (settings.advantagesBeforeGoldenPoint ?? 0),
    gameWon, setWon, matchWon: !!after.matchWinner,
  };
}
export function decodePointEvents(raw: unknown): PointEvent[] | null {
  if (!Array.isArray(raw) || raw.length > MAX_POINT_EVENTS) return null;
  let prevSeconds = 0;
  const result: PointEvent[] = [];
  for (const [i, e] of raw.entries()) {
    if (!object(e) || e.index !== i + 1 || !integer(e.undoDepth, 50000) ||
      !integer(e.elapsedSeconds, 100000000) || e.elapsedSeconds < prevSeconds ||
      !integer(e.occurredAt, 9000000000000000) || !integer(e.setNumber, 5) || e.setNumber < 1 ||
      !integer(e.gamesA, 10000) || !integer(e.gamesB, 10000) ||
      !integer(e.serverPlayerId, 4) || e.serverPlayerId < 1 ||
      !['teamA','teamB'].includes(e.team as string) ||
      !['beforeA','beforeB','afterA','afterB'].every(k => typeof e[k] === 'string' && (e[k] as string).length <= 16) ||
      !['isTieBreak','isMatchTieBreak','isGoldenPoint','gameWon','setWon','matchWon'].every(k => typeof e[k] === 'boolean')) return null;
    prevSeconds = e.elapsedSeconds;
    result.push(e as unknown as PointEvent);
  }
  return result;
}
export interface PointAnalytics {
  totalPoints: number; pointsA: number; pointsB: number;
  pointShareA: number | null; pointShareB: number | null;
  longestStreakA: number; longestStreakB: number;
  leadChanges: number; goldenPointsA: number; goldenPointsB: number;
  tieBreakPointsA: number; tieBreakPointsB: number;
  gamesWonA: number; gamesWonB: number; breakGamesA: number; breakGamesB: number;
  timeline: Array<{ index: number; a: number; b: number }>;
  lastTen: PointEvent[];
}
/** null = match legacy o registro non attendibile; mai stimare i punti dai game. */
export function calculatePointAnalytics(raw: unknown): PointAnalytics | null {
  const events = decodePointEvents(raw);
  if (events === null) return null;
  let a = 0, b = 0, streakA = 0, streakB = 0, maxA = 0, maxB = 0;
  let leadChanges = 0, lastLeader = 0, goldenPointsA = 0, goldenPointsB = 0;
  let tieBreakPointsA = 0, tieBreakPointsB = 0, gamesWonA = 0, gamesWonB = 0, breakGamesA = 0, breakGamesB = 0;
  const timeline = [{ index: 0, a: 0, b: 0 }];
  for (const e of events) {
    const teamA = e.team === 'teamA';
    if (teamA) { a++; streakA++; streakB = 0; maxA = Math.max(maxA, streakA); }
    else { b++; streakB++; streakA = 0; maxB = Math.max(maxB, streakB); }
    if (e.isGoldenPoint) { if (teamA) goldenPointsA++; else goldenPointsB++; }
    if (e.isTieBreak) { if (teamA) tieBreakPointsA++; else tieBreakPointsB++; }
    if (e.gameWon && !e.isMatchTieBreak) {
      const serverTeamA = e.serverPlayerId === 1 || e.serverPlayerId === 2;
      if (teamA) { gamesWonA++; if (!serverTeamA) breakGamesA++; }
      else { gamesWonB++; if (serverTeamA) breakGamesB++; }
    }
    const leader = a === b ? 0 : a > b ? 1 : -1;
    if (leader !== 0) { if (lastLeader && leader !== lastLeader) leadChanges++; lastLeader = leader; }
    timeline.push({ index: a + b, a, b });
  }
  return {
    totalPoints: events.length, pointsA: a, pointsB: b,
    pointShareA: events.length ? a * 100 / events.length : null,
    pointShareB: events.length ? b * 100 / events.length : null,
    longestStreakA: maxA, longestStreakB: maxB, leadChanges,
    goldenPointsA, goldenPointsB, tieBreakPointsA, tieBreakPointsB,
    gamesWonA, gamesWonB, breakGamesA, breakGamesB,
    timeline, lastTen: events.slice(-10),
  };
}
