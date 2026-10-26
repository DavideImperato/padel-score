// Fase 2B.4C - prove sul motore reale per i tie-break decisivi FIP a 7 o 10 punti.
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
let checks = 0;
const expect = (actual, expected, description) => {
  assert.deepStrictEqual(actual, expected, description);
  checks++;
};
function makeStore(target, bestOfSets = 3) {
  return new PadelMatchStore({
    teamAName:'A', teamBName:'B', player1Name:'A1', player2Name:'A2',
    player3Name:'B1', player4Name:'B2', firstServerPlayerId:1,
    isGoldenPoint:true, advantagesBeforeGoldenPoint:0, bestOfSets,
    gamesPerSet:6, decidingMatchTieBreak:true, decidingTieBreakPoints:target,
    ttsSpeed:1, ttsVolume:1, isVoiceMuted:true, isSfxMuted:true,
  });
}
function sweepSet(store, winner) {
  for(let game=0;game<6;game++) for(let point=0;point<4;point++) store.addPoint(winner);
}
function toDecider(target, bestOfSets=3) {
  const s=makeStore(target,bestOfSets);
  const winners=bestOfSets===5 ? ['teamA','teamB','teamA','teamB'] : ['teamA','teamB'];
  for(const winner of winners) sweepSet(s,winner);
  expect(s.getSnapshot().isMatchTieBreak,true,'starts match tiebreak');
  return s;
}
for(const bestOfSets of [3,5]) {
  for(const target of [7,10]) {
    const s=toDecider(target,bestOfSets);
    for(let i=0;i<target-2;i++) s.addPoint('teamA');
    for(let i=0;i<target-2;i++) s.addPoint('teamB');
    expect(s.getSnapshot().matchWinner,undefined,`${target}: ${target-2} equal continues`);
    s.addPoint('teamA');
    expect(s.getSnapshot().matchWinner,undefined,`${target}: penultimate A point`);
    s.addPoint('teamA');
    expect(s.getSnapshot().matchWinner,'teamA',`${target}-${target-2} finishes`);
    const last=s.getSnapshot().completedSets.at(-1);
    expect(last.isMatchTieBreak,true,'decider labelled');
    expect([last.tieBreakPointsA,last.tieBreakPointsB],[target,target-2],'decider points stored');
    expect([last.gamesA,last.gamesB],[0,0],'no ghost game');
    expect(s.addPoint('teamB'),null,'no score after match complete');
    s.undo();
    expect(s.getSnapshot().matchWinner,undefined,'undo reopens match');
    expect(s.getSnapshot().isMatchTieBreak,true,'undo returns to match TB');
    s.addPoint('teamA');
    expect(s.getSnapshot().matchWinner,'teamA','point after undo finishes');
  }
}
for(const target of [7,10]) {
  const s=toDecider(target);
  for(let i=0;i<target-1;i++) { s.addPoint('teamA'); s.addPoint('teamB'); }
  expect(s.getSnapshot().matchWinner,undefined,`${target-1} all continues`);
  s.addPoint('teamA');
  expect(s.getSnapshot().matchWinner,undefined,`${target}-${target-1} continues`);
  s.addPoint('teamA');
  expect(s.getSnapshot().matchWinner,'teamA',`${target+1}-${target-1} wins by two`);
}
{
  const s=makeStore(undefined);
  sweepSet(s,'teamA'); sweepSet(s,'teamB');
  for(let i=0;i<7;i++) s.addPoint('teamA');
  expect(s.getSnapshot().matchWinner,undefined,'backward compatibility: 7 points alone do not finish default 10');
  for(let i=0;i<3;i++) s.addPoint('teamA');
  expect(s.getSnapshot().matchWinner,'teamA','backward compatibility: default 10 ends');
}
console.log(`OK tie-break decisivi 7/10: ${checks} verifiche sul motore React`);
