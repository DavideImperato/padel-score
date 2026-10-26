// Fase 2B.3B: scenari condivisi fra il motore TypeScript e il provider Flutter.
// Prima generazione intenzionale: node scripts/verify-scoring-parity.cjs --update-fixtures
// Verifica regolare: node scripts/verify-scoring-parity.cjs
// Il file JSON va versionato: NON rigenerarlo automaticamente durante i test.
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('@typescript/typescript6');

const root = path.resolve(__dirname, '..');
const fixturePath = path.join(root, 'test/fixtures/scoring_parity_cases.json');
const mirrorPath = path.join(root, 'flutter_project/test/fixtures/scoring_parity_cases.json');

// Il package React è ESM, ma il motore non dipende dal DOM: compila solo il
// modulo puro in CommonJS per poterlo eseguire in Node senza Vite o Flutter.
Module._extensions['.ts'] = (module, filename) => {
  const transpiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: filename,
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2020,
    },
  });
  module._compile(transpiled.outputText, filename);
};
const { processPoint, createInitialSnapshot, getCurrentServerPlayerId } =
  require('../src/engine/padelScoringEngine.ts');

const makeGame = (team) => Array(4).fill(team);
const makeGames = (teams) => teams.flatMap(makeGame);
const definitions = [
  {
    id: 'golden-point-undo',
    firstServerPlayerId: 1, goldenPoint: true, advantages: 0, bestOfSets: 3,
    actions: [...Array(3).fill('A'), ...Array(3).fill('B'), 'B', 'U', 'A', ...makeGame('B')],
  },
  {
    id: 'star-point-and-undo',
    firstServerPlayerId: 2, goldenPoint: true, advantages: 2, bestOfSets: 3,
    actions: [...Array(3).fill('A'), ...Array(3).fill('B'), 'A', 'B', 'B', 'A', 'B', 'U', 'B'],
  },
  {
    id: 'traditional-advantages',
    firstServerPlayerId: 3, goldenPoint: false, advantages: 0, bestOfSets: 3,
    actions: [...Array(3).fill('A'), ...Array(3).fill('B'), 'B', 'A', 'B', 'B'],
  },
  {
    id: 'set-six-four',
    firstServerPlayerId: 1, goldenPoint: true, advantages: 0, bestOfSets: 3,
    actions: makeGames(['A','B','A','B','A','B','A','B','A','A']),
  },
  {
    id: 'set-six-three',
    firstServerPlayerId: 4, goldenPoint: true, advantages: 0, bestOfSets: 3,
    actions: makeGames(['A','B','A','B','A','B','A','A','A']),
  },
  {
    id: 'tie-break-eight-six',
    firstServerPlayerId: 3, goldenPoint: true, advantages: 0, bestOfSets: 3,
    actions: [...makeGames(['A','B','A','B','A','B','A','B','A','B','A','B']),
      ...Array(6).fill(['A','B']).flat(), 'A', 'A', 'U', 'A'],
  },
  {
    id: 'mini-set-four-two',
    firstServerPlayerId: 1, goldenPoint: true, advantages: 0, bestOfSets: 3, shortSets: true,
    actions: makeGames(['A','B','A','B','A','A']),
  },
  {
    id: 'mini-set-five-three-and-undo',
    firstServerPlayerId: 2, goldenPoint: true, advantages: 0, bestOfSets: 3, shortSets: true,
    actions: [...makeGames(['A','B','A','B','A','B','A','A']), 'U', 'A'],
  },
  {
    id: 'mini-set-tiebreak-five-four',
    firstServerPlayerId: 3, goldenPoint: true, advantages: 0, bestOfSets: 3, shortSets: true,
    actions: [...makeGames(['A','B','A','B','A','B','A','B']),
      ...Array(5).fill(['A','B']).flat(), 'A', 'A'],
  },
  {
    id: 'finished-match-undo',
    firstServerPlayerId: 4, goldenPoint: true, advantages: 0, bestOfSets: 1,
    actions: [...makeGames(['B','B','B','B','B','B']), 'A', 'U', 'B'],
  },
];

