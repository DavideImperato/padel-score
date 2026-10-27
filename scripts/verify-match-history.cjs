// Verifica archivio offline React senza browser e senza dipendenze UI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { ts = require('typescript'); }
Module._extensions['.ts'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  module._compile(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    fileName: filename,
  }).outputText, filename);
};
const { PadelMatchStore } = require('../src/engine/padelMatchStore.ts');
const { MATCH_HISTORY_KEY, loadMatchHistory, archiveCompletedMatch, removeArchivedMatch, MAX_ARCHIVED_MATCHES } = require('../src/engine/matchHistory.ts');
const { saveCheckpoint, loadCheckpoint, CHECKPOINT_KEY } = require('../src/engine/matchPersistence.ts');
const settings = {
  teamAName: 'Squadra A', teamBName: 'Squadra B',
  player1Name: 'A1', player2Name: 'A2', player3Name: 'B1', player4Name: 'B2',
  firstServerPlayerId: 1, isGoldenPoint: true, advantagesBeforeGoldenPoint: 0,
  bestOfSets: 1, gamesPerSet: 6, decidingMatchTieBreak: false,
  decidingTieBreakPoints: 10, ttsSpeed: 1, ttsVolume: 1,
  isVoiceMuted: false, isSfxMuted: false,
};
const map = new Map();
const storage = { getItem: k => map.get(k) ?? null,
  setItem: (k, v) => map.set(k, v), removeItem: k => map.delete(k) };
let checks = 0;
const ok = (c, message) => { assert.ok(c, message); checks++; };
const store = new PadelMatchStore(settings);
ok(archiveCompletedMatch(storage, 'match-1', settings, store.getSnapshot(), 100) === 'notFinished', 'non archivia in corso');
for (let i = 0; i < 24; i++) store.addPoint('teamA');
ok(store.getSnapshot().matchWinner === 'teamA', 'winner');
ok(store.getSnapshot().completedSets.length === 1, 'set completato');
ok(archiveCompletedMatch(storage, 'match-1', settings, store.getSnapshot(), 143, 1600000000000) === 'saved', 'salvataggio');
let items = loadMatchHistory(storage);
ok(items.length === 1, 'prima voce');
ok(items[0].winner === 'teamA', 'vincitore');
ok(items[0].durationSeconds === 143, 'durata');
ok(items[0].sets[0].gamesA === 6 && items[0].sets[0].gamesB === 0, 'risultato set');
ok(items[0].players.join(',') === 'A1,A2,B1,B2', 'giocatori');
ok(archiveCompletedMatch(storage, 'match-1', settings, store.getSnapshot(), 199) === 'exists', 'idempotente');
ok(loadMatchHistory(storage).length === 1, 'nessun duplicato');
ok(saveCheckpoint(storage, settings, store.getState(), { matchId: 'match-1', matchSeconds: 143, isTimerRunning: false,
  isSidesSwapped: false, breakSecondsLeft: 0, isBreakActive: false, view: 'summary' }), 'checkpoint');
ok(loadCheckpoint(storage).runtime.matchId === 'match-1', 'matchId recuperato');
ok(map.has(CHECKPOINT_KEY) && map.has(MATCH_HISTORY_KEY), 'archivio separato dal checkpoint');
ok(removeArchivedMatch(storage, 'match-1'), 'elimina');
ok(loadMatchHistory(storage).length === 0, 'storico vuoto');
ok(map.has(CHECKPOINT_KEY), 'checkpoint non toccato dall eliminazione');
ok(!removeArchivedMatch(storage, 'non-esiste'), 'eliminazione inesistente');
map.set(MATCH_HISTORY_KEY, '{broken');
ok(loadMatchHistory(storage).length === 0, 'non espone dati rotti');
ok(archiveCompletedMatch(storage, 'match-2', settings, store.getSnapshot(), 10) === 'unavailable', 'no overwrite storico corrotto');
ok(map.get(MATCH_HISTORY_KEY) === '{broken', 'preserva archivio corrotto');
map.delete(MATCH_HISTORY_KEY);
const storageError = { ...storage, setItem: () => { throw new Error('quota exceeded'); } };
ok(archiveCompletedMatch(storageError, 'new', settings, store.getSnapshot(), 10) === 'unavailable', 'quota error');
ok(MAX_ARCHIVED_MATCHES >= 100, 'limite documentato');
console.log(`OK ${checks} verifiche storico partite React`);
