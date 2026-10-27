// Test del checkpoint offline React, indipendente da browser e React.
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
const { CHECKPOINT_KEY, loadCheckpoint, saveCheckpoint, clearCheckpoint, decodeCheckpoint } = require('../src/engine/matchPersistence.ts');
const settings = {
  teamAName: 'A', teamBName: 'B', player1Name: 'A1', player2Name: 'A2',
  player3Name: 'B1', player4Name: 'B2', firstServerPlayerId: 2,
  isGoldenPoint: true, advantagesBeforeGoldenPoint: 0,
  bestOfSets: 3, gamesPerSet: 4, decidingMatchTieBreak: true,
  decidingTieBreakPoints: 7, isVoiceMuted: true, isSfxMuted: true,
  ttsSpeed: 1, ttsVolume: 1,
};
const runtime = { matchSeconds: 137, isTimerRunning: false, isSidesSwapped: true,
  breakSecondsLeft: 29, isBreakActive: true, view: 'scoreboard' };
const map = new Map();
const storage = { getItem: k => map.get(k) ?? null,
  setItem: (k, v) => {map.set(k,v);}, removeItem: k => {map.delete(k);} };
let checks = 0;
function ok(condition, label) { assert.ok(condition, label); checks++; }
const store = new PadelMatchStore(settings);
for(let i=0; i<12; i++) store.addPoint(i % 3 === 0 ? 'teamB' : 'teamA');
store.toggleServingTeam();
ok(saveCheckpoint(storage, store.getSettings(), store.getState(), runtime), 'salva');
const old = loadCheckpoint(storage);
ok(old !== null, 'legge');
ok(old.settings.firstServerPlayerId === 2 && old.settings.gamesPerSet === 4 && old.settings.decidingTieBreakPoints === 7, 'regole');
ok(old.state.history.length === 13, 'cronologia undo');
ok(old.runtime.matchSeconds === 137 && old.runtime.isSidesSwapped && old.runtime.breakSecondsLeft === 29, 'tempo e cambio campo');
const restored = new PadelMatchStore(settings);
restored.restoreMatch(old.settings, old.state);
ok(JSON.stringify(restored.getSnapshot()) === JSON.stringify(store.getSnapshot()), 'snapshot e servizio');
ok(JSON.stringify(restored.getHistory()) === JSON.stringify(store.getHistory()), 'cronologia');
restored.undo();
ok(restored.getHistory().length === 12, 'undo dopo ripresa');
restored.addPoint('teamA');
ok(restored.getHistory().length === 13, 'prosegue con nuovi punti');
map.set(CHECKPOINT_KEY, '{broken json');
ok(loadCheckpoint(storage) === null, 'json corrotto');
map.set(CHECKPOINT_KEY, JSON.stringify({...old, version:99}));
ok(loadCheckpoint(storage) === null, 'versione futura');
map.set(CHECKPOINT_KEY, JSON.stringify({...old, state: {...old.state, snapshot:{...old.state.snapshot, rawPointsA:-2}}}));
ok(loadCheckpoint(storage) === null, 'punteggio invalido');
map.set(CHECKPOINT_KEY, JSON.stringify(old));
clearCheckpoint(storage);
ok(loadCheckpoint(storage) === null, 'scarta');
ok(decodeCheckpoint('null') === null, 'valore null');
console.log(`OK ${checks} verifiche checkpoint React offline`);
