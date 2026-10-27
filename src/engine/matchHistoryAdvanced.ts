import type { ArchivedMatch } from './matchHistory';
import type { InterruptedMatch } from './matchInterrupted';
import type { PlayerDirectory } from './playerDirectory';

export interface HistoryFilters {
  query: string;
  playerId: string;
  pairId: string;
  fromDate: string; // YYYY-MM-DD in local time
  toDate: string;
}
export const EMPTY_HISTORY_FILTERS: HistoryFilters = { query: '', playerId: '', pairId: '', fromDate: '', toDate: '' };

type IndexedMatch = { timestamp: number; searchable: string[]; ids: (string | null)[] };
const normalized = (text: string) => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('it-IT').trim();

/** Local-calendar bounds, with validation to prevent impossible dates such as 31/02. */
const dayStart = (value: string): number | null => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const [y, m, d] = value.split('-').map(Number);
  const local = new Date(y, m - 1, d);
  return local.getFullYear() === y && local.getMonth() === m - 1 && local.getDate() === d
    ? local.getTime() : null;
};
const nextDay = (value: string): number | null => {
  const start = dayStart(value);
  if (start === null) return null;
  const date = new Date(start);
  date.setDate(date.getDate() + 1);
  return date.getTime();
};

const check = (data: IndexedMatch, filters: HistoryFilters, directory: PlayerDirectory): boolean => {
  const from = filters.fromDate ? dayStart(filters.fromDate) : null;
  const toExclusive = filters.toDate ? nextDay(filters.toDate) : null;
  if (filters.fromDate && from === null || filters.toDate && toExclusive === null) return false;
  if (from !== null && data.timestamp < from || toExclusive !== null && data.timestamp >= toExclusive) return false;
  if (filters.playerId && !data.ids.includes(filters.playerId)) return false;
  if (filters.pairId) {
    const pair = directory.pairs.find(p => p.id === filters.pairId);
    if (!pair) return false;
    const matchesA = pair.playerIds.every(id => data.ids.slice(0, 2).includes(id));
    const matchesB = pair.playerIds.every(id => data.ids.slice(2, 4).includes(id));
    if (!matchesA && !matchesB) return false;
  }
  const query = normalized(filters.query);
  if (query) {
    const currentNames = data.ids.map(id => directory.players.find(p => p.id === id)?.name ?? '');
    if (![...data.searchable, ...currentNames].some(s => normalized(s).includes(query))) return false;
  }
  return true;
};

export const filterFinishedMatches = (matches: ArchivedMatch[], filters: HistoryFilters, directory: PlayerDirectory): ArchivedMatch[] =>
  matches.filter(item => check({ timestamp: item.completedAt,
    searchable: [item.teamAName, item.teamBName, ...item.players],
    ids: item.playerIds ?? [null, null, null, null],
  }, filters, directory));

export const filterInterruptedMatches = (matches: InterruptedMatch[], filters: HistoryFilters, directory: PlayerDirectory): InterruptedMatch[] =>
  matches.filter(item => {
    const s = item.checkpoint.settings;
    return check({ timestamp: item.interruptedAt,
      searchable: [s.teamAName, s.teamBName, s.player1Name, s.player2Name, s.player3Name, s.player4Name],
      ids: s.playerIds ?? [null, null, null, null],
    }, filters, directory);
  });

// Protect exports opened by spreadsheet programs from CSV formula injection.
const safeCell = (value: string | number): string => {
  let text = String(value).replace(/\r\n?/g, '\n');
  if (/^\s*[=+@\-\t\r]/.test(text)) text = `'${text}`;
  return `"${text.replace(/"/g, '""')}"`;
};
const row = (cells: (string | number)[]) => cells.map(safeCell).join(';');
const columns = ['Stato','Data ISO','Squadra A','Squadra B','Giocatore A1','Giocatore A2','Giocatore B1','Giocatore B2','Vincitore','Set','Durata (secondi)'];
const score = (set: { gamesA: number; gamesB: number; isMatchTieBreak?: boolean; tieBreakPointsA?: number; tieBreakPointsB?: number }) =>
  set.isMatchTieBreak ? `MTB ${set.tieBreakPointsA ?? 0}-${set.tieBreakPointsB ?? 0}` :
  `${set.gamesA}-${set.gamesB}${set.tieBreakPointsA != null && set.tieBreakPointsB != null ? ` (TB ${set.tieBreakPointsA}-${set.tieBreakPointsB})` : ''}`;

/** Exports only the visible, already-filtered matches. Nothing is uploaded. */
export function exportHistoryCsv(finished: ArchivedMatch[], interrupted: InterruptedMatch[] = []): string {
  const lines = [row(columns)];
  for (const item of finished) lines.push(row([
    'Conclusa', new Date(item.completedAt).toISOString(), item.teamAName, item.teamBName,
    ...item.players, item.winner === 'teamA' ? item.teamAName : item.teamBName,
    item.sets.map(score).join(' | '), item.durationSeconds,
  ]));
  for (const item of interrupted) {
    const { settings, state, runtime } = item.checkpoint;
    const snap = state.snapshot;
    const running = snap.isTieBreak ? `TB ${snap.tieBreakPointsA}-${snap.tieBreakPointsB}` : `${snap.currentGamesA}-${snap.currentGamesB}`;
    lines.push(row(['Interrotta', new Date(item.interruptedAt).toISOString(), settings.teamAName, settings.teamBName,
      settings.player1Name, settings.player2Name, settings.player3Name, settings.player4Name, '',
      [...snap.completedSets.map(score), `In corso ${running}`].join(' | '), runtime.matchSeconds]));
  }
  return `\uFEFF${lines.join('\r\n')}\r\n`;
}
