const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { try { ts = require('typescript'); } catch { ts = require(require.resolve('typescript', {paths:['/opt/nvm/versions/node/v22.16.0/lib/node_modules']})); } }
Module._extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: filename, compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020},
}).outputText, filename);
const {filterFinishedMatches, filterInterruptedMatches, exportHistoryCsv, EMPTY_HISTORY_FILTERS} = require('../src/engine/matchHistoryAdvanced.ts');
const directory = {version: 1, players:[
  {id:'p1',name:'Giorgio', createdAt: 1},{id:'p2',name:'Elena', createdAt:1},
  {id:'p3',name:'Luca', createdAt: 1},{id:'p4',name:'Anna',createdAt:1},
], pairs:[{id:'pair1',name:'Coppia vincente',playerIds:['p2','p1'],createdAt:1},{id:'pair2',name:'Avversari',playerIds:['p3','p4'],createdAt:1}]};
const now = (day, hour=14) => new Date(2026, 9, day, hour).getTime();
const make = (id, day, playerIds=['p1','p2','p3','p4']) => ({version:1,id,completedAt:now(day),durationSeconds:100,
  teamAName:'Rossi',teamBName:'Blu',players:['Mario','Èlena','Luca','Anna'],playerIds,winner:'teamA',
  sets:[{gamesA:6,gamesB:4,isCompleted:true,winner:'teamA'}],bestOfSets:1,gamesPerSet:6});
const finished = [make('a', 20),make('b', 26, ['p3','p1','p2','p4']), {...make('c',25),playerIds:undefined,players:['Mario','Anna','Luca','Sofia']}];
const checkpoint = {settings:{teamAName:'Rossi',teamBName:'Blu',player1Name:'Mario',player2Name:'Èlena',player3Name:'Luca',player4Name:'Anna',playerIds:['p1','p2','p3','p4']},
 state:{snapshot:{completedSets:[],isTieBreak:false,currentGamesA:1,currentGamesB:2}},runtime:{matchSeconds:120}};
const interrupted = [{id:'x',interruptedAt:now(21),checkpoint}];
let n=0; const ok=(condition, title)=>{assert.ok(condition,title);n++;};
const f = (over={})=>({...EMPTY_HISTORY_FILTERS,...over});
ok(filterFinishedMatches(finished,f(),directory).length===3,'no filters');
ok(filterFinishedMatches(finished,f({query:'rossi'}),directory).length===3,'search team');
ok(filterFinishedMatches(finished,f({query:'ELENA'}),directory).length===2,'find current name linked ids');
ok(filterFinishedMatches(finished,f({query:'sofia'}),directory).length===1,'old manually typed names searchable');
ok(filterFinishedMatches(finished,f({query:'Élena'}),directory).length===2,'accent search');
ok(filterFinishedMatches(finished,f({playerId:'p1'}),directory).length===2,'filter by id');
ok(filterFinishedMatches(finished,f({playerId:'p2'}),directory).length===2,'filter by id2');
ok(filterFinishedMatches(finished,f({pairId:'pair1'}),directory).map(x=>x.id).join(',')==='a','pair both on same team');
ok(filterFinishedMatches(finished,f({pairId:'pair2'}),directory).map(x=>x.id).join(',')==='a','pair other team');
ok(filterFinishedMatches(finished,f({pairId:'unknown'}),directory).length===0,'unknown pair');
ok(filterFinishedMatches(finished,f({fromDate:'2026-10-21'}),directory).length===2,'from inclusive');
ok(filterFinishedMatches(finished,f({toDate:'2026-10-20'}),directory).length===1,'to inclusive');
ok(filterFinishedMatches(finished,f({fromDate:'2026-10-25',toDate:'2026-10-25'}),directory).length===1,'single day');
ok(filterFinishedMatches(finished,f({fromDate:'2026-02-31'}),directory).length===0,'invalid calendar day');
ok(filterFinishedMatches(finished,f({fromDate:'2026-10-27',toDate:'2026-10-21'}),directory).length===0,'invalid range');
ok(filterFinishedMatches(finished,f({query:'nomatch'}),directory).length===0,'no match');
ok(filterInterruptedMatches(interrupted,f(),directory).length===1,'interrupted shown');
ok(filterInterruptedMatches(interrupted,f({query:'giorgio'}),directory).length===1,'interrupted current name');
ok(filterInterruptedMatches(interrupted,f({pairId:'pair1'}),directory).length===1,'interrupted pair');
ok(filterInterruptedMatches(interrupted,f({toDate:'2026-10-20'}),directory).length===0,'interrupted date');
ok(filterInterruptedMatches(interrupted,f({playerId:'unknown'}),directory).length===0,'interrupted player');
const csv = exportHistoryCsv([finished[0]],interrupted);
ok(csv.charCodeAt(0)===0xfeff,'utf8 bom');
ok(csv.includes('"Conclusa"')&&csv.includes('"Interrotta"'),'both states');
ok(csv.split('\r\n').filter(Boolean).length===3,'rows');
ok(csv.includes('"In corso 1-2"'),'interrupted partial score');
ok(csv.includes('"6-4"'),'completed set score');
const injection=exportHistoryCsv([{...finished[0],teamAName:'=2+3',players:['+cmd','-cmd','@SUM(A1)','safe;"x"']}]);
ok(injection.includes('"\'=2+3"')&&injection.includes('"\'+cmd"'),'formula injection guarded');
ok(injection.includes('"safe;""x"""'),'escape delimiters');
ok(finished[0].teamAName==='Rossi','export non-mutating');
console.log(`OK ${n} verifiche storico avanzato React`);
