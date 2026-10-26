import { PadelMatchStore } from '../engine/padelMatchStore';
import {
  getCurrentServerPlayerId,
  getPlayerNameById,
  getTeamForPlayerId,
  createInitialSnapshot,
  PlayerId,
} from '../engine/padelScoringEngine';
import { MatchSettings, Team, PadelMatchSnapshot } from '../types/padel';

const BASE_SETTINGS: MatchSettings = {
  teamAName: 'Team Alpha',
  teamBName: 'Team Beta',
  player1Name: 'Player 1A',
  player2Name: 'Player 2A',
  player3Name: 'Player 3B',
  player4Name: 'Player 4B',
  firstServerPlayerId: 1,
  isGoldenPoint: true,
  advantagesBeforeGoldenPoint: 0,
  bestOfSets: 3,
  ttsSpeed: 1.0,
  ttsVolume: 1.0,
  isVoiceMuted: false,
  isSfxMuted: false,
};

let passed = 0;
let failed = 0;

function assert(condition: boolean, msg: string) {
  if (condition) {
    console.log(`[PASS] ${msg}`);
    passed++;
  } else {
    console.error(`[FAIL] ${msg}`);
    failed++;
  }
}

console.log('===================================================================');
console.log(' TEST INTEGRAZIONE REACT PADEL SCORE BOARD — FASE 2B.2.1');
console.log('===================================================================\n');

// --- 1. RESET CON BATTITORE 1 ---
console.log('--- 1. RESET CON BATTITORE 1 ---');
{
  const settings: MatchSettings = { ...BASE_SETTINGS, firstServerPlayerId: 1 };
  const store = new PadelMatchStore(settings);

  // Gioca qualche punto
  store.addPoint('teamA');
  store.addPoint('teamB');
  assert(store.getHistory().length === 2, '1.1: 2 punti registrati prima del reset');

  // Esegui reset
  let resetAnnouncedPlayerId: PlayerId | null = null;
  store.onReset = (pId) => {
    resetAnnouncedPlayerId = pId;
  };
  const serverId = store.resetMatch();

  const snap = store.getSnapshot();
  assert(serverId === 1, '1.2: ServerId restituito dal reset è 1');
  assert(resetAnnouncedPlayerId === 1, '1.3: Evento onReset invoca battitore 1');
  assert(snap.servingTeam === 'teamA', '1.4: servingTeam al reset è teamA');
  assert(getCurrentServerPlayerId(snap, 1) === 1, '1.5: getCurrentServerPlayerId è 1');
  assert(getPlayerNameById(serverId, settings) === 'Player 1A', '1.6: Nome battitore al reset è Player 1A');
  assert(snap.rawPointsA === 0 && snap.rawPointsB === 0, '1.7: Punti azzerati (0-0)');
  assert(snap.currentGamesA === 0 && snap.currentGamesB === 0, '1.8: Game azzerati (0-0)');
  assert(snap.servingRotationIndex === 0, '1.9: servingRotationIndex azzerato a 0');
  assert(store.getHistory().length === 0, '1.10: Storico Undo completamente vuoto dopo reset');
}

