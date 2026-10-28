// Fase 5D web: test senza browser, con compilatore TypeScript CJS per il motore puro.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const { execFileSync } = require('node:child_process');
let ts;
for (const name of ['@typescript/typescript6', 'typescript']) {
  try { ts = require(name); if (ts.transpileModule && ts.ModuleKind) break; } catch (_) {}
}
if (!ts || !ts.transpileModule || !ts.ModuleKind) {
  ts = require(require('node:path').join(execFileSync('npm', ['root', '-g'], {encoding:'utf8'}).trim(), 'typescript'));
}
Module._extensions['.ts'] = (mod, file) => {
  const source = fs.readFileSync(file, 'utf8');
  mod._compile(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022,
  }, fileName: file }).outputText, file);
};
const { PadelMatchStore } = require('../src/engine/padelMatchStore.ts');
const { decodePointEvents, calculatePointAnalytics, MAX_POINT_EVENTS } = require('../src/engine/matchPointAnalytics.ts');
const { saveCheckpoint, loadCheckpoint } = require('../src/engine/matchPersistence.ts');
const { archiveCompletedMatch, loadMatchHistory, MATCH_HISTORY_KEY } = require('../src/engine/matchHistory.ts');
const settings = {
  teamAName:'A', teamBName:'B', player1Name:'A1', player2Name:'A2', player3Name:'B1', player4Name:'B2',
  firstServerPlayerId:1, isGoldenPoint:true, advantagesBeforeGoldenPoint:0,
  bestOfSets:1, gamesPerSet:6, ttsSpeed:1, ttsVolume:1, isVoiceMuted:false, isSfxMuted:false,
};
const mem = new Map();
const storage = { getItem: key => mem.get(key) ?? null, setItem: (key,value)=>mem.set(key,value),removeItem:key=>mem.delete(key) };
const runtime = { matchSeconds:14, isTimerRunning:true, isSidesSwapped:false, breakSecondsLeft:0, isBreakActive:false, view:'scoreboard', matchId:'web-stats-test' };
let checks=0; const ok=(condition,message)=>{assert.ok(condition,message);checks++;};
const store = new PadelMatchStore(settings);
store.addPoint('teamA',1); store.addPoint('teamB',2); store.addPoint('teamA',3);
ok(store.getState().pointEvents.length===3,'3 eventi');
ok(store.getState().pointEvents[0].index===1,'indice stabile');
ok(store.getState().pointEvents[0].serverPlayerId===1,'server iniziale');
ok(store.getState().pointEvents[0].beforeA==='0' && store.getState().pointEvents[0].afterA==='15','punto 0-15');
ok(store.getState().pointEvents[2].elapsedSeconds===3,'tempo evento');
let data=calculatePointAnalytics(store.getState().pointEvents);
ok(data.pointsA===2 && data.pointsB===1,'conteggio');
ok(data.longestStreakA===1 && data.longestStreakB===1,'serie consecutive');
ok(data.timeline.length===4 && data.timeline.at(-1).a===2,'grafico progressione');
store.undo(); ok(store.getState().pointEvents.length===2 && store.getSnapshot().rawPointsA===1,'undo punto rimuove evento');
store.toggleServingTeam();
ok(store.getState().pointEvents.length===2,'cambio battitore non aggiunge evento');
store.undo(); ok(store.getState().pointEvents.length===2,'undo cambio battitore non tocca punti');
store.addPoint('teamB',5);
ok(store.getState().pointEvents.at(-1).index===3,'riassegnazione indicizza bene');
ok(store.getState().pointEvents.at(-1).elapsedSeconds===5,'tempo non regredisce');
ok(saveCheckpoint(storage,settings,store.getState(),runtime),'salvataggio');
const checkpoint=loadCheckpoint(storage); ok(!!checkpoint && checkpoint.state.pointEvents.length===3,'recupero eventi');
const restore=new PadelMatchStore(settings);restore.restoreMatch(checkpoint.settings,checkpoint.state);
ok(restore.getState().pointTrackingComplete===true && restore.getState().pointEvents.length===3,'restore completo');
restore.undo();ok(restore.getState().pointEvents.length===2,'undo dopo restore');
const legacyStore={snapshot:store.getSnapshot(),history:store.getHistory()};
restore.restoreMatch(settings,legacyStore);
ok(restore.getState().pointTrackingComplete===false,'checkpoint precedente non ricostruisce gli eventi');
restore.addPoint('teamA',7);ok(restore.getState().pointEvents.length===0,'nessuna cronologia parziale');
ok(decodePointEvents([{index:2}])===null,'rifiuta eventi malformati');
ok(decodePointEvents(new Array(MAX_POINT_EVENTS+1).fill({}))===null,'limite eventi');
ok(calculatePointAnalytics(undefined)===null,'analytics legacy assente');
const end=new PadelMatchStore(settings);for (let i=0;i<24;i++) end.addPoint('teamA',i);
ok(end.getSnapshot().matchWinner==='teamA','match concluso');
ok(end.getState().pointEvents.length===24,'punti completi');
ok(end.getState().pointEvents.at(-1).matchWon,'ultimo punto vincente');
ok(end.getState().pointEvents.at(-1).gameWon,'ultimo punto chiude game');
ok(archiveCompletedMatch(storage,'finished',settings,end.getSnapshot(),145,Date.now(),end.getState().pointEvents)==='saved','archivio registra eventi');
const saved=loadMatchHistory(storage);ok(saved[0].pointEvents.length===24,'lettura eventi nello storico');
ok(calculatePointAnalytics(saved[0].pointEvents).pointsA===24,'analytics storico');
ok(archiveCompletedMatch(storage,'finished',settings,end.getSnapshot(),190,Date.now(),[])==='exists','idempotenza');
const before=mem.get(MATCH_HISTORY_KEY);mem.set(MATCH_HISTORY_KEY,'[{"version":1,"id":"bad","pointEvents":[{"index":5}]}]');
ok(archiveCompletedMatch(storage,'other',settings,end.getSnapshot(),0,Date.now(),end.getState().pointEvents)==='unavailable','archivio corrotto non sovrascritto');
mem.set(MATCH_HISTORY_KEY,before);
const gold=new PadelMatchStore(settings);for(let i=0;i<3;i++){gold.addPoint('teamA');gold.addPoint('teamB');}
gold.addPoint('teamA');
ok(gold.getState().pointEvents.at(-1).isGoldenPoint,'rileva punto d oro');
ok(calculatePointAnalytics(gold.getState().pointEvents).goldenPointsA===1,'statistica punto d oro');