function stateOf(snapshot, firstServerPlayerId) {
  return {
    rawPointsA: snapshot.rawPointsA,
    rawPointsB: snapshot.rawPointsB,
    deuceCount: snapshot.deuceCount ?? 0,
    currentGamesA: snapshot.currentGamesA,
    currentGamesB: snapshot.currentGamesB,
    servingTeam: snapshot.servingTeam,
    servingRotationIndex: snapshot.servingRotationIndex,
    serverPlayerId: getCurrentServerPlayerId(snapshot, firstServerPlayerId),
    initialSetServer: snapshot.initialSetServer,
    isTieBreak: snapshot.isTieBreak,
    tieBreakPointsA: snapshot.tieBreakPointsA,
    tieBreakPointsB: snapshot.tieBreakPointsB,
    tieBreakInitialRotationIndex: snapshot.tieBreakInitialRotationIndex ?? null,
    matchWinner: snapshot.matchWinner ?? null,
    completedSets: snapshot.completedSets.map(s => ({
      gamesA: s.gamesA,
      gamesB: s.gamesB,
      tieBreakPointsA: s.tieBreakPointsA ?? null,
      tieBreakPointsB: s.tieBreakPointsB ?? null,
      winner: s.winner ?? null,
    })),
  };
}

function runScenario(definition) {
  const settings = {
    teamAName: 'Squadra A', teamBName: 'Squadra B',
    player1Name: 'Alex', player2Name: 'Luigi', player3Name: 'Alex', player4Name: 'Marco',
    firstServerPlayerId: definition.firstServerPlayerId,
    isGoldenPoint: definition.goldenPoint,
    advantagesBeforeGoldenPoint: definition.advantages,
    bestOfSets: definition.bestOfSets,
    gamesPerSet: definition.shortSets ? 4 : 6,
    ttsSpeed: 1, ttsVolume: 1, isVoiceMuted: false, isSfxMuted: false,
  };
  let current = createInitialSnapshot(settings.firstServerPlayerId);
  const history = [];
  const states = [stateOf(current, definition.firstServerPlayerId)];
  for (const action of definition.actions) {
    if (action === 'U') {
      if (history.length) current = history.pop();
    } else {
      const next = processPoint(current, action === 'A' ? 'teamA' : 'teamB', settings);
      if (next) {
        history.push(current);
        current = next.nextSnapshot;
      }
    }
    states.push(stateOf(current, definition.firstServerPlayerId));
  }
  return { ...definition, states };
}

const generated = { version: 1, note: 'Scenari congelati dal motore React Fase 2B.3B; Flutter confronta ogni step.', cases: definitions.map(runScenario) };
if (process.argv.includes('--update-fixtures')) {
  fs.writeFileSync(fixturePath, JSON.stringify(generated, null, 2) + '\n');
  fs.mkdirSync(path.dirname(mirrorPath), { recursive: true });
  fs.copyFileSync(fixturePath, mirrorPath);
  console.log(`Aggiornati ${generated.cases.length} scenari e ${generated.cases.reduce((n,c)=>n+c.states.length,0)} snapshot.`);
} else {
  if (!fs.existsSync(fixturePath)) throw new Error('Fixture non presente. Generarla consapevolmente con --update-fixtures');
  const expected = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  if (expected.version !== generated.version || expected.cases.length !== generated.cases.length) throw new Error('Numero/versione scenari cambiato');
  for (let i = 0; i < generated.cases.length; i++) {
    const actual = generated.cases[i];
    const fixture = expected.cases[i];
    if (JSON.stringify(actual) !== JSON.stringify(fixture)) {
      const mismatch = actual.states.findIndex((state,k) => JSON.stringify(state) !== JSON.stringify(fixture.states[k]));
      throw new Error(`Divergenza React nello scenario ${actual.id}, checkpoint ${mismatch}`);
    }
    console.log(`[PASS] ${actual.id}: ${actual.actions.length} azioni`);
  }
  if (!fs.existsSync(mirrorPath) || fs.readFileSync(mirrorPath,'utf8') !== fs.readFileSync(fixturePath,'utf8')) {
    throw new Error('La copia flutter_project/test/fixtures non coincide con test/fixtures');
  }
  console.log(`OK ${generated.cases.length} scenari, ${generated.cases.reduce((n,c)=>n+c.states.length,0)} checkpoint React. Verificare Flutter separatamente con flutter test.`);
}