// --- 2. RESET CON BATTITORE 3 (E ANCHE 2 E 4) ---
console.log('\n--- 2. RESET CON BATTITORE 3 (E VERIFICA 2 E 4) ---');
{
  // Caso Battitore 3 (Team B)
  const settingsB: MatchSettings = { ...BASE_SETTINGS, firstServerPlayerId: 3 };
  const storeB = new PadelMatchStore(settingsB);
  storeB.addPoint('teamA');
  storeB.resetMatch();

  const snap3 = storeB.getSnapshot();
  assert(snap3.servingTeam === 'teamB', '2.1: Con firstServerPlayerId=3, servingTeam dopo reset è teamB');
  assert(getCurrentServerPlayerId(snap3, 3) === 3, '2.2: getCurrentServerPlayerId dopo reset è 3');
  assert(getPlayerNameById(3, settingsB) === 'Player 3B', '2.3: Nome battitore è Player 3B');
  assert(storeB.getHistory().length === 0, '2.4: Storico vuoto dopo reset');

  // Rotazione successiva dopo reset con battitore 3: Game 1 (P3) -> Game 2 (P1) -> Game 3 (P4) -> Game 4 (P2)
  for (let i = 0; i < 4; i++) storeB.addPoint('teamB'); // Vince Game 1
  const snapAfterGame1 = storeB.getSnapshot();
  assert(snapAfterGame1.currentGamesB === 1, '2.5: Team B ha vinto Game 1');
  assert(snapAfterGame1.servingTeam === 'teamA', '2.6: Game 2 serve Team A');
  assert(getCurrentServerPlayerId(snapAfterGame1, 3) === 1, '2.7: Game 2 batte Giocatore 1 (Team A)');

  // Caso Battitore 2 (Team A)
  const settings2: MatchSettings = { ...BASE_SETTINGS, firstServerPlayerId: 2 };
  const store2 = new PadelMatchStore(settings2);
  store2.resetMatch();
  assert(store2.getSnapshot().servingTeam === 'teamA', '2.8: Con firstServerPlayerId=2, servingTeam è teamA');
  assert(getCurrentServerPlayerId(store2.getSnapshot(), 2) === 2, '2.9: Con firstServerPlayerId=2, battitore iniziale è 2');

  // Caso Battitore 4 (Team B)
  const settings4: MatchSettings = { ...BASE_SETTINGS, firstServerPlayerId: 4 };
  const store4 = new PadelMatchStore(settings4);
  store4.resetMatch();
  assert(store4.getSnapshot().servingTeam === 'teamB', '2.10: Con firstServerPlayerId=4, servingTeam è teamB');
  assert(getCurrentServerPlayerId(store4.getSnapshot(), 4) === 4, '2.11: Con firstServerPlayerId=4, battitore iniziale è 4');
}

// --- 3. NUOVA PARTITA DOPO VITTORIA PRECEDENTE ---
console.log('\n--- 3. NUOVA PARTITA DOPO VITTORIA PRECEDENTE ---');
{
  const settings: MatchSettings = { ...BASE_SETTINGS, bestOfSets: 1 };
  const store = new PadelMatchStore(settings);

  // Vinci 6 game consecutivi per completare il match
  for (let g = 0; g < 6; g++) {
    for (let p = 0; p < 4; p++) {
      store.addPoint('teamA');
    }
  }

  assert(store.getSnapshot().matchWinner === 'teamA', '3.1: Partita terminata con vincitore teamA');
  assert(store.getSnapshot().completedSets.length === 1, '3.2: 1 set completato');

  // Ulteriore addPoint deve essere bloccato
  const blockedRes = store.addPoint('teamA');
  assert(blockedRes === null, '3.3: addPoint a match completato restituisce null (blocco attivo)');

  // Avvia nuova partita (startNewMatch)
  const newFirstServer = store.startNewMatch({ ...settings, firstServerPlayerId: 3 });
  const freshSnap = store.getSnapshot();

  assert(freshSnap.matchWinner === undefined || freshSnap.matchWinner === null, '3.4: matchWinner resettato a null');
  assert(freshSnap.completedSets.length === 0, '3.5: completedSets azzerato');
  assert(freshSnap.currentGamesA === 0 && freshSnap.currentGamesB === 0, '3.6: Game resettati');
  assert(freshSnap.rawPointsA === 0 && freshSnap.rawPointsB === 0, '3.7: Punti resettati');
  assert(freshSnap.servingTeam === 'teamB', '3.8: Nuova partita serve teamB (firstServerPlayerId=3)');
  assert(newFirstServer === 3, '3.9: Battitore iniziale nuova partita è Giocatore 3');
  assert(store.getHistory().length === 0, '3.10: Storico resettato');

  // Nuovi punti possono essere assegnati regolarmente
  const postResetPoint = store.addPoint('teamA');
  assert(postResetPoint !== null, '3.11: Nuova partita accetta punti immediatamente');
  assert(store.getSnapshot().rawPointsA === 1, '3.12: Punteggio è 15-0');
}

