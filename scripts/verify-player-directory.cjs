// Suite standalone: verifica anagrafica offline e relazioni con lo storico senza UI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { ts = require('typescript'); }
Module._extensions['.ts'] = (mod, filename) => mod._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }, fileName: filename,
}).outputText, filename);
const { PLAYER_DIRECTORY_KEY, readPlayerDirectory, addPlayer, renamePlayer, removePlayer, addPair, removePair, MAX_PLAYERS } = require('../src/engine/playerDirectory.ts');
const { PadelMatchStore } = require('../src/engine/padelMatchStore.ts');
const { archiveCompletedMatch, loadMatchHistory, MATCH_HISTORY_KEY } = require('../src/engine/matchHistory.ts');
const { saveCheckpoint, loadCheckpoint } = require('../src/engine/matchPersistence.ts');
const data = new Map();
const storage = { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value), removeItem: key => data.delete(key) };
let checks = 0;
const check = (condition, message) => { assert.ok(condition, message); checks++; };
check(readPlayerDirectory(storage).players.length === 0, 'nuova rubrica');
check(addPlayer(storage, '  Mario   Rossi  ').ok, 'aggiungi giocatore');
check(!addPlayer(storage, 'mario rossi').ok, 'no doppione ignorando maiuscole');
check(addPlayer(storage, 'Luigi Verdi').ok, 'secondo giocatore');
check(addPlayer(storage, 'Paolo Bianchi').ok, 'terzo giocatore');
check(addPlayer(storage, 'Marco Neri').ok, 'quarto giocatore');
let directory = readPlayerDirectory(storage);
check(directory.players.length === 4, 'quattro giocatori');
const ids = directory.players.map(p => p.id);
check(new Set(ids).size === 4, 'ids unici');
check(directory.players[0].name === 'Mario Rossi', 'spazi normalizzati');
check(addPair(storage, 'I Fulmini', ids[0], ids[1]).ok, 'crea coppia');
check(!addPair(storage, 'Duplicata', ids[1], ids[0]).ok, 'no coppie invertite duplicate');
check(!addPair(storage, 'Non valida', ids[1], ids[1]).ok, 'no stesso giocatore');
check(!addPair(storage, 'Mancante', ids[0], 'missing').ok, 'no id inesistente');
check(addPair(storage, 'I Tigri', ids[2], ids[3]).ok, 'seconda coppia');
check(!removePlayer(storage, ids[0]).ok, 'non elimina giocatori usati in coppie');
check(renamePlayer(storage, ids[0], 'Mario Nuovo').ok, 'rinomina');
check(readPlayerDirectory(storage).pairs[0].playerIds[0] === ids[0], 'id coppia resta invariato');
check(!renamePlayer(storage, ids[0], 'Luigi Verdi').ok, 'rename duplicato bloccato');
const settings = {
  teamAName: 'I Fulmini', teamBName: 'I Tigri', player1Name: 'Mario Nuovo', player2Name: 'Luigi Verdi', player3Name: 'Paolo Bianchi', player4Name: 'Marco Neri',
  playerIds: ids, firstServerPlayerId: 1, isGoldenPoint: true, advantagesBeforeGoldenPoint: 0, bestOfSets: 1, gamesPerSet: 6, decidingMatchTieBreak: false, decidingTieBreakPoints: 10, ttsSpeed: 1, ttsVolume: 1, isVoiceMuted: false, isSfxMuted: false,
};
const store = new PadelMatchStore(settings);
check(saveCheckpoint(storage, settings, store.getState(), {matchId:'dir-checkpoint',matchSeconds:15,isTimerRunning:true,isSidesSwapped:false,breakSecondsLeft:0,isBreakActive:false,view:'scoreboard'}), 'checkpoint con ids');
check(loadCheckpoint(storage).settings.playerIds.join(',') === ids.join(','), 'ripristino degli ids');
for (let i = 0; i < 24; i++) store.addPoint('teamA');
check(archiveCompletedMatch(storage, 'dir-match', settings, store.getSnapshot(), 90) === 'saved', 'archivia partita');
const archived = loadMatchHistory(storage);
check(archived[0].playerIds.join(',') === ids.join(','), 'ids nello storico');
check(removePair(storage, readPlayerDirectory(storage).pairs[0].id).ok, 'elimina coppia');
check(removePlayer(storage, ids[0]).ok, 'elimina giocatore dopo coppia');
check(loadMatchHistory(storage)[0].players[0] === 'Mario Nuovo', 'nome nello storico immutato');
check(loadMatchHistory(storage)[0].playerIds[0] === ids[0], 'id storico immutato');
check(data.has(MATCH_HISTORY_KEY), 'storico separato dalla rubrica');
check(!addPlayer(storage, '').ok, 'nome vuoto vietato');
check(!addPlayer(storage, 'a'.repeat(61)).ok, 'nome troppo lungo vietato');
const snapshot = data.get(PLAYER_DIRECTORY_KEY);
data.set(PLAYER_DIRECTORY_KEY, '{corrotto');
check(readPlayerDirectory(storage) === null, 'dati corrotti riconosciuti');
check(!addPlayer(storage, 'Nuovo').ok, 'nessuna sovrascrittura dati corrotti');
check(data.get(PLAYER_DIRECTORY_KEY) === '{corrotto', 'dato corrotto preservato');
data.set(PLAYER_DIRECTORY_KEY, snapshot);
const denied = {...storage, setItem: () => { throw Error('quota'); }};
check(!addPlayer(denied, 'Nuovo').ok, 'memoria piena gestita');
check(MAX_PLAYERS >= 100, 'limite previsto');
const legacy = JSON.parse(data.get(MATCH_HISTORY_KEY));
delete legacy[0].playerIds;
data.set(MATCH_HISTORY_KEY, JSON.stringify(legacy));
check(loadMatchHistory(storage).length === 1, 'storico legacy continua a funzionare');
console.log(`OK ${checks} verifiche anagrafica giocatori/coppie React`);
