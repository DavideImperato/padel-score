// Fase 2B.4B: verifica indipendente del motore reale, senza interfaccia React.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { ts = require('typescript'); }
Module._extensions['.ts'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
    fileName: filename,
  });
  module._compile(compiled.outputText, filename);
};
const { PadelMatchStore } = require('../src/engine/padelMatchStore.ts');
const { getCurrentServerPlayerId, getRotationOrder } = require('../src/engine/padelScoringEngine.ts');
let assertions = 0;
const check = (value, expected, message) => {
  assert.deepEqual(value, expected, message);
  assertions++;
};
const setup = (bestOfSets = 3, decidingMatchTieBreak = true, firstServerPlayerId = 1) =>
  new PadelMatchStore({
    teamAName: 'A', teamBName: 'B', player1Name: 'A1', player2Name: 'A2',
    player3Name: 'B1', player4Name: 'B2', firstServerPlayerId,
    isGoldenPoint: true, advantagesBeforeGoldenPoint: 0,
    bestOfSets, gamesPerSet: 6, decidingMatchTieBreak,
    ttsSpeed: 1, ttsVolume: 1, isVoiceMuted: true, isSfxMuted: true,
  });
const setSixZero = (store, winner) => {
  for (let game = 0; game < 6; game++) {
    for (let point = 0; point < 4; point++) store.addPoint(winner);
  }
};
const startAtTieBreak = (sets = 3, enabled = true) => {
  const store = setup(sets, enabled);
  const winners = sets === 5 ? ['teamA','teamB','teamA','teamB'] : ['teamA','teamB'];
  for (const winner of winners) setSixZero(store, winner);
  return store;
};
for (const sets of [3, 5]) {
  const store = startAtTieBreak(sets);
  check(store.getSnapshot().isTieBreak, true, 'match TB starts at tied sets');
  check(store.getSnapshot().isMatchTieBreak, true, '10-point flag on');
  check(store.getSnapshot().completedSets.length, sets - 1, 'sets played');
  const initial = store.getSnapshot();
  const order = getRotationOrder(1);
  const initialRot = initial.tieBreakInitialRotationIndex;
  check(getCurrentServerPlayerId(initial, 1), order[initialRot % 4], 'initial server');
  store.addPoint('teamA');
  check(getCurrentServerPlayerId(store.getSnapshot(), 1), order[(initialRot + 1) % 4], 'next server after first point');
  store.addPoint('teamB');
  check(getCurrentServerPlayerId(store.getSnapshot(), 1), order[(initialRot + 1) % 4], 'same server on third point');
  store.undo(); store.undo();
  check(store.getSnapshot().tieBreakPointsA, 0, 'undo first point');
  check(store.getSnapshot().tieBreakPointsB, 0, 'undo second point');
  for (let i=0;i<9;i++) store.addPoint('teamA');
  for (let i=0;i<8;i++) store.addPoint('teamB');
  check(store.getSnapshot().matchWinner, undefined, '9-8 not finished');
  store.addPoint('teamA');
  check(store.getSnapshot().matchWinner, 'teamA', '10-8 wins');
  check(store.getSnapshot().completedSets.length, sets, 'decider counts as set');
  const result = store.getSnapshot().completedSets.at(-1);
  check(result.isMatchTieBreak, true, 'match decider labelled');
  check([result.gamesA,result.gamesB], [0,0], 'no fictitious games');
  check([result.tieBreakPointsA,result.tieBreakPointsB], [10,8], 'real points recorded');
  check(store.addPoint('teamB'), null, 'post-win point blocked');
  store.undo();
  check(store.getSnapshot().matchWinner, undefined, 'undo win restores match');
  check(store.getSnapshot().isMatchTieBreak, true, 'undo win restores deciding TB');
  store.addPoint('teamA');
  check(store.getSnapshot().matchWinner, 'teamA', 'point after undo wins');
}
// Il pareggio 9-9 richiede due punti di vantaggio.
{
  const store = startAtTieBreak();
  for (let i=0;i<9;i++) { store.addPoint('teamA'); store.addPoint('teamB'); }
  check(store.getSnapshot().matchWinner, undefined, '9-9 continues');
  store.addPoint('teamA');
  check(store.getSnapshot().matchWinner, undefined, '10-9 continues');
  store.addPoint('teamA');
  check(store.getSnapshot().matchWinner, 'teamA', '11-9 wins');
}
// Configurazione disattivata: terzo set regolare; al meglio di 1 disabilitato.
{
  const a = startAtTieBreak(3, false);
  check(a.getSnapshot().isMatchTieBreak, false, 'disabled mode preserves regular third set');
  check(a.getSnapshot().isTieBreak, false, 'regular third set starts at 0-0');
  const b = setup(1, true);
  setSixZero(b, 'teamA');
  check(b.getSnapshot().matchWinner, 'teamA', 'best of one ends normally');
}
console.log(`OK match tie-break React: ${assertions} verifiche superate`);