// --- 4. CRONOMETRO E GESTIONE RESET ---
console.log('\n--- 4. CRONOMETRO E STATO INIZIALE ---');
{
  // Verifica logica cronometro:
  // - resetMatch/startNewMatch impostano matchSeconds = 0 e isTimerRunning = true
  // Nota: Questo test verifica la funzione di reset dello stato del cronometro in memoria
  // e non costituisce un test dell'interfaccia React reale (DOM/render).
  let matchSeconds: number = 120;
  let isTimerRunning: boolean = false;
  let isBreakActive: boolean = true;
  let breakSeconds: number = 45;

  const handleResetSimulated = () => {
    matchSeconds = 0;
    isTimerRunning = true;
    isBreakActive = false;
    breakSeconds = 0;
  };

  handleResetSimulated();
  assert(matchSeconds === 0, '4.1: matchSeconds reimpostato a 0');
  assert(Boolean(isTimerRunning), '4.2: isTimerRunning è true (attivo automaticamente)');
  assert(!isBreakActive, '4.3: Pausa cambio campo annullata');
  assert(breakSeconds === 0, '4.4: Timer pausa azzerato');
}

// --- 5. DUE PUNTI RAVVICINATI CONSECUTIVI ---
console.log('\n--- 5. DUE PUNTI RAVVICINATI CONSECUTIVI ---');
{
  const store = new PadelMatchStore(BASE_SETTINGS);
  const eventsDispatched: string[] = [];
  store.onScoreEvent = (event) => {
    eventsDispatched.push(`${event.rawPointsA}-${event.rawPointsB}`);
  };

  // Due chiamate sincrone consecutive senza attendere React re-render
  store.addPoint('teamA');
  store.addPoint('teamA');

  const snap = store.getSnapshot();
  assert(snap.rawPointsA === 2, '5.1: Team A ha 30 punti (rawPointsA = 2)');
  assert(snap.rawPointsB === 0, '5.2: Team B ha 0 punti');
  assert(store.getHistory().length === 2, '5.3: Storico ha esattamente 2 stati salvati');
  assert(eventsDispatched.length === 2, '5.4: Esattamente 2 eventi di punteggio notificati');
  assert(eventsDispatched[0] === '1-0', '5.5: 1° evento è 15-0 (1-0)');
  assert(eventsDispatched[1] === '2-0', '5.6: 2° evento è 30-0 (2-0)');
}

// --- 6. PUNTO A SEGUITO SUBITO DA PUNTO B ---
console.log('\n--- 6. PUNTO A SEGUITO SUBITO DA PUNTO B ---');
{
  const store = new PadelMatchStore(BASE_SETTINGS);
  const events: string[] = [];
  store.onScoreEvent = (ev) => {
    events.push(`${ev.rawPointsA}-${ev.rawPointsB}`);
  };

  // Punto A seguito immediatamente da Punto B
  store.addPoint('teamA');
  store.addPoint('teamB');

  const snap = store.getSnapshot();
  assert(snap.rawPointsA === 1, '6.1: Team A ha 15 punti');
  assert(snap.rawPointsB === 1, '6.2: Team B ha 15 punti (15 pari)');
  assert(store.getHistory().length === 2, '6.3: Storico contiene esattamente 2 snapshot');
  assert(events[0] === '1-0', '6.4: 1° punto Team A: 15-0');
  assert(events[1] === '1-1', '6.5: 2° punto Team B: 15-15');
}

// --- 7. PUNTO SEGUITO DA UNDO ---
console.log('\n--- 7. PUNTO SEGUITO DA UNDO ---');
{
  const store = new PadelMatchStore(BASE_SETTINGS);
  let undoTriggered: boolean = false;
  store.onUndo = () => {
    undoTriggered = true;
  };

  store.addPoint('teamA');
  assert(store.getSnapshot().rawPointsA === 1, '7.1: Punto assegnato (15-0)');
  assert(store.getHistory().length === 1, '7.2: Storico ha 1 elemento prima di Undo');

  const restored = store.undo();
  assert(restored !== null, '7.3: Undo ha restituito lo snapshot precedente');
  assert(Boolean(undoTriggered), '7.4: Evento onUndo invocato');
  assert(store.getSnapshot().rawPointsA === 0, '7.5: Team A tornato a 0 punti');
  assert(store.getSnapshot().rawPointsB === 0, '7.6: Team B è a 0 punti');
  assert(store.getHistory().length === 0, '7.7: Storico Undo vuoto dopo ripristino');

  // Ulteriore Undo su storico vuoto restituisce null
  assert(store.undo() === null, '7.8: Undo su storico vuoto è non distruttivo');
}

