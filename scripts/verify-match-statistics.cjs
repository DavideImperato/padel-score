const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { ts = require('typescript'); }
Module._extensions['.ts'] = (mod, filename) => mod._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }, fileName: filename,
}).outputText, filename);
const { calculateMatchStatistics } = require('../src/engine/matchStatistics.ts');
const { readPlayerDirectory, renamePlayer, addPlayer, addPair } = require('../src/engine/playerDirectory.ts');
const { loadMatchHistory, removeArchivedMatch, MATCH_HISTORY_KEY } = require('../src/engine/matchHistory.ts');

let checks = 0;
const check = (condition, description) => { assert.ok(condition, description); checks++; };
const store = new Map();
const storage = {getItem: key => store.get(key) ?? null, setItem: (key, value) => store.set(key, value), removeItem: key => store.delete(key)};
for (const name of ['Mario', 'Luigi', 'Paolo', 'Marco']) check(addPlayer(storage, name).ok, 'aggiungi giocatore');
let directory = readPlayerDirectory(storage);
const ids = directory.players.map(p => p.id);
check(addPair(storage, 'Verde', ids[0], ids[1]).ok, 'prima coppia');
check(addPair(storage, 'Blu', ids[2], ids[3]).ok, 'seconda coppia');
directory = readPlayerDirectory(storage);
const record = (id, at, winner, playerIds, gamesPerSet = 6) => ({
  version: 1, id, completedAt: at, durationSeconds: 120, teamAName: 'Verde', teamBName: 'Blu',
  players: ['Mario','Luigi','Paolo','Marco'], ...(playerIds ? {playerIds} : {}), winner,
  sets: [
    {gamesA: 6, gamesB: 3, isCompleted: true, winner: 'teamA'},
    {gamesA: 4, gamesB: 6, isCompleted: true, winner: 'teamB'},
    {gamesA: 6, gamesB: 1, isCompleted: true, winner: 'teamA'},
  ], bestOfSets: 3, gamesPerSet,
});
const legacy = record('old', 1, 'teamA', undefined);
const one = record('one', 4, 'teamA', ids);
const two = record('two', 3, 'teamB', [ids[1], ids[0], ids[2], ids[3]], 4);
const manual = record('manual', 2, 'teamA', [null,null,null,null]);
store.set(MATCH_HISTORY_KEY, JSON.stringify([legacy, one, two, manual]));
let result = calculateMatchStatistics(directory, loadMatchHistory(storage));
check(result.totalCompleted === 4, 'totale include legacy');
check(result.unlinkedMatches === 2, 'legacy e manuali non attribuiti');
check(result.players.length === 4, '4 giocatori in classifica');
const mario = result.players.find(p => p.id === ids[0]);
check(mario.played === 2 && mario.wins === 1 && mario.losses === 1, 'conteggio giocatore');
check(mario.winRate === 50, 'percentuale');
check(mario.setsWon === 4 && mario.setsLost === 2, 'set vinti/persi');
check(mario.lastFive.join(',') === 'W,L', 'trend ordinato per data');
check(mario.standardSets === 1 && mario.shortSets === 1, 'modalità');
const verde = result.pairs.find(p => p.name === 'Verde');
check(verde.played === 2 && verde.wins === 1, 'coppia conta anche invertita');
check(result.pairs.find(p => p.name === 'Blu').wins === 1, 'vittoria squadra avversaria');
check(renamePlayer(storage, ids[0], 'Mario Nuovo').ok, 'rinomina senza cambiare id');
result = calculateMatchStatistics(readPlayerDirectory(storage), loadMatchHistory(storage));
check(result.players.find(p => p.id === ids[0]).name === 'Mario Nuovo', 'nome aggiornato');
check(result.players.find(p => p.id === ids[0]).played === 2, 'storico invariato dopo rinomina');
check(removeArchivedMatch(storage, 'one'), 'elimina risultato');
result = calculateMatchStatistics(readPlayerDirectory(storage), loadMatchHistory(storage));
check(result.players.find(p => p.id === ids[0]).wins === 0, 'eliminazione ricalcola le vittorie');
check(result.totalCompleted === 3, 'eliminazione ricalcola il totale');
const duplicated = record('duplicate', 6, 'teamA', [ids[0],ids[0],ids[2],ids[3]]);
result = calculateMatchStatistics(directory, [duplicated]);
check(result.unlinkedMatches === 1 && result.players.every(p => p.played === 0), 'id duplicati non conteggiati');
result = calculateMatchStatistics(directory, [record('partial',8,'teamA',[ids[0],null,ids[2],null])]);
check(result.players.find(p => p.id === ids[0]).played === 1, 'selezione singola conta');
check(result.pairs.every(p => p.played === 0), 'coppia incompleta non conta');
result = calculateMatchStatistics(directory, []);
check(result.players.every(p => p.winRate === 0 && p.lastFive.length === 0), 'nessuna partita');
check(result.totalCompleted === 0, 'nessun incontro');
check(result.unlinkedMatches === 0, 'nessun elemento non collegato');
const many = Array.from({length: 7}, (_,i) => record(`r${i}`, 100+i, i%2 ? 'teamB' : 'teamA', ids));
result = calculateMatchStatistics(directory, many);
check(result.players.find(p => p.id === ids[0]).lastFive.length === 5, 'ultimo andamento limitato a cinque');
check(result.players.find(p => p.id === ids[0]).lastFive[0] === 'W', 'ultimo risultato corretto');
check(result.pairs.find(p => p.name === 'Verde').played === 7, 'coppia 7 partite');
console.log(`OK ${checks} controlli statistiche React`);
