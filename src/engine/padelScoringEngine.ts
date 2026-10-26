// Motore deterministico e puro per il calcolo del punteggio e rotazione servizio nel Padel
// Regolamento ufficiale FIP aggiornato al 2026.
// Nessuna dipendenza da React, DOM, Audio o Timer.

import { Team, SetScore, PadelMatchSnapshot, MatchSettings } from '../types/padel';

export type PlayerId = 1 | 2 | 3 | 4;

export interface PlayerInfo {
  id: PlayerId;
  team: Team;
}

export type ScoringEventType =
  | 'point'
  | 'tieBreakPoint'
  | 'gameWon'
  | 'tieBreakStarted'
  | 'setWon'
  | 'matchWon';

export interface ScoringEvent {
  type: ScoringEventType;
  scoringTeam: Team;
  winner?: Team;
  setNumber?: number;
  finalGamesA?: number;
  finalGamesB?: number;
  tieBreakPointsA?: number;
  tieBreakPointsB?: number;
  setsWonA?: number;
  setsWonB?: number;
  serverPlayerId: PlayerId;
  servingTeam: Team;
  rawPointsA: number;
  rawPointsB: number;
  isDeuce?: boolean;
  isGoldenPoint?: boolean;
  isAdvantage?: boolean;
  message?: string;
}

export interface ScoringResult {
  nextSnapshot: PadelMatchSnapshot;
  event: ScoringEvent;
}

/**
 * Associa in modo immutabile l'ID del giocatore alla squadra di appartenenza.
 * Giocatore 1 e 2 -> Squadra A
 * Giocatore 3 e 4 -> Squadra B
 */
export function getTeamForPlayerId(playerId: PlayerId): Team {
  return playerId === 1 || playerId === 2 ? 'teamA' : 'teamB';
}

/**
 * Restituisce il nome visualizzato per un ID giocatore dalle impostazioni.
 */
export function getPlayerNameById(playerId: PlayerId, settings: MatchSettings): string {
  switch (playerId) {
    case 1: return settings.player1Name?.trim() || 'Giocatore 1';
    case 2: return settings.player2Name?.trim() || 'Giocatore 2';
    case 3: return settings.player3Name?.trim() || 'Giocatore 3';
    case 4: return settings.player4Name?.trim() || 'Giocatore 4';
    default: return `Giocatore ${playerId}`;
  }
}

/**
 * Calcola l'ordine ciclico di rotazione dei 4 battitori (ID stabili)
 * in base al primo battitore scelto.
 *
 * Sequenza ufficiale FIP:
 * - Se inizia 1 (Sq A): [1, 3, 2, 4] -> Sq A, Sq B, Sq A, Sq B
 * - Se inizia 2 (Sq A): [2, 3, 1, 4] -> Sq A, Sq B, Sq A, Sq B
 * - Se inizia 3 (Sq B): [3, 1, 4, 2] -> Sq B, Sq A, Sq B, Sq A
 * - Se inizia 4 (Sq B): [4, 1, 3, 2] -> Sq B, Sq A, Sq B, Sq A
 */
export function getRotationOrder(firstServerPlayerId: number = 1): PlayerId[] {
  switch (firstServerPlayerId) {
    case 1: return [1, 3, 2, 4];
    case 2: return [2, 3, 1, 4];
    case 3: return [3, 1, 4, 2];
    case 4: return [4, 1, 3, 2];
    default: return [1, 3, 2, 4];
  }
}

/**
 * Determina l'ID del giocatore attualmente al servizio.
 * Nel Tie-break la sequenza è 1-2-2-2...
 * Nei game ordinari è ciclica sulla rotazione.
 */
export function getCurrentServerPlayerId(
  snapshot: PadelMatchSnapshot,
  firstServerPlayerId: number = 1
): PlayerId {
  const rotation = getRotationOrder(firstServerPlayerId);

  if (snapshot.isTieBreak) {
    const initialIdx = snapshot.tieBreakInitialRotationIndex ?? snapshot.servingRotationIndex;
    const totalPoints = snapshot.tieBreakPointsA + snapshot.tieBreakPointsB;
    const shift = totalPoints === 0 ? 0 : Math.floor((totalPoints + 1) / 2);
    return rotation[(initialIdx + shift) % rotation.length];
  }

  return rotation[snapshot.servingRotationIndex % rotation.length];
}