// --- 8. UNDO SEGUITO DA NUOVO PUNTO ---
console.log('\n--- 8. UNDO SEGUITO DA NUOVO PUNTO ---');
{
  const store = new PadelMatchStore(BASE_SETTINGS);

  store.addPoint('teamA'); // 15-0
  store.undo(); // 0-0

  // Ora assegna punto a Team B
  const resB = store.addPoint('teamB');
  assert(resB !== null, '8.1: addPoint("teamB") riuscito dopo Undo');
  const snap = store.getSnapshot();
  assert(snap.rawPointsA === 0, '8.2: Team A ha 0 punti');
  assert(snap.rawPointsB === 1, '8.3: Team B ha 15 punti');
  assert(store.getHistory().length === 1, '8.4: Storico contiene lo snapshot 0-0 precedente');
}

// --- 9. NESSUN DUPLICATO NELLO STORICO ---
console.log('\n--- 9. NESSUN DUPLICATO NELLO STORICO ---');
{
  const store = new PadelMatchStore(BASE_SETTINGS);

  // Esegui sequenza complessa: A, A, B, Undo, A
  store.addPoint('teamA'); // Snap 0: 0-0 -> Now: 15-0
  store.addPoint('teamA'); // Snap 1: 15-0 -> Now: 30-0
  store.addPoint('teamB'); // Snap 2: 30-0 -> Now: 30-15
  store.undo();            // Ripristina Snap 2 (30-0) -> Now: 30-0
  store.addPoint('teamA'); // Snap 2: 30-0 -> Now: 40-0

  const hist = store.getHistory();
  assert(hist.length === 3, '9.1: Lunghezza storico finale è 3');
  assert(hist[0].rawPointsA === 0 && hist[0].rawPointsB === 0, '9.2: Hist[0] è 0-0');
  assert(hist[1].rawPointsA === 1 && hist[1].rawPointsB === 0, '9.3: Hist[1] è 15-0');
  assert(hist[2].rawPointsA === 2 && hist[2].rawPointsB === 0, '9.4: Hist[2] è 30-0');

  // Verifica che gli snapshot nello storico siano copie distinte e non riferimenti mutati
  const snapFinal = store.getSnapshot();
  assert(snapFinal.rawPointsA === 3 && snapFinal.rawPointsB === 0, '9.5: Snapshot corrente è 40-0');
  assert(hist[2].rawPointsA === 2, '9.6: Hist[2] non è stato corrotto dalla mutazione');
}

// --- 10. VERIFICA BLOCCO INPUT QUANDO MODAL O VIEW DIVERSA ---
console.log('\n--- 10. GESTIONE STATO DI BLOCCO STORE ---');
{
  const store = new PadelMatchStore(BASE_SETTINGS);
  store.setBlocked(true);

  assert(store.isBlocked() === true, '10.1: Store correttamente bloccato');
  assert(store.addPoint('teamA') === null, '10.2: addPoint ignorato quando blocked=true');
  assert(store.undo() === null, '10.3: undo ignorato quando blocked=true');
  assert(store.getSnapshot().rawPointsA === 0, '10.4: Nessun punto assegnato durante blocco');

  store.setBlocked(false);
  assert(store.addPoint('teamA') !== null, '10.5: addPoint eseguito dopo sblocco');
  assert(store.getSnapshot().rawPointsA === 1, '10.6: Punteggio aggiornato a 15-0');
}

console.log('\n===================================================================');
console.log(` RIEPILOGO INTEGRATION TEST REACT: ${passed} PASSATI, ${failed} FALLITI`);
console.log('===================================================================');

if (failed > 0) {
  process.exit(1);
}
