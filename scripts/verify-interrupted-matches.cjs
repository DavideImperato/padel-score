const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { ts = require('typescript'); }
Module._extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }, fileName: filename,
  }).outputText, filename);
};
const { PadelMatchStore } = require('../src/engine/padelMatchStore.ts');
const { archiveInterruptedMatch, loadInterruptedMatches, findInterruptedMatch, removeInterruptedMatch, INTERRUPTED_MATCHES_KEY, MAX_INTERRUPTED_MATCHES } = require('../src/engine/matchInterrupted.ts');
const { saveCheckpoint, loadCheckpoint, clearCheckpoint, CHECKPOINT_KEY } = require('../src/engine/matchPersistence.ts');
const { loadMatchHistory } = require('../src/engine/matchHistory.ts');
const settings = {
  teamAName: 'Team A', teamBName: 'Team B', player1Name: 'A1', player2Name: 'A2', player3Name: 'B1', player4Name: 'B2',
  firstServerPlayerId: 1, isGoldenPoint: true, advantagesBeforeGoldenPoint: 0,
  bestOfSets: 1, gamesPerSet: 6, decidingMatchTieBreak: false, decidingTieBreakPoints: 10,
};
const data = new Map();
const storage = { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value), removeItem: key => data.delete(key) };
const state = new PadelMatchStore(settings);
let checks = 0;
const check = (condition, label) => { assert.ok(condition, label); checks++; };
const runtime = id => ({ matchId: id, matchSeconds: 121, isTimerRunning: true, isSidesSwapped: false, breakSecondsLeft: 0, isBreakActive: false, view: 'scoreboard' });
state.addPoint('teamA'); state.addPoint('teamB');
const snapshot = state.getState();
check(saveCheckpoint(storage, settings, snapshot, runtime('one')), 'active checkpoint saved');
const first = loadCheckpoint(storage);
check(archiveInterruptedMatch(storage, first) === 'saved', 'archive');
check(loadInterruptedMatches(storage).length === 1, 'one interrupted');
check(findInterruptedMatch(storage, 'one').checkpoint.state.history.length === 2, 'undo history preserved');
check(findInterruptedMatch(storage, 'one').checkpoint.runtime.isTimerRunning === false, 'clock paused on archive');
check(findInterruptedMatch(storage, 'one').checkpoint.state.snapshot.matchWinner === undefined, 'unfinished match');
check(loadMatchHistory(storage).length === 0, 'completed archive unchanged');
check(archiveInterruptedMatch(storage, first) === 'exists', 'duplicate prevented');
clearCheckpoint(storage);
check(!data.has(CHECKPOINT_KEY), 'active checkpoint independent');
check(saveCheckpoint(storage, settings, snapshot, runtime('two')), 'second checkpoint');
check(archiveInterruptedMatch(storage, loadCheckpoint(storage)) === 'saved', 'second archived');
check(loadInterruptedMatches(storage).length === 2, 'multiple matches stored');
check(removeInterruptedMatch(storage, 'one'), 'removed by id');
check(!findInterruptedMatch(storage, 'one') && !!findInterruptedMatch(storage, 'two'), 'other match remains');
const resume = findInterruptedMatch(storage, 'two').checkpoint;
check(saveCheckpoint(storage, resume.settings, resume.state, resume.runtime), 'resume checkpoint persisted');
const restored = new PadelMatchStore(settings);
restored.restoreMatch(resume.settings, resume.state);
check(restored.getState().history.length === 2, 'Undo preserved after resuming');
check(restored.undo() !== null, 'Undo after restore');
check(removeInterruptedMatch(storage, 'two') && !loadInterruptedMatches(storage).length, 'remove after resume');
const won = new PadelMatchStore(settings);
for (let i=0;i<24;i++) won.addPoint('teamA');
check(won.getSnapshot().matchWinner === 'teamA', 'match finished');
check(archiveInterruptedMatch(storage, { ...first, state: won.getState() }) === 'unavailable', 'winner cannot be interrupted');
data.set(INTERRUPTED_MATCHES_KEY, '{invalid');
check(loadInterruptedMatches(storage).length === 0, 'invalid archive not exposed');
check(archiveInterruptedMatch(storage, first) === 'unavailable', 'invalid archive not overwritten');
check(data.get(INTERRUPTED_MATCHES_KEY) === '{invalid', 'corrupt bytes preserved');
data.delete(INTERRUPTED_MATCHES_KEY);
const failing = { ...storage, setItem: () => { throw new Error('quota'); } };
check(archiveInterruptedMatch(failing, first) === 'unavailable', 'quota exception safe');
check(MAX_INTERRUPTED_MATCHES > 0, 'documented limit');
console.log(`OK ${checks} verifiche archivio partite interrotte React`);