// Tie-break a 7: 4-4 nei mini-set, ultimo punto 7-5 e Undo della chiusura.
const mini = new PadelMatchStore({...settings, gamesPerSet:4});
for(let g=0;g<4;g++){for(let i=0;i<4;i++)mini.addPoint('teamA');for(let i=0;i<4;i++)mini.addPoint('teamB');}
ok(mini.getSnapshot().isTieBreak===true,'tie-break mini set a 4-4');
for(let i=0;i<6;i++)mini.addPoint('teamA');
for(let i=0;i<5;i++)mini.addPoint('teamB');
ok(mini.getState().pointEvents.at(-1).isTieBreak,'eventi tie-break');
mini.addPoint('teamA');
ok(mini.getSnapshot().matchWinner==='teamA','chiusura tie-break 7-5');
ok(mini.getState().pointEvents.at(-1).setWon,'ultimo punto segna set');
const miniStats=calculatePointAnalytics(mini.getState().pointEvents);
ok(miniStats.tieBreakPointsA===7 && miniStats.tieBreakPointsB===5,'statistiche tie-break corrette');
mini.undo();
ok(mini.getSnapshot().matchWinner===undefined,'undo della vittoria');
ok(mini.getState().pointEvents.at(-1).matchWon===false,'rimosso evento di vittoria');

console.log(`OK ${checks} verifiche Fase 5D web (punti, Undo, checkpoint, storico, oro, compatibilita)`)