/**
 * Determina la squadra al servizio direttamente dall'ID del battitore attivo.
 * Elimina alla radice qualsiasi errore di confronto tra stringhe dei nomi.
 */
export function getCurrentServingTeam(
  snapshot: PadelMatchSnapshot,
  firstServerPlayerId: number = 1
): Team {
  const playerId = getCurrentServerPlayerId(snapshot, firstServerPlayerId);
  return getTeamForPlayerId(playerId);
}

/**
 * Crea lo snapshot iniziale della partita.
 */
export function createInitialSnapshot(firstServerPlayerId: number = 1): PadelMatchSnapshot {
  const initialPlayer = (firstServerPlayerId >= 1 && firstServerPlayerId <= 4)
    ? (firstServerPlayerId as PlayerId)
    : 1;
  const initialTeam = getTeamForPlayerId(initialPlayer);

  return {
    rawPointsA: 0,
    rawPointsB: 0,
    currentGamesA: 0,
    currentGamesB: 0,
    completedSets: [],
    servingTeam: initialTeam,
    servingRotationIndex: 0,
    initialSetServer: initialTeam,
    isTieBreak: false,
    tieBreakPointsA: 0,
    tieBreakPointsB: 0,
    deuceCount: 0,
    lastEventMessage: 'Inizio match',
  };
}

/**
 * Aggiunge un punto alla partita secondo le regole FIP 2026.
 * Funzione pura: non muta snapshot né settings.
 */
export function processPoint(
  current: PadelMatchSnapshot,
  scoringTeam: Team,
  settings: MatchSettings
): ScoringResult | null {
  // Se la partita è già conclusa, non processare ulteriori punti
  if (current.matchWinner) {
    return null;
  }

  const firstServerId = settings.firstServerPlayerId || 1;

  // =========================================================================
  // 1. GESTIONE TIE-BREAK
  // =========================================================================
  if (current.isTieBreak) {
    let tbA = current.tieBreakPointsA;
    let tbB = current.tieBreakPointsB;

    if (scoringTeam === 'teamA') tbA++;
    else tbB++;

    const totalPoints = tbA + tbB;
    const wonA = tbA >= 7 && tbA - tbB >= 2;
    const wonB = tbB >= 7 && tbB - tbA >= 2;

    // Vittoria del Tie-Break
    if (wonA || wonB) {
      const setWinner: Team = wonA ? 'teamA' : 'teamB';
      return processSetWin(
        current,
        setWinner,
        wonA ? 7 : 6,
        wonB ? 7 : 6,
        settings,
        tbA,
        tbB
      );
    }

    // Tie-break continua: calcolo prossimo battitore secondo sequenza 1-2-2-2...
    const initialIdx = current.tieBreakInitialRotationIndex ?? current.servingRotationIndex;
    const shift = Math.floor((totalPoints + 1) / 2);
    const rotation = getRotationOrder(firstServerId);
    const nextRot = initialIdx + shift;
    const nextPlayerId = rotation[nextRot % rotation.length];
    const nextServerTeam = getTeamForPlayerId(nextPlayerId);

    const nextSnapshot: PadelMatchSnapshot = {
      ...current,
      tieBreakPointsA: tbA,
      tieBreakPointsB: tbB,
      servingTeam: nextServerTeam,
      lastEventMessage: `Tie-break ${tbA} - ${tbB}`,
    };

    return {
      nextSnapshot,
      event: {
        type: 'tieBreakPoint',
        scoringTeam,
        tieBreakPointsA: tbA,
        tieBreakPointsB: tbB,
        serverPlayerId: nextPlayerId,
        servingTeam: nextServerTeam,
        rawPointsA: 0,
        rawPointsB: 0,
      },
    };
  }

  // =========================================================================
  // 2. GESTIONE GAME STANDARD
  // =========================================================================
  let pA = current.rawPointsA;
  let pB = current.rawPointsB;
  const deuceCount = current.deuceCount ?? 0;

  // Punto d'Oro o Star Point
  const isGoldenPointNow =
    settings.isGoldenPoint &&
    pA === 3 &&
    pB === 3 &&
    deuceCount >= (settings.advantagesBeforeGoldenPoint ?? 0);

  if (scoringTeam === 'teamA') {
    if (pA < 3) {
      pA++;
      return commitRegularPoint(current, pA, pB, deuceCount, scoringTeam, settings);
    } else if (pA === 3 && pB < 3) {
      // Vittoria game su 40-0, 40-15, 40-30
      return processGameWin(current, 'teamA', settings);
    } else if (pA === 3 && pB === 3) {
      if (isGoldenPointNow) {
        return processGameWin(current, 'teamA', settings);
      } else {
        pA = 4; // Vantaggio Squadra A
        return commitRegularPoint(current, pA, pB, deuceCount, scoringTeam, settings);
      }
    } else if (pA === 4 && pB === 3) {
      // Vittoria game da Vantaggio Squadra A
      return processGameWin(current, 'teamA', settings);
    } else if (pA === 3 && pB === 4) {
      // Contro-punto: da Vantaggio B si torna a 40-40 (Deuce)
      pB = 3;
      const nextDeuceCount = deuceCount + 1;
      return commitRegularPoint(current, pA, pB, nextDeuceCount, scoringTeam, settings);
    }
  } else {
    // Squadra B segna
    if (pB < 3) {
      pB++;
      return commitRegularPoint(current, pA, pB, deuceCount, scoringTeam, settings);
    } else if (pB === 3 && pA < 3) {
      return processGameWin(current, 'teamB', settings);
    } else if (pA === 3 && pB === 3) {
      if (isGoldenPointNow) {
        return processGameWin(current, 'teamB', settings);
      } else {
        pB = 4; // Vantaggio Squadra B
        return commitRegularPoint(current, pA, pB, deuceCount, scoringTeam, settings);
      }
    } else if (pB === 4 && pA === 3) {
      return processGameWin(current, 'teamB', settings);
    } else if (pB === 3 && pA === 4) {
      pA = 3;
      const nextDeuceCount = deuceCount + 1;
      return commitRegularPoint(current, pA, pB, nextDeuceCount, scoringTeam, settings);
    }
  }

  return null;
}

