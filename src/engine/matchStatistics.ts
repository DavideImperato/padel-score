import type { ArchivedMatch } from './matchHistory';
import type { PlayerDirectory } from './playerDirectory';

/** Statistiche derivate: non modifica mai lo storico e non usa i nomi come identificativi. */
export interface StatisticsRow {
  id: string;
  name: string;
  played: number;
  wins: number;
  losses: number;
  winRate: number;
  setsWon: number;
  setsLost: number;
  lastFive: ('W' | 'L')[];
  shortSets: number;
  standardSets: number;
}
export interface MatchStatistics {
  players: StatisticsRow[];
  pairs: StatisticsRow[];
  totalCompleted: number;
  unlinkedMatches: number;
}

const newRow = (id: string, name: string): StatisticsRow => ({
  id, name, played: 0, wins: 0, losses: 0, winRate: 0,
  setsWon: 0, setsLost: 0, lastFive: [], shortSets: 0, standardSets: 0,
});

/** Lo stesso identico duo è riconosciuto anche se cambia ordine o nome della coppia. */
const pairKey = (a: string, b: string) => JSON.stringify([a, b].sort());

const applyResult = (row: StatisticsRow, match: ArchivedMatch, side: 'teamA' | 'teamB') => {
  row.played += 1;
  const won = match.winner === side;
  if (won) row.wins++; else row.losses++;
  row.lastFive.push(won ? 'W' : 'L');
  const wonSets = match.sets.filter(s => s.winner === side).length;
  row.setsWon += wonSets;
  row.setsLost += match.sets.length - wonSets;
  if (match.gamesPerSet === 4) row.shortSets++; else row.standardSets++;
};

const finalize = (rows: StatisticsRow[]): StatisticsRow[] => rows
  .map(row => ({ ...row,
    winRate: row.played ? Math.round(row.wins / row.played * 1000) / 10 : 0,
    lastFive: row.lastFive.slice(0, 5),
  }))
  .sort((a, b) => b.wins - a.wins || b.winRate - a.winRate || b.played - a.played || a.name.localeCompare(b.name, 'it'));

export function calculateMatchStatistics(directory: PlayerDirectory, completed: readonly ArchivedMatch[]): MatchStatistics {
  const players = new Map(directory.players.map(p => [p.id, newRow(p.id, p.name)]));
  const pairs = new Map(directory.pairs.map(p => [pairKey(p.playerIds[0], p.playerIds[1]), newRow(p.id, p.name)]));
  let unlinkedMatches = 0;

  // Ordinamento per data: il trend resta stabile anche con archivio non ordinato.
  const matches = [...completed].sort((a, b) => b.completedAt - a.completedAt || a.id.localeCompare(b.id));
  for (const match of matches) {
    const ids = match.playerIds;
    if (!ids || !ids.some(id => id !== null) ||
        new Set(ids.filter((id): id is string => id !== null)).size !== ids.filter(id => id !== null).length) {
      unlinkedMatches++;
      continue;
    }
    let attributed = false;
    for (let side = 0; side < 2; side++) {
      const team: 'teamA' | 'teamB' = side === 0 ? 'teamA' : 'teamB';
      const first = ids[side * 2];
      const second = ids[side * 2 + 1];
      for (const id of [first, second]) {
        if (id && players.has(id)) { applyResult(players.get(id)!, match, team); attributed = true; }
      }
      if (first && second) {
        const pair = pairs.get(pairKey(first, second));
        if (pair) { applyResult(pair, match, team); attributed = true; }
      }
    }
    if (!attributed) unlinkedMatches++;
  }
  return {
    players: finalize([...players.values()]),
    pairs: finalize([...pairs.values()]),
    totalCompleted: completed.length,
    unlinkedMatches,
  };
}
