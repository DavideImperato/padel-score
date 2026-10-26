// Test suite del motore di punteggio reale Padel Score Board (FASE 2B.2)
// Importa ed esercita direttamente il modulo di produzione: src/engine/padelScoringEngine.ts
// Regolamento ufficiale FIP aggiornato al 2026.

import {
  processPoint,
  getCurrentServerPlayerId,
  getCurrentServingTeam,
  getPlayerNameById,
  getTeamForPlayerId,
  getRotationOrder,
  createInitialSnapshot,
  setStartOfSetServer,
  PlayerId,
} from '../engine/padelScoringEngine';
import { PadelMatchSnapshot, MatchSettings, Team } from '../types/padel';

// Helper per simulare una sequenza di assegnazione punti con storico per Undo
class PadelMatchRunner {
  public snapshot: PadelMatchSnapshot;
  public settings: MatchSettings;
  public history: PadelMatchSnapshot[] = [];

  constructor(settings: MatchSettings) {
    this.settings = settings;
    const initialPlayer = (settings.firstServerPlayerId >= 1 && settings.firstServerPlayerId <= 4)
      ? (settings.firstServerPlayerId as PlayerId)
      : 1;
    this.snapshot = createInitialSnapshot(initialPlayer);
  }

  public addPoint(scoringTeam: Team) {
    if (this.snapshot.matchWinner) return null;
    const result = processPoint(this.snapshot, scoringTeam, this.settings);
    if (!result) return null;
    this.history.push({ ...this.snapshot, completedSets: [...this.snapshot.completedSets] });
    this.snapshot = result.nextSnapshot;
    return result;
  }

  public undo() {
    if (this.history.length === 0) return false;
    const prev = this.history.pop()!;
    this.snapshot = prev;
    return true;
  }

  public getCurrentServerId(): PlayerId {
    return getCurrentServerPlayerId(this.snapshot, this.settings.firstServerPlayerId);
  }

  public getCurrentServerName(): string {
    return getPlayerNameById(this.getCurrentServerId(), this.settings);
  }

  public getCurrentServingTeam(): Team {
    return getCurrentServingTeam(this.snapshot, this.settings.firstServerPlayerId);
  }
}

function createSettings(overrides: Partial<MatchSettings> = {}): MatchSettings {
  return {
    teamAName: 'Squadra A',
    teamBName: 'Squadra B',
    player1Name: 'Mario',
    player2Name: 'Luigi',
    player3Name: 'Paolo',
    player4Name: 'Marco',
    firstServerPlayerId: 1,
    isGoldenPoint: false,
    advantagesBeforeGoldenPoint: 0,
    bestOfSets: 3,
    ttsSpeed: 0.95,
    ttsVolume: 1.0,
    isVoiceMuted: false,
    isSfxMuted: false,
    ...overrides,
  };
}

