import type { MatchSettings, PadelMatchSnapshot, SetScore, Team } from '../types/padel';
import type { CheckpointStorage } from './matchPersistence';
import { decodePointEvents, type PointEvent } from './matchPointAnalytics';

export const MATCH_HISTORY_KEY = 'padel_completed_matches_v1';
const VERSION = 1;
export const MAX_ARCHIVED_MATCHES = 250;

export interface ArchivedMatch {
  version: 1;
  id: string;
  completedAt: number;
  durationSeconds: number;
  teamAName: string;
  teamBName: string;
  players: [string, string, string, string];
  playerIds?: [string | null, string | null, string | null, string | null];
  winner: Team;
  sets: SetScore[];
  bestOfSets: number;
  gamesPerSet: 4 | 6;
  pointEvents?: PointEvent[];
}

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);
const strId = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && v.length <= 100;
const isTeam = (value: unknown): value is Team => value === 'teamA' || value === 'teamB';
const validNumber = (value: unknown, max: number): value is number =>
  Number.isSafeInteger(value) && (value as number) >= 0 && (value as number) <= max;

export function isArchivedMatch(value: unknown): value is ArchivedMatch {
  if (!isObject(value) || value.version !== VERSION || typeof value.id !== 'string' ||
      value.id.length < 1 || value.id.length > 128 || !validNumber(value.completedAt, 9e15) ||
      !validNumber(value.durationSeconds, 10_000_000) ||
      typeof value.teamAName !== 'string' || typeof value.teamBName !== 'string' ||
      !Array.isArray(value.players) || value.players.length !== 4 ||
      !value.players.every(v => typeof v === 'string') ||
      (value.playerIds !== undefined && (!Array.isArray(value.playerIds) || value.playerIds.length !== 4 || !value.playerIds.every(v => v === null || strId(v)))) || !isTeam(value.winner) ||
      ![1, 3, 5].includes(value.bestOfSets as number) ||
      ![4, 6].includes(value.gamesPerSet as number) ||
      !Array.isArray(value.sets) || value.sets.length < 1 || value.sets.length > 5 ||
      (value.pointEvents !== undefined && decodePointEvents(value.pointEvents) === null)) return false;
  return value.sets.every(s => isObject(s) && validNumber(s.gamesA, 10000) &&
    validNumber(s.gamesB, 10000) && s.isCompleted === true && isTeam(s.winner) &&
    (s.isMatchTieBreak === undefined || typeof s.isMatchTieBreak === 'boolean') &&
    (s.tieBreakPointsA === undefined || validNumber(s.tieBreakPointsA, 10000)) &&
    (s.tieBreakPointsB === undefined || validNumber(s.tieBreakPointsB, 10000)));
}

// Non si recuperano dati parzialmente corrotti: evitare di sovrascrivere uno storico non valido.
function read(storage: CheckpointStorage): ArchivedMatch[] | null {
  const raw = storage.getItem(MATCH_HISTORY_KEY);
  if (raw === null) return [];
  const decoded: unknown = JSON.parse(raw);
  if (!Array.isArray(decoded) || decoded.length > MAX_ARCHIVED_MATCHES ||
      !decoded.every(isArchivedMatch)) return null;
  return decoded;
}

export function loadMatchHistory(storage: CheckpointStorage): ArchivedMatch[] {
  try { return (read(storage) ?? []).slice().sort((a, b) => b.completedAt - a.completedAt); }
  catch { return []; }
}

export function archiveCompletedMatch(
  storage: CheckpointStorage, id: string, settings: MatchSettings,
  snapshot: PadelMatchSnapshot, durationSeconds: number,
  completedAt = Date.now(), pointEvents?: PointEvent[],
): 'saved' | 'exists' | 'notFinished' | 'unavailable' {
  if (!snapshot.matchWinner || !snapshot.completedSets.length) return 'notFinished';
  const record: ArchivedMatch = {
    version: 1, id, completedAt, durationSeconds,
    teamAName: settings.teamAName, teamBName: settings.teamBName,
    players: [settings.player1Name, settings.player2Name, settings.player3Name, settings.player4Name],
    ...(settings.playerIds ? { playerIds: settings.playerIds } : {}),
    winner: snapshot.matchWinner,
    sets: snapshot.completedSets.map(s => ({ ...s })),
    bestOfSets: settings.bestOfSets,
    gamesPerSet: settings.gamesPerSet === 4 ? 4 : 6,
    ...(pointEvents !== undefined ? { pointEvents: pointEvents.map(e => ({ ...e })) } : {}),
  };
  if (!isArchivedMatch(record)) return 'unavailable';
  try {
    const items = read(storage);
    if (items === null) return 'unavailable';
    if (items.some(item => item.id === id)) return 'exists';
    if (items.length >= MAX_ARCHIVED_MATCHES) return 'unavailable';
    storage.setItem(MATCH_HISTORY_KEY, JSON.stringify([record, ...items]));
    return 'saved';
  } catch { return 'unavailable'; }
}

export function removeArchivedMatch(storage: CheckpointStorage, id: string): boolean {
  try {
    const items = read(storage);
    if (items === null || !items.some(item => item.id === id)) return false;
    storage.setItem(MATCH_HISTORY_KEY, JSON.stringify(items.filter(item => item.id !== id)));
    return true;
  } catch { return false; }
}