function commitRegularPoint(
  current: PadelMatchSnapshot,
  newPA: number,
  newPB: number,
  newDeuceCount: number,
  scoringTeam: Team,
  settings: MatchSettings
): ScoringResult {
  const firstServerId = settings.firstServerPlayerId || 1;
  const serverId = getCurrentServerPlayerId(current, firstServerId);
  const serverTeam = getTeamForPlayerId(serverId);

  const isDeuce = newPA === 3 && newPB === 3;
  const isAdvantage = newPA === 4 || newPB === 4;
  const isGolden = isDeuce && settings.isGoldenPoint && newDeuceCount >= (settings.advantagesBeforeGoldenPoint ?? 0);

  const nextSnapshot: PadelMatchSnapshot = {
    ...current,
    rawPointsA: newPA,
    rawPointsB: newPB,
    deuceCount: newDeuceCount,
    lastEventMessage: isAdvantage
      ? `Vantaggio ${newPA === 4 ? settings.teamAName : settings.teamBName}`
      : isGolden
      ? "Punto d'oro"
      : 'Punto assegnato',
  };

  return {
    nextSnapshot,
    event: {
      type: 'point',
      scoringTeam,
      rawPointsA: newPA,
      rawPointsB: newPB,
      serverPlayerId: serverId,
      servingTeam: serverTeam,
      isDeuce,
      isGoldenPoint: isGolden,
      isAdvantage,
    },
  };
}