async function runRealEngineTests() {
  console.log('================================================================');
  console.log('=== TEST MOTORE REALE PADEL SCORE BOARD — FASE 2B.2 (FIP 2026) ===');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, title: string, details?: string) {
    if (condition) {
      console.log(`[PASS] ${title}`);
      passed++;
    } else {
      console.error(`[FAIL] ${title}`);
      if (details) console.error(`       -> ${details}`);
      failed++;
    }
  }

  // -------------------------------------------------------------------------
  // 1. GIOCATORI OMONIMI IN SQUADRE DIFFERENTI
  // -------------------------------------------------------------------------
  console.log('--- 1. GIOCATORI OMONIMI IN SQUADRE DIFFERENTI ---');
  {
    // P1 (Sq A) e P3 (Sq B) si chiamano entrambi "Alex"
    const runner = new PadelMatchRunner(createSettings({
      player1Name: 'Alex',
      player2Name: 'Luigi',
      player3Name: 'Alex',
      player4Name: 'Marco',
      firstServerPlayerId: 1, // P1 (Sq A)
      isGoldenPoint: true,
    }));

    // Game 1: P1 serve (Alex, Sq A). Sq A vince il game 1-0.
    runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');

    // Nel Game 2 DEVE servire Squadra B (P3: Alex, Sq B).
    // Con l'ID stabile, il server ID è 3 e la squadra è teamB, senza ambiguità.
    const serverIdGame2 = runner.getCurrentServerId();
    const serverTeamGame2 = runner.getCurrentServingTeam();
    const serverNameGame2 = runner.getCurrentServerName();

    assert(serverIdGame2 === 3, '1.1: ID battitore Game 2 è 3 (Giocatore 3, Squadra B)');
    assert(serverTeamGame2 === 'teamB', '1.2: Squadra al servizio Game 2 è teamB nonostante il nome "Alex" identico a P1');
    assert(serverNameGame2 === 'Alex', '1.3: Nome visualizzato rimane correttamente "Alex"');
  }

  // -------------------------------------------------------------------------
  // 2. ROTAZIONE DEI QUATTRO BATTITORI
  // -------------------------------------------------------------------------
  console.log('\n--- 2. ROTAZIONE DEI QUATTRO BATTITORI ---');
  {
    const runner = new PadelMatchRunner(createSettings({
      firstServerPlayerId: 1,
      isGoldenPoint: true,
    }));

    const expectedSequence: Array<{ game: number; playerId: PlayerId; team: Team }> = [
      { game: 1, playerId: 1, team: 'teamA' },
      { game: 2, playerId: 3, team: 'teamB' },
      { game: 3, playerId: 2, team: 'teamA' },
      { game: 4, playerId: 4, team: 'teamB' },
      { game: 5, playerId: 1, team: 'teamA' },
      { game: 6, playerId: 3, team: 'teamB' },
    ];

    for (const step of expectedSequence) {
      assert(runner.getCurrentServerId() === step.playerId, `2.Game ${step.game}: Battitore è ID ${step.playerId}`);
      assert(runner.getCurrentServingTeam() === step.team, `2.Game ${step.game}: Squadra al servizio è ${step.team}`);
      // Assegna game
      runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
    }
  }

  // -------------------------------------------------------------------------
  // 3. INIZIO SET SUCCESSIVO DOPO 6-4 (CASO A FIP)
  // -------------------------------------------------------------------------
  console.log('\n--- 3. INIZIO SET SUCCESSIVO DOPO 6-4 (CASO A) ---');
  {
    // Caso A: La Squadra A serve nel primo game. Il set termina 6-4.
    // Dopo 10 game, il primo servizio del nuovo set spetta alla Squadra A.
    const runner = new PadelMatchRunner(createSettings({
      firstServerPlayerId: 1,
      isGoldenPoint: true,
    }));

    // 10 game: 1:A, 2:B, 3:A, 4:B, 5:A, 6:B, 7:A, 8:B, 9:A, 10:B -> Set vinto 6-4 da Squadra A
    const winners: Team[] = [
      'teamA', 'teamB', 'teamA', 'teamB', 'teamA', 'teamB', 'teamA', 'teamB', 'teamA', 'teamA'
    ];
    for (const w of winners) {
      runner.addPoint(w); runner.addPoint(w); runner.addPoint(w); runner.addPoint(w);
    }

    assert(runner.snapshot.completedSets.length === 1, '3.1: Set 1 concluso 6-4');
    assert(runner.snapshot.completedSets[0].gamesA === 6 && runner.snapshot.completedSets[0].gamesB === 4, '3.2: Punteggio set 1 è 6-4');

    // Verifica primo servizio del Set 2
    const set2ServerTeam = runner.getCurrentServingTeam();
    const set2ServerId = runner.getCurrentServerId();

    assert(set2ServerTeam === 'teamA', '3.3: Caso A: Dopo 6-4 (10 game), il 1° servizio del Set 2 spetta a Squadra A');
    assert(set2ServerId === 2, '3.4: Caso A: Battitore è il Giocatore 2 (Squadra A), rispettando la rotazione naturale');
  }

  // -------------------------------------------------------------------------
  // 4. INIZIO SET SUCCESSIVO DOPO 6-3 (CASO B FIP)
  // -------------------------------------------------------------------------
  console.log('\n--- 4. INIZIO SET SUCCESSIVO DOPO 6-3 (CASO B) ---');
  {
    // Caso B: La Squadra A serve nel primo game. Il set termina 6-3.
    // Dopo 9 game, il primo servizio del nuovo set spetta alla Squadra B.
    const runner = new PadelMatchRunner(createSettings({
      firstServerPlayerId: 1,
      isGoldenPoint: true,
    }));

    // 9 game (6 per Team A, 3 per Team B):
    // Game 1: A (1-0), Game 2: B (1-1), Game 3: A (2-1), Game 4: B (2-2),
    // Game 5: A (3-2), Game 6: B (3-3), Game 7: A (4-3), Game 8: A (5-3), Game 9: A (6-3)
    const winners: Team[] = [
      'teamA', 'teamB', 'teamA', 'teamB', 'teamA', 'teamB', 'teamA', 'teamA', 'teamA'
    ];
    for (const w of winners) {
      runner.addPoint(w); runner.addPoint(w); runner.addPoint(w); runner.addPoint(w);
    }

    assert(runner.snapshot.completedSets.length === 1, '4.1: Set 1 concluso 6-3');
    assert(runner.snapshot.completedSets[0].gamesA === 6 && runner.snapshot.completedSets[0].gamesB === 3, '4.2: Punteggio set 1 è 6-3');

    // Verifica primo servizio del Set 2
    const set2ServerTeam = runner.getCurrentServingTeam();
    const set2ServerId = runner.getCurrentServerId();

    assert(set2ServerTeam === 'teamB', '4.3: Caso B: Dopo 6-3 (9 game), il 1° servizio del Set 2 spetta a Squadra B');
    assert(set2ServerId === 3, '4.4: Caso B: Battitore è il Giocatore 3 (Squadra B), rispettando la rotazione naturale');
  }

  // -------------------------------------------------------------------------
  // 5. SERVIZIO DOPO TIE-BREAK (REGOLA FIP 9)
  // -------------------------------------------------------------------------
  console.log('\n--- 5. SERVIZIO DOPO TIE-BREAK ---');
  {
    // Regola FIP: La coppia che ha iniziato a servire nel tie-break riceverà nel 1° game del set successivo.
    const runner = new PadelMatchRunner(createSettings({
      firstServerPlayerId: 1, // P1 (Sq A)
      isGoldenPoint: true,
    }));

    // Arrivo a 6-6
    for (let g = 0; g < 6; g++) {
      runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
      runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB');
    }
    assert(runner.snapshot.isTieBreak === true, '5.1: Tie-break avviato sul 6-6');

    // Chi ha iniziato a servire nel tie-break?
    const tbInitialServerId = runner.getCurrentServerId();
    const tbInitialServerTeam = runner.getCurrentServingTeam();
    assert(tbInitialServerTeam === 'teamA' && tbInitialServerId === 1, '5.2: Tie-break iniziato con servizio di Squadra A (P1)');

    // Vittoria tie-break 7-5 per Squadra A
    for (let i = 0; i < 6; i++) runner.addPoint('teamA');
    for (let i = 0; i < 5; i++) runner.addPoint('teamB');
    runner.addPoint('teamA'); // 7-5 -> Set vince 7-6

    assert(runner.snapshot.completedSets.length === 1, '5.3: Set 1 vinto al tie-break (7-6)');
    assert(runner.snapshot.isTieBreak === false, '5.4: isTieBreak resettato a false per il nuovo set');

    // Chi serve nel 1° game del Set 2?
    // Deve ricevere Squadra A, quindi DEVE SERVIRE LA SQUADRA B!
    const set2ServerTeam = runner.getCurrentServingTeam();
    const set2ServerId = runner.getCurrentServerId();

    assert(set2ServerTeam === 'teamB', '5.5: Squadra al servizio nel 1° game del Set 2 è Squadra B (Squadra A riceve come da regola FIP)');
    assert(set2ServerId === 3, '5.6: Battitore è Giocatore 3 (Squadra B), perfetta coerenza tra ID e servingTeam');
  }

  // -------------------------------------------------------------------------
  // 6. SERVIZIO E PUNTEGGIO DOPO UNDO
  // -------------------------------------------------------------------------
  console.log('\n--- 6. SERVIZIO E PUNTEGGIO DOPO UNDO ---');
  {
    const runner = new PadelMatchRunner(createSettings({ isGoldenPoint: false }));

    // 0-0 -> 15-0
    runner.addPoint('teamA');
    assert(runner.snapshot.rawPointsA === 1, '6.1: Punto assegnato (15-0)');
    runner.undo();
    assert(runner.snapshot.rawPointsA === 0, '6.2: Undo ripristina 0-0');

    // Game 1 vinto da Squadra A -> 1-0, servizio passa a Squadra B (P3)
    runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
    assert(runner.snapshot.currentGamesA === 1, '6.3: Game 1 vinto');
    assert(runner.getCurrentServerId() === 3, '6.4: Servizio Game 2 a Giocatore 3');

    // Undo del game vincente
    runner.undo();
    assert(runner.snapshot.currentGamesA === 0, '6.5: Undo ripristina 0 game');
    assert(runner.snapshot.rawPointsA === 3, '6.6: Undo ripristina 40-0');
    assert(runner.getCurrentServerId() === 1, '6.7: Undo ripristina il battitore del Game 1 (Giocatore 1)');
  }

  // -------------------------------------------------------------------------
  // 7. VANTAGGI TRADIZIONALI
  // -------------------------------------------------------------------------
  console.log('\n--- 7. VANTAGGI TRADIZIONALI ---');
  {
    const runner = new PadelMatchRunner(createSettings({ isGoldenPoint: false }));
    // 40-40
    runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
    runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB');
    assert(runner.snapshot.rawPointsA === 3 && runner.snapshot.rawPointsB === 3, '7.1: 40-40 Parità');

    // Vantaggio A
    runner.addPoint('teamA');
    assert(runner.snapshot.rawPointsA === 4 && runner.snapshot.rawPointsB === 3, '7.2: Vantaggio Squadra A (AV)');

    // Ritorno a 40-40
    runner.addPoint('teamB');
    assert(runner.snapshot.rawPointsA === 3 && runner.snapshot.rawPointsB === 3 && runner.snapshot.deuceCount === 1,
      '7.3: Ritorno a 40-40 con incremento deuceCount = 1');

    // Due punti consecutivi di Squadra A
    runner.addPoint('teamA'); // AV
    runner.addPoint('teamA'); // Game
    assert(runner.snapshot.currentGamesA === 1, '7.4: Vittoria game dopo due punti consecutivi da deuce');
  }

  // -------------------------------------------------------------------------
  // 8. PUNTO D'ORO
  // -------------------------------------------------------------------------
  console.log('\n--- 8. PUNTO D\'ORO ---');
  {
    const runner = new PadelMatchRunner(createSettings({ isGoldenPoint: true, advantagesBeforeGoldenPoint: 0 }));
    // 40-40
    runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
    runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB');
    assert(runner.snapshot.rawPointsA === 3 && runner.snapshot.rawPointsB === 3, '8.1: 40-40');

    // Punto secco Punto d'Oro
    runner.addPoint('teamB');
    assert(runner.snapshot.currentGamesB === 1 && runner.snapshot.rawPointsA === 0, '8.2: Punto d\'oro vince immediatamente il game');
  }

  // -------------------------------------------------------------------------
  // 9. STAR POINT FIP 2026
  // -------------------------------------------------------------------------
  console.log('\n--- 9. STAR POINT FIP 2026 ---');
  {
    const runner = new PadelMatchRunner(createSettings({ isGoldenPoint: true, advantagesBeforeGoldenPoint: 2 }));
    // 1° Deuce (40-40, deuceCount = 0)
    runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
    runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB');
    assert(runner.snapshot.deuceCount === 0, '9.1: 1° 40-40 (deuceCount = 0)');

    // 1° Vantaggio A -> Ritorno Deuce (deuceCount = 1)
    runner.addPoint('teamA');
    assert(runner.snapshot.rawPointsA === 4, '9.2: 1° Vantaggio A');
    runner.addPoint('teamB');
    assert(runner.snapshot.deuceCount === 1, '9.3: 2° 40-40 (deuceCount = 1)');

    // 2° Vantaggio B -> Ritorno Deuce (deuceCount = 2, Star Point attivo)
    runner.addPoint('teamB');
    assert(runner.snapshot.rawPointsB === 4, '9.4: 2° Vantaggio B');
    runner.addPoint('teamA');
    assert(runner.snapshot.deuceCount === 2, '9.5: 3° 40-40 (deuceCount = 2, Star Point decisivo attivo)');

    // Punto decisivo Star Point
    runner.addPoint('teamA');
    assert(runner.snapshot.currentGamesA === 1 && runner.snapshot.rawPointsA === 0,
      '9.6: Star Point decisivo sul 3° deuce assegna direttamente il game');
  }

  // -------------------------------------------------------------------------
  // 10. TIE-BREAK CON PUNTEGGIO OLTRE 7 (OLTRANZA)
  // -------------------------------------------------------------------------
  console.log('\n--- 10. TIE-BREAK CON PUNTEGGIO OLTRE 7 (OLTRANZA) ---');
  {
    const runner = new PadelMatchRunner(createSettings({ isGoldenPoint: true }));
    // Arrivo a 6-6
    for (let g = 0; g < 6; g++) {
      runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA'); runner.addPoint('teamA');
      runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB'); runner.addPoint('teamB');
    }

    // 6-6 nel Tie-Break
    for (let i = 0; i < 6; i++) {
      runner.addPoint('teamA');
      runner.addPoint('teamB');
    }
    assert(runner.snapshot.tieBreakPointsA === 6 && runner.snapshot.tieBreakPointsB === 6, '10.1: Tie-break 6-6');

    // 7-6 non conclude il tie-break
    runner.addPoint('teamA');
    assert(runner.snapshot.isTieBreak === true && runner.snapshot.tieBreakPointsA === 7, '10.2: Tie-break 7-6 continua (serve scarto di 2)');

    // 7-7 -> 8-7 -> 8-8 -> 9-8 -> 10-8 (vittoria)
    runner.addPoint('teamB'); // 7-7
    runner.addPoint('teamA'); // 8-7
    runner.addPoint('teamB'); // 8-8
    runner.addPoint('teamA'); // 9-8
    runner.addPoint('teamA'); // 10-8
    assert(runner.snapshot.completedSets[0].tieBreakPointsA === 10 && runner.snapshot.completedSets[0].tieBreakPointsB === 8,
      '10.3: Vittoria Tie-break a oltranza 10-8 con 2 punti di vantaggio');
  }

  // -------------------------------------------------------------------------
  // 11. VITTORIA DEL SET E DELLA PARTITA
  // -------------------------------------------------------------------------
  console.log('\n--- 11. VITTORIA DEL SET E DELLA PARTITA ---');
  {
    // Best of 1 set
    const runner1 = new PadelMatchRunner(createSettings({ bestOfSets: 1, isGoldenPoint: true }));
    for (let g = 0; g < 6; g++) {
      runner1.addPoint('teamA'); runner1.addPoint('teamA'); runner1.addPoint('teamA'); runner1.addPoint('teamA');
    }
    assert(runner1.snapshot.matchWinner === 'teamA', '11.1: Best of 1: partita conclusa al 1° set');

    // Best of 3 set
    const runner3 = new PadelMatchRunner(createSettings({ bestOfSets: 3, isGoldenPoint: true }));
    // Set 1 a A
    for (let g = 0; g < 6; g++) {
      runner3.addPoint('teamA'); runner3.addPoint('teamA'); runner3.addPoint('teamA'); runner3.addPoint('teamA');
    }
    assert(runner3.snapshot.matchWinner === undefined, '11.2: Best of 3: partita in corso dopo 1 set vinto');
    // Set 2 a B (1-1)
    for (let g = 0; g < 6; g++) {
      runner3.addPoint('teamB'); runner3.addPoint('teamB'); runner3.addPoint('teamB'); runner3.addPoint('teamB');
    }
    assert(runner3.snapshot.matchWinner === undefined, '11.3: Best of 3: continua al 3° set sull\'1 pari');
    // Set 3 a A (2-1)
    for (let g = 0; g < 6; g++) {
      runner3.addPoint('teamA'); runner3.addPoint('teamA'); runner3.addPoint('teamA'); runner3.addPoint('teamA');
    }
    assert(runner3.snapshot.matchWinner === 'teamA', '11.4: Best of 3: Squadra A vince la partita 2 set a 1');
  }

  // -------------------------------------------------------------------------
  // 12. BLOCCO DEGLI INPUT A PARTITA CONCLUSA
  // -------------------------------------------------------------------------
  console.log('\n--- 12. BLOCCO DEGLI INPUT A PARTITA CONCLUSA ---');
  {
    const runnerOver = new PadelMatchRunner(createSettings({ bestOfSets: 1, isGoldenPoint: true }));
    for (let g = 0; g < 6; g++) {
      runnerOver.addPoint('teamA'); runnerOver.addPoint('teamA'); runnerOver.addPoint('teamA'); runnerOver.addPoint('teamA');
    }
    assert(runnerOver.snapshot.matchWinner === 'teamA', '12.1: Partita vinta da Squadra A');

    // Tentativo di assegnare punti a partita conclusa
    const resultAfterOver = runnerOver.addPoint('teamB');
    assert(resultAfterOver === null, '12.2: addPoint restituisce null se matchWinner è impostato');
    assert(runnerOver.snapshot.currentGamesB === 0, '12.3: Nessun punto o game assegnato a partita conclusa (blocco input)');
  }

  // -------------------------------------------------------------------------
  // 13. PREDISPOSIZIONE SCELTA BATTITORE A INIZIO SET
  // -------------------------------------------------------------------------
  console.log('\n--- 13. PREDISPOSIZIONE SCELTA BATTITORE A INIZIO SET ---');
  {
    // A inizio set, se la coppia al servizio (es. Squadra A) decide di iniziare con il compagno (P2 anziché P1)
    const initialSnap = createInitialSnapshot(1); // Default: P1 (Sq A)
    const customSnap = setStartOfSetServer(initialSnap, 2, 1);
    const serverId = getCurrentServerPlayerId(customSnap, 1);
    const serverTeam = getCurrentServingTeam(customSnap, 1);

    assert(serverId === 2, '13.1: Scelta esplicita battitore a inizio set assegna P2');
    assert(serverTeam === 'teamA', '13.2: Squadra al servizio rimane coerente (teamA)');
  }

  console.log('\n================================================================');
  console.log(`=== RIEPILOGO TEST MOTORE REALE: ${passed} PASSATI, ${failed} FALLITI ===`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runRealEngineTests();
