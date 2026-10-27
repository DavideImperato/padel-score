import { decodeCheckpoint, type CheckpointStorage, type MatchCheckpoint } from './matchPersistence';

export const INTERRUPTED_MATCHES_KEY = 'padel_interrupted_matches_v1';
export const MAX_INTERRUPTED_MATCHES = 30;

export interface InterruptedMatch {
  version: 1;
  id: string;
  interruptedAt: number;
  checkpoint: MatchCheckpoint;
}

const object = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

export function isInterruptedMatch(value: unknown): value is InterruptedMatch {
  if (!object(value) || value.version !== 1 || typeof value.id !== 'string' ||
      !value.id.length || value.id.length > 128 ||
      typeof value.interruptedAt !== 'number' || !Number.isSafeInteger(value.interruptedAt) ||
      value.interruptedAt <= 0 || !object(value.checkpoint)) return false;
  const checkpoint = decodeCheckpoint(JSON.stringify(value.checkpoint));
  return checkpoint !== null && !checkpoint.state.snapshot.matchWinner &&
    checkpoint.runtime.matchId === value.id;
}

// null means corrupted/unreadable: never overwrite it as an empty archive.
function read(storage: CheckpointStorage): InterruptedMatch[] | null {
  const raw = storage.getItem(INTERRUPTED_MATCHES_KEY);
  if (raw === null) return [];
  const value: unknown = JSON.parse(raw);
  if (!Array.isArray(value) || value.length > MAX_INTERRUPTED_MATCHES ||
      !value.every(isInterruptedMatch)) return null;
  return value;
}

export function loadInterruptedMatches(storage: CheckpointStorage): InterruptedMatch[] {
  try { return (read(storage) ?? []).slice().sort((a, b) => b.interruptedAt - a.interruptedAt); }
  catch { return []; }
}

export function findInterruptedMatch(storage: CheckpointStorage, id: string): InterruptedMatch | null {
  try { return read(storage)?.find(entry => entry.id === id) ?? null; }
  catch { return null; }
}

export function archiveInterruptedMatch(
  storage: CheckpointStorage, checkpoint: MatchCheckpoint,
): 'saved' | 'exists' | 'unavailable' {
  const id = checkpoint.runtime.matchId;
  if (!id) return 'unavailable';
  const record: InterruptedMatch = {
    version: 1, id, interruptedAt: Date.now(),
    checkpoint: {
      ...checkpoint,
      runtime: { ...checkpoint.runtime, isTimerRunning: false, isBreakActive: false, breakSecondsLeft: 0, view: 'scoreboard' },
    },
  };
  if (!isInterruptedMatch(record)) return 'unavailable';
  try {
    const entries = read(storage);
    if (!entries) return 'unavailable';
    if (entries.some(entry => entry.id === id)) return 'exists';
    if (entries.length >= MAX_INTERRUPTED_MATCHES) return 'unavailable';
    storage.setItem(INTERRUPTED_MATCHES_KEY, JSON.stringify([record, ...entries]));
    return 'saved';
  } catch { return 'unavailable'; }
}

export function removeInterruptedMatch(storage: CheckpointStorage, id: string): boolean {
  try {
    const entries = read(storage);
    if (!entries || !entries.some(entry => entry.id === id)) return false;
    storage.setItem(INTERRUPTED_MATCHES_KEY, JSON.stringify(entries.filter(entry => entry.id !== id)));
    return true;
  } catch { return false; }
}