function processGameWin(
  current: PadelMatchSnapshot,
  winner: Team,
  settings: MatchSettings
): ScoringResult {
  let gA = current.currentGamesA;
  let gB = current.currentGamesB;
  if (winner === 'teamA') gA++;
  else gB++;

  const firstServerId = settings.firstServerPlayerId || 1;
  const rotation = getRotationOrder(firstServerId);
  const nextRotIndex = current.servingRotationIndex + 1;
  const nextServerPlayerId = rotation[nextRotIndex % rotation.length];
  const nextServerTeam = getTeamForPlayerId(nextServerPlayerId);

  // Scatto Tie-Break sul 6-6
  if (gA === 6 && gB === 6) {
    const nextSnapshot: PadelMatchSnapshot = {
      ...current,
      rawPointsA: 0,
      rawPointsB: 0,
      deuceCount: 0,
      currentGamesA: 6,
      currentGamesB: 6,
      isTieBreak: true,
      tieBreakPointsA: 0,
      tieBreakPointsB: 0,
      servingTeam: nextServerTeam,
      servingRotationIndex: nextRotIndex,
      tieBreakInitialRotationIndex: nextRotIndex,
      lastEventMessage: 'Tie-break!',
    };

    return {
      nextSnapshot,
      event: {
        type: 'tieBreakStarted',
        scoringTeam: winner,
        winner,
        finalGamesA: 6,
        finalGamesB: 6,
        serverPlayerId: nextServerPlayerId,
        servingTeam: nextServerTeam,
        rawPointsA: 0,
        rawPointsB: 0,
      },
    };
  }

  // Controllo vittoria set (6 con 2 di scarto, oppure 7-5)
  const wonA = gA >= 6 && gA - gB >= 2;
  const wonB = gB >= 6 && gB - gA >= 2;

  if (wonA || wonB) {
    return processSetWin(current, wonA ? 'teamA' : 'teamB', gA, gB, settings);
  }

  // Game ordinario concluso
  const winnerName = winner === 'teamA' ? settings.teamAName : settings.teamBName;
  const nextSnapshot: PadelMatchSnapshot = {
    ...current,
    rawPointsA: 0,
    rawPointsB: 0,
    deuceCount: 0,
    currentGamesA: gA,
    currentGamesB: gB,
    servingTeam: nextServerTeam,
    servingRotationIndex: nextRotIndex,
    lastEventMessage: `Game ${winnerName}`,
  };

  return {
    nextSnapshot,
    event: {
      type: 'gameWon',
      scoringTeam: winner,
      winner,
      finalGamesA: gA,
      finalGamesB: gB,
      serverPlayerId: nextServerPlayerId,
      servingTeam: nextServerTeam,
      rawPointsA: 0,
      rawPointsB: 0,
    },
  };
}

/**
 * Gestione della vittoria del set secondo le regole FIP 2026.
 *
 * REGOLA FIP SERVIZIO NEL SET SUCCESSIVO:
 * 1. Se il set si è concluso senza tie-break (es. 6-4 o 6-3 o 7-5):
 *    L'alternanza naturale dei game prosegue regolarmente!
 *    - Se sono stati giocati 10 game (es. 6-4), il 10° game è stato servito dalla Squadra B.
 *      Il 1° game del set 2 tocca alla Squadra A (nextRotIndex = 10, che appartiene a Squadra A).
 *    - Se sono stati giocati 9 game (es. 6-3), il 9° game è stato servito dalla Squadra A.
 *      Il 1° game del set 2 tocca alla Squadra B (nextRotIndex = 9, che appartiene a Squadra B).
 *
 * 2. Se il set si è concluso al tie-break (7-6):
 *    La coppia che ha iniziato a servire nel tie-break riceverà nel primo game del set successivo.
 *    Quindi il servizio del 1° game del nuovo set va alla coppia opposta a quella che ha iniziato il tie-break!
 */
function processSetWin(
  current: PadelMatchSnapshot,
  setWinner: Team,
  finalGA: number,
  finalGB: number,
  settings: MatchSettings,
  tbA?: number,
  tbB?: number
): ScoringResult {
  const completedSet: SetScore = {
    gamesA: finalGA,
    gamesB: finalGB,
    tieBreakPointsA: tbA,
    tieBreakPointsB: tbB,
    isCompleted: true,
    winner: setWinner,
  };

  const updatedSets = [...current.completedSets, completedSet];
  const setNumber = updatedSets.length;
  const setsWonA = updatedSets.filter(s => s.winner === 'teamA').length;
  const setsWonB = updatedSets.filter(s => s.winner === 'teamB').length;
  const setsToWin = Math.ceil(settings.bestOfSets / 2);

  let matchWinner: Team | undefined = undefined;
  if (setsWonA >= setsToWin) matchWinner = 'teamA';
  else if (setsWonB >= setsToWin) matchWinner = 'teamB';

  const firstServerId = settings.firstServerPlayerId || 1;
  const rotation = getRotationOrder(firstServerId);

  let nextRotIndex: number;
  let nextServerPlayerId: PlayerId;
  let nextSetServerTeam: Team;

  if (current.isTieBreak) {
    // Caso Tie-Break:
    // Chi ha iniziato a servire nel tie-break deve RICEVERE nel 1° game del nuovo set.
    // Il battitore iniziale del tie-break era a tieBreakInitialRotationIndex.
    // Il primo servitore del set successivo è il giocatore della squadra opposta che segue nella rotazione.
    const tbStartRot = current.tieBreakInitialRotationIndex ?? current.servingRotationIndex;
    nextRotIndex = tbStartRot + 1;
    nextServerPlayerId = rotation[nextRotIndex % rotation.length];
    nextSetServerTeam = getTeamForPlayerId(nextServerPlayerId);
  } else {
    // Caso Set regolare (senza tie-break):
    // La sequenza dei game prosegue con la naturale alternanza!
    nextRotIndex = current.servingRotationIndex + 1;
    nextServerPlayerId = rotation[nextRotIndex % rotation.length];
    nextSetServerTeam = getTeamForPlayerId(nextServerPlayerId);
  }

  const setWinnerName = setWinner === 'teamA' ? settings.teamAName : settings.teamBName;
  const nextSnapshot: PadelMatchSnapshot = {
    ...current,
    rawPointsA: 0,
    rawPointsB: 0,
    deuceCount: 0,
    currentGamesA: 0,
    currentGamesB: 0,
    completedSets: updatedSets,
    servingTeam: nextSetServerTeam,
    servingRotationIndex: nextRotIndex,
    initialSetServer: nextSetServerTeam,
    isTieBreak: false,
    tieBreakPointsA: 0,
    tieBreakPointsB: 0,
    tieBreakInitialRotationIndex: undefined,
    matchWinner,
    lastEventMessage: matchWinner ? `Partita vinta da ${setWinnerName}!` : `Set vinto da ${setWinnerName}`,
  };

  const isMatchOver = matchWinner !== undefined;

  return {
    nextSnapshot,
    event: {
      type: isMatchOver ? 'matchWon' : 'setWon',
      scoringTeam: setWinner,
      winner: isMatchOver ? matchWinner : setWinner,
      setNumber,
      finalGamesA: finalGA,
      finalGamesB: finalGB,
      tieBreakPointsA: tbA,
      tieBreakPointsB: tbB,
      setsWonA,
      setsWonB,
      serverPlayerId: nextServerPlayerId,
      servingTeam: nextSetServerTeam,
      rawPointsA: 0,
      rawPointsB: 0,
    },
  };
}

/**
 * Consente opzionalmente a inizio set di impostare un battitore specifico
 * tra i due giocatori della squadra a cui spetta il servizio.
 * Predispone la logica per future schermate o comandi esterni (es. smartwatch).
 */
export function setStartOfSetServer(
  snapshot: PadelMatchSnapshot,
  chosenPlayerId: PlayerId,
  firstServerPlayerId: number = 1
): PadelMatchSnapshot {
  const chosenTeam = getTeamForPlayerId(chosenPlayerId);
  // Il giocatore scelto deve appartenere alla squadra che deve servire
  if (chosenTeam !== snapshot.servingTeam) {
    return snapshot;
  }

  const rotation = getRotationOrder(firstServerPlayerId);
  // Trova l'indice della rotazione associato al giocatore scelto che rispetta il ciclo
  let newRotIndex = snapshot.servingRotationIndex;
  while (rotation[newRotIndex % rotation.length] !== chosenPlayerId) {
    newRotIndex += 2; // Salta di 2 per rimanere nella stessa squadra
  }

  return {
    ...snapshot,
    servingRotationIndex: newRotIndex,
  };
}
