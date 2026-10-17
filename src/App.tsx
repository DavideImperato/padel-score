import React, { useState, useEffect, useRef, useCallback } from 'react';
import { PadelMatchSnapshot, SetScore, MatchSettings, Team } from './types/padel';
import { padelAudio } from './utils/padelAudio';
import { BluetoothKeyListener } from './utils/bluetoothListener';
import { TeamColumn } from './components/TeamColumn';
import { CentralScoreboardColumn } from './components/CentralScoreboardColumn';
import { MatchInfoModal } from './components/MatchInfoModal';
import { SettingsModal } from './components/SettingsModal';
import { RemoteHelperModal } from './components/RemoteHelperModal';
import { MatchSetupScreen } from './components/MatchSetupScreen';
import { MatchSummaryScreen } from './components/MatchSummaryScreen';
import { ResetConfirmModal } from './components/ResetConfirmModal';
import { TerminateConfirmModal } from './components/TerminateConfirmModal';
import { LandscapeEnforcer } from './components/LandscapeEnforcer';
import { SmartwatchScoreboard } from './components/SmartwatchScoreboard';
import { Trophy, Sparkles, Hourglass, Play } from 'lucide-react';

const INITIAL_SNAPSHOT: PadelMatchSnapshot = {
  rawPointsA: 0,
  rawPointsB: 0,
  currentGamesA: 0,
  currentGamesB: 0,
  completedSets: [],
  servingTeam: 'teamA',
  servingRotationIndex: 0,
  initialSetServer: 'teamA',
  isTieBreak: false,
  tieBreakPointsA: 0,
  tieBreakPointsB: 0,
  deuceCount: 0,
  lastEventMessage: 'Inizio Partita',
};

const DEFAULT_SETTINGS: MatchSettings = {
  teamAName: 'Gli Smashtori',
  teamBName: 'I Timemasters',
  player1Name: 'Mario Rossi',
  player2Name: 'Luigi Verdi',
  player3Name: 'Paolo Bianchi',
  player4Name: 'Marco Neri',
  firstServerPlayerId: 1,
  isGoldenPoint: true,
  advantagesBeforeGoldenPoint: 0,
  bestOfSets: 3,
  ttsSpeed: 0.95, // Cadenza arbitrale naturale
  ttsVolume: 1.0,
  isMuted: false,
  isVoiceMuted: false,
  isSfxMuted: false,
};

export default function App() {
  // Schermata: 'setup' (default per "/"), 'scoreboard', o 'summary' (riepilogo finale)
  const [currentView, setCurrentView] = useState<'setup' | 'scoreboard' | 'summary'>('setup');

  const [snapshot, setSnapshot] = useState<PadelMatchSnapshot>(INITIAL_SNAPSHOT);
  const [history, setHistory] = useState<PadelMatchSnapshot[]>([]);
  const [settings, setSettings] = useState<MatchSettings>(() => {
    try {
      const saved = localStorage.getItem('padel_settings_v3');
      if (saved) {
        const parsed = JSON.parse(saved);
        return {
          ...DEFAULT_SETTINGS,
          ...parsed,
          isVoiceMuted: parsed.isVoiceMuted ?? false,
          isSfxMuted: parsed.isSfxMuted ?? false,
          advantagesBeforeGoldenPoint: parsed.advantagesBeforeGoldenPoint ?? 0,
        };
      }
    } catch {}
    return DEFAULT_SETTINGS;
  });

  // Modal di reset personalizzata (elimina window.confirm bloccato in iframe)
  const [isResetConfirmOpen, setIsResetConfirmOpen] = useState(false);

  // Modal Info Match
  const [isMatchInfoOpen, setIsMatchInfoOpen] = useState(false);

  // Timers: Match duration & Change of Ends (Cambio Campo)
  const [matchSeconds, setMatchSeconds] = useState(0);
  const [isTimerRunning, setIsTimerRunning] = useState(true);

  const [breakSecondsLeft, setBreakSecondsLeft] = useState(0);
  const [isBreakActive, setIsBreakActive] = useState(false);

  // Screen Wake Lock (schermo sempre attivo a bordo campo)
  const [isWakeLockActive, setIsWakeLockActive] = useState(false);

  // Fullscreen & Modals
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isRemoteHelperOpen, setIsRemoteHelperOpen] = useState(false);
  const [isTerminateModalOpen, setIsTerminateModalOpen] = useState(false);
  const [isSmartwatchMode, setIsSmartwatchMode] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return (window.innerWidth <= 330 && window.innerHeight <= 380) || (window.innerWidth <= 380 && window.innerHeight <= 330);
  });
  const [lastLogs, setLastLogs] = useState<Array<{ text: string; time: string; type: 'up1' | 'up2' | 'down' | 'other' }>>([]);

  // Auto-detect Smartwatch screen resize
  useEffect(() => {
    const handleCheckWatch = () => {
      const isWatch = (window.innerWidth <= 330 && window.innerHeight <= 380) || (window.innerWidth <= 380 && window.innerHeight <= 330);
      if (isWatch) {
        setIsSmartwatchMode(true);
      }
    };
    window.addEventListener('resize', handleCheckWatch);
    return () => window.removeEventListener('resize', handleCheckWatch);
  }, []);

  // Sincronizzazione impostazioni audio (Voce e Effetti Sonori)
  useEffect(() => {
    padelAudio.setVoiceMuted(settings.isVoiceMuted ?? false);
    padelAudio.setSfxMuted(settings.isSfxMuted ?? false);
    padelAudio.setSpeed(settings.ttsSpeed ?? 0.95);
  }, [settings.isVoiceMuted, settings.isSfxMuted, settings.ttsSpeed]);

  // Sblocca audio e sintesi vocale alla prima interazione dell'utente (policy mobile / Chrome)
  useEffect(() => {
    const handleUnlock = () => {
      padelAudio.unlockAudio();
    };
    window.addEventListener('click', handleUnlock, { once: true });
    window.addEventListener('touchstart', handleUnlock, { once: true });
    window.addEventListener('keydown', handleUnlock, { once: true });
    return () => {
      window.removeEventListener('click', handleUnlock);
      window.removeEventListener('touchstart', handleUnlock);
      window.removeEventListener('keydown', handleUnlock);
    };
  }, []);

  // Match Duration stopwatch
  useEffect(() => {
    if (!isTimerRunning || currentView !== 'scoreboard') return;
    const interval = setInterval(() => {
      setMatchSeconds(s => s + 1);
    }, 1000);
    return () => clearInterval(interval);
  }, [isTimerRunning, currentView]);

  // Break Countdown interval
  useEffect(() => {
    if (!isBreakActive || breakSecondsLeft <= 0 || currentView !== 'scoreboard') return;
    const interval = setInterval(() => {
      setBreakSecondsLeft(prev => {
        if (prev <= 1) {
          setIsBreakActive(false);
          padelAudio.playCourtBeep('game');
          padelAudio.speak('Tempo scaduto, riprendere il gioco!');
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [isBreakActive, breakSecondsLeft, currentView]);

  // Screen Wake Lock
  useEffect(() => {
    let wakeLockSentinel: any = null;

    const requestWakeLock = async () => {
      if ('wakeLock' in navigator) {
        try {
          wakeLockSentinel = await (navigator as any).wakeLock.request('screen');
          setIsWakeLockActive(true);
          wakeLockSentinel.addEventListener('release', () => {
            setIsWakeLockActive(false);
          });
        } catch {
          setIsWakeLockActive(false);
        }
      }
    };

    requestWakeLock();

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        requestWakeLock();
      }
    };

    document.addEventListener('visibilitychange', handleVisibility);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibility);
      if (wakeLockSentinel) wakeLockSentinel.release().catch(() => {});
    };
  }, []);

  // Compute 4-player rotation sequence based on firstServerPlayerId
  const getRotationOrder = useCallback((): string[] => {
    const { player1Name, player2Name, player3Name, player4Name, firstServerPlayerId } = settings;
    switch (firstServerPlayerId) {
      case 1: return [player1Name, player3Name, player2Name, player4Name];
      case 2: return [player2Name, player3Name, player1Name, player4Name];
      case 3: return [player3Name, player1Name, player4Name, player2Name];
      case 4: return [player4Name, player1Name, player3Name, player2Name];
      default: return [player1Name, player3Name, player2Name, player4Name];
    }
  }, [settings]);

  // Get current serving player's name
  const getCurrentServingPlayer = useCallback((): string => {
    const rotation = getRotationOrder();
    if (rotation.length === 0) return settings.player1Name;

    if (snapshot.isTieBreak) {
      const initialIdx = snapshot.tieBreakInitialRotationIndex ?? snapshot.servingRotationIndex;
      const totalPoints = snapshot.tieBreakPointsA + snapshot.tieBreakPointsB;
      const shift = totalPoints === 0 ? 0 : Math.floor((totalPoints + 1) / 2);
      return rotation[(initialIdx + shift) % rotation.length];
    }

    return rotation[snapshot.servingRotationIndex % rotation.length];
  }, [getRotationOrder, settings.player1Name, snapshot]);

  const formatMatchTime = (totalSeconds: number): string => {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  };

  const triggerHaptic = (pattern: number | number[] = 25) => {
    if (typeof window !== 'undefined' && 'vibrate' in navigator) {
      try {
        navigator.vibrate(pattern);
      } catch {}
    }
  };

  const addLog = useCallback((text: string, type: 'up1' | 'up2' | 'down' | 'other') => {
    const time = new Date().toLocaleTimeString('it-IT', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
    setLastLogs(prev => [{ text, time, type }, ...prev.slice(0, 19)]);
  }, []);

  const getTeamName = useCallback((team: Team): string => {
    return team === 'teamA' ? settings.teamAName : settings.teamBName;
  }, [settings.teamAName, settings.teamBName]);

  const getPointLabel = (rawPoint: number): string => {
    switch (rawPoint) {
      case 0: return '0';
      case 1: return '15';
      case 2: return '30';
      case 3: return '40';
      case 4: return 'AV';
      default: return '0';
    }
  };

  const getPointWordItalian = (rawPoint: number): string => {
    switch (rawPoint) {
      case 0: return 'Zero';
      case 1: return 'Quindici';
      case 2: return 'Trenta';
      case 3: return 'Quaranta';
      default: return 'Zero';
    }
  };

  // =========================================================================
  // SCORING LOGIC
  // =========================================================================

  const addPoint = useCallback((scoringTeam: Team) => {
    if (currentView !== 'scoreboard') return;

    padelAudio.unlockAudio();

    setSnapshot(current => {
      if (current.matchWinner) return current;

      setHistory(h => [...h, current]);
      triggerHaptic(30);

      // --- TIE-BREAK ---
      if (current.isTieBreak) {
        let tbA = current.tieBreakPointsA;
        let tbB = current.tieBreakPointsB;

        if (scoringTeam === 'teamA') tbA++;
        else tbB++;

        const totalPoints = tbA + tbB;

        const wonA = tbA >= 7 && tbA - tbB >= 2;
        const wonB = tbB >= 7 && tbB - tbA >= 2;

        if (wonA || wonB) {
          const setWinner: Team = wonA ? 'teamA' : 'teamB';
          const nextRot = (current.tieBreakInitialRotationIndex ?? current.servingRotationIndex) + 1;
          return winSet(current, setWinner, wonA ? 7 : 6, wonB ? 7 : 6, nextRot, tbA, tbB);
        }

        const initialIdx = current.tieBreakInitialRotationIndex ?? current.servingRotationIndex;
        const shift = Math.floor((totalPoints + 1) / 2);
        const nextRot = initialIdx + shift;
        const rotation = getRotationOrder();
        const nextServerPlayer = rotation[nextRot % rotation.length];
        const isTeamA = nextServerPlayer === settings.player1Name || nextServerPlayer === settings.player2Name;
        const nextServerTeam: Team = isTeamA ? 'teamA' : 'teamB';
        const nextServerTeamName = nextServerTeam === 'teamA' ? settings.teamAName : settings.teamBName;

        padelAudio.speak(`${tbA} a ${tbB}, servizio ${nextServerTeamName}.`);

        return {
          ...current,
          tieBreakPointsA: tbA,
          tieBreakPointsB: tbB,
          servingTeam: nextServerTeam,
          lastEventMessage: `Tie-break ${tbA} - ${tbB}`,
        };
      }

      // --- STANDARD GAME ---
      let pA = current.rawPointsA;
      let pB = current.rawPointsB;
      const deuceCount = current.deuceCount ?? 0;
      const isGoldenPointNow =
        settings.isGoldenPoint &&
        pA === 3 &&
        pB === 3 &&
        deuceCount >= (settings.advantagesBeforeGoldenPoint ?? 0);

      if (scoringTeam === 'teamA') {
        if (pA < 3) {
          pA++;
          return commitPoint(current, pA, pB, deuceCount);
        } else if (pA === 3 && pB < 3) {
          return winGame(current, 'teamA');
        } else if (pA === 3 && pB === 3) {
          if (isGoldenPointNow) {
            return winGame(current, 'teamA');
          } else {
            pA = 4;
            return commitPoint(current, pA, pB, deuceCount);
          }
        } else if (pA === 4 && pB === 3) {
          return winGame(current, 'teamA');
        } else if (pA === 3 && pB === 4) {
          pB = 3;
          const nextDeuceCount = deuceCount + 1;
          return commitPoint(current, pA, pB, nextDeuceCount);
        }
      } else {
        if (pB < 3) {
          pB++;
          return commitPoint(current, pA, pB, deuceCount);
        } else if (pB === 3 && pA < 3) {
          return winGame(current, 'teamB');
        } else if (pA === 3 && pB === 3) {
          if (isGoldenPointNow) {
            return winGame(current, 'teamB');
          } else {
            pB = 4;
            return commitPoint(current, pA, pB, deuceCount);
          }
        } else if (pB === 4 && pA === 3) {
          return winGame(current, 'teamB');
        } else if (pB === 3 && pA === 4) {
          pA = 3;
          const nextDeuceCount = deuceCount + 1;
          return commitPoint(current, pA, pB, nextDeuceCount);
        }
      }

      return current;
    });
  }, [settings, getRotationOrder, currentView]);

  const commitPoint = (
    current: PadelMatchSnapshot,
    newPA: number,
    newPB: number,
    newDeuceCount: number = 0
  ): PadelMatchSnapshot => {
    const rotation = getRotationOrder();
    const serverPlayer = rotation[current.servingRotationIndex % rotation.length];
    const servingTeamName = current.servingTeam === 'teamA' ? settings.teamAName : settings.teamBName;

    // ANNUNCIO AUTOMATICO IMMEDIATO (SYNCHRONOUS CALL)
    if (newPA === newPB) {
      if (newPA === 0) {
        padelAudio.speak(`0 pari, servizio ${servingTeamName}, batte ${serverPlayer}.`);
      } else if (newPA === 1) {
        padelAudio.speak(`15 pari, servizio ${servingTeamName}, batte ${serverPlayer}.`);
      } else if (newPA === 2) {
        padelAudio.speak(`30 pari, servizio ${servingTeamName}, batte ${serverPlayer}.`);
      } else if (newPA === 3) {
        const isGoldenNow =
          settings.isGoldenPoint &&
          newDeuceCount >= (settings.advantagesBeforeGoldenPoint ?? 0);

        if (isGoldenNow) {
          padelAudio.speak("40 pari, Punto d'Oro!");
        } else {
          padelAudio.speak(`40 pari, servizio ${servingTeamName}, batte ${serverPlayer}.`);
        }
      }
    } else if (newPA === 4) {
      padelAudio.speak(`Vantaggio ${settings.teamAName}, servizio ${servingTeamName}, batte ${serverPlayer}.`);
    } else if (newPB === 4) {
      padelAudio.speak(`Vantaggio ${settings.teamBName}, servizio ${servingTeamName}, batte ${serverPlayer}.`);
    } else {
      const scoreA = getPointLabel(newPA);
      const scoreB = getPointLabel(newPB);
      padelAudio.speak(`${scoreA} - ${scoreB}, servizio ${servingTeamName}, batte ${serverPlayer}.`);
    }

    return {
      ...current,
      rawPointsA: newPA,
      rawPointsB: newPB,
      deuceCount: newDeuceCount,
      lastEventMessage: `Punto assegnato`,
    };
  };

  const winGame = (current: PadelMatchSnapshot, winner: Team): PadelMatchSnapshot => {
    triggerHaptic([60, 40, 60]);

    let gA = current.currentGamesA;
    let gB = current.currentGamesB;
    if (winner === 'teamA') gA++;
    else gB++;

    const nextRotIndex = current.servingRotationIndex + 1;
    const rotation = getRotationOrder();
    const nextServerPlayer = rotation[nextRotIndex % rotation.length];
    const isTeamA = nextServerPlayer === settings.player1Name || nextServerPlayer === settings.player2Name;
    const nextServerTeam: Team = isTeamA ? 'teamA' : 'teamB';
    const winnerName = winner === 'teamA' ? settings.teamAName : settings.teamBName;

    if (gA === 6 && gB === 6) {
      padelAudio.speak(`Sei pari. Tie-break. Serve ${nextServerPlayer}.`);
      return {
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
    }

    const wonA = gA >= 6 && gA - gB >= 2;
    const wonB = gB >= 6 && gB - gA >= 2;

    if (wonA || wonB) {
      return winSet(current, wonA ? 'teamA' : 'teamB', gA, gB, nextRotIndex);
    }

    padelAudio.speak(`Vince Game ${winnerName}.`);

    return {
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
  };

  const winSet = (
    current: PadelMatchSnapshot,
    setWinner: Team,
    finalGA: number,
    finalGB: number,
    nextRotIndex: number,
    tbA?: number,
    tbB?: number
  ): PadelMatchSnapshot => {
    triggerHaptic([100, 50, 100, 50, 100]);
    padelAudio.playCourtBeep('game');

    const completedSet: SetScore = {
      gamesA: finalGA,
      gamesB: finalGB,
      tieBreakPointsA: tbA,
      tieBreakPointsB: tbB,
      isCompleted: true,
      winner: setWinner,
    };

    const updatedSets = [...current.completedSets, completedSet];
    const setNum = updatedSets.length;

    const setsWonA = updatedSets.filter(s => s.winner === 'teamA').length;
    const setsWonB = updatedSets.filter(s => s.winner === 'teamB').length;
    const setsToWin = Math.ceil(settings.bestOfSets / 2);

    let matchWinner: Team | undefined = undefined;
    if (setsWonA >= setsToWin) matchWinner = 'teamA';
    else if (setsWonB >= setsToWin) matchWinner = 'teamB';

    const nextSetServerTeam: Team = current.initialSetServer === 'teamA' ? 'teamB' : 'teamA';
    const setWinnerName = setWinner === 'teamA' ? settings.teamAName : settings.teamBName;

    const setOrdinal = setNum === 1 ? 'primo' : (setNum === 2 ? 'secondo' : (setNum === 3 ? 'terzo' : (setNum === 4 ? 'quarto' : 'quinto')));
    if (matchWinner) {
      const matchWinnerName = matchWinner === 'teamA' ? settings.teamAName : settings.teamBName;
      padelAudio.speak(`Vince Game, Set e Partita la squadra ${matchWinnerName}!`);
      setIsTimerRunning(false);
      setTimeout(() => {
        setCurrentView('summary');
      }, 2500);
    } else {
      padelAudio.speak(`Vince Game e ${setOrdinal} Set la squadra ${setWinnerName}.`);
      startBreakTimer(120);
    }

    return {
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
  };

  const startBreakTimer = (duration: number = 90) => {
    triggerHaptic(50);
    setBreakSecondsLeft(duration);
    setIsBreakActive(true);
    padelAudio.speak(`Pausa cambio campo di ${duration} secondi.`);
  };

  const stopBreakTimer = () => {
    setIsBreakActive(false);
    setBreakSecondsLeft(0);
  };

  const handleUndo = useCallback(() => {
    if (history.length === 0) return;
    triggerHaptic(20);
    padelAudio.unlockAudio();
    const prevSnapshot = history[history.length - 1];
    setHistory(h => h.slice(0, -1));
    setSnapshot(prevSnapshot);
    padelAudio.speak('Punto annullato.');
  }, [history]);

  // RESET FUNCTIONALITY (In-app confirmation without window.confirm!)
  const handleOpenResetDialog = useCallback(() => {
    setIsResetConfirmOpen(true);
  }, []);

  const handleConfirmReset = useCallback(() => {
    triggerHaptic(50);
    padelAudio.unlockAudio();
    setHistory([]);
    setSnapshot(INITIAL_SNAPSHOT);
    setMatchSeconds(0);
    setIsBreakActive(false);
    const server = getCurrentServingPlayer();
    padelAudio.speak(`Partita resettata. Serve ${server}.`);
  }, [getCurrentServingPlayer]);

  const handleResetAndGoToSetup = useCallback(() => {
    triggerHaptic(50);
    padelAudio.unlockAudio();
    setHistory([]);
    setSnapshot(INITIAL_SNAPSHOT);
    setMatchSeconds(0);
    setIsBreakActive(false);
    setCurrentView('setup');
    padelAudio.speak('Partita azzerata. Nuova configurazione match.');
  }, []);

  const handleTerminateMatch = useCallback(() => {
    setIsTimerRunning(false);
    triggerHaptic([80, 40, 80]);
    padelAudio.unlockAudio();
    padelAudio.speak('Partita conclusa. Visualizzazione del riepilogo finale.');
    setCurrentView('summary');
  }, []);

  const handleToggleServingTeam = useCallback(() => {
    setSnapshot(current => {
      setHistory(h => [...h, current]);
      const nextRot = current.servingRotationIndex + 1;
      const rotation = getRotationOrder();
      const nextPlayer = rotation[nextRot % rotation.length];
      const isTeamA = nextPlayer === settings.player1Name || nextPlayer === settings.player2Name;
      padelAudio.speak(`Cambio battitore. Serve ${nextPlayer}.`);
      return {
        ...current,
        servingTeam: isTeamA ? 'teamA' : 'teamB',
        servingRotationIndex: nextRot,
      };
    });
  }, [getRotationOrder, settings.player1Name, settings.player2Name]);

  const handleSwitchSides = useCallback(() => {
    setSnapshot(prev => {
      setHistory(h => [...h, prev]);
      padelAudio.speak('Cambio campo.');
      return {
        ...prev,
        rawPointsA: prev.rawPointsB,
        rawPointsB: prev.rawPointsA,
        currentGamesA: prev.currentGamesB,
        currentGamesB: prev.currentGamesA,
        completedSets: prev.completedSets.map(s => ({
          gamesA: s.gamesB,
          gamesB: s.gamesA,
          tieBreakPointsA: s.tieBreakPointsB,
          tieBreakPointsB: s.tieBreakPointsA,
          isCompleted: s.isCompleted,
          winner: s.winner === 'teamA' ? 'teamB' : (s.winner === 'teamB' ? 'teamA' : undefined),
        })),
        servingTeam: prev.servingTeam === 'teamA' ? 'teamB' : 'teamA',
        servingRotationIndex: prev.servingRotationIndex,
        initialSetServer: prev.initialSetServer === 'teamA' ? 'teamB' : 'teamA',
        tieBreakPointsA: prev.tieBreakPointsB,
        tieBreakPointsB: prev.tieBreakPointsA,
        matchWinner: prev.matchWinner === 'teamA' ? 'teamB' : (prev.matchWinner === 'teamB' ? 'teamA' : undefined),
        lastEventMessage: 'Cambio campo',
      };
    });

    setSettings(prev => ({
      ...prev,
      teamAName: prev.teamBName,
      teamBName: prev.teamAName,
      player1Name: prev.player3Name,
      player2Name: prev.player4Name,
      player3Name: prev.player1Name,
      player4Name: prev.player2Name,
    }));

    startBreakTimer(90);
  }, []);

  const handleToggleMute = useCallback(() => {
    setSettings(prev => {
      const nextMuted = !(prev.isVoiceMuted && prev.isSfxMuted);
      padelAudio.setMuted(nextMuted);
      return {
        ...prev,
        isMuted: nextMuted,
        isVoiceMuted: nextMuted,
        isSfxMuted: nextMuted,
      };
    });
  }, []);

  const handleToggleGoldenPoint = useCallback(() => {
    setSettings(prev => {
      const next = !prev.isGoldenPoint;
      padelAudio.speak(next ? "Punto d'oro attivato." : 'Vantaggi tradizionali attivati.');
      return { ...prev, isGoldenPoint: next };
    });
  }, []);

  const handleToggleFullscreen = useCallback(() => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().then(() => {
        setIsFullscreen(true);
        try {
          (screen.orientation as { lock?: (orientation: string) => Promise<void> })?.lock?.('landscape').catch(() => {});
        } catch {}
      }).catch(() => {});
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false)).catch(() => {});
    }
  }, []);

  // START MATCH FROM SETUP SCREEN
  const handleStartMatchFromSetup = (newSettings: MatchSettings) => {
    setSettings(newSettings);
    try {
      localStorage.setItem('padel_settings_v3', JSON.stringify(newSettings));
    } catch {}

    const initialTeam: Team = (newSettings.firstServerPlayerId === 1 || newSettings.firstServerPlayerId === 2)
      ? 'teamA'
      : 'teamB';

    setHistory([]);
    setSnapshot({
      ...INITIAL_SNAPSHOT,
      servingTeam: initialTeam,
      servingRotationIndex: 0,
      initialSetServer: initialTeam,
    });
    setMatchSeconds(0);
    setIsBreakActive(false);

    // Switch screen to scoreboard!
    setCurrentView('scoreboard');

    // Annuncio arbitrale con applauso del pubblico in sottofondo
    const firstServer = (newSettings.firstServerPlayerId === 1)
      ? newSettings.player1Name
      : (newSettings.firstServerPlayerId === 2)
      ? newSettings.player2Name
      : (newSettings.firstServerPlayerId === 3)
      ? newSettings.player3Name
      : newSettings.player4Name;

    const initialTeamName = initialTeam === 'teamA' ? newSettings.teamAName : newSettings.teamBName;

    padelAudio.unlockAudio();
    padelAudio.speak(
      `Inizia la sfida tra ${newSettings.teamAName}, con ${newSettings.player1Name} e ${newSettings.player2Name}, e ${newSettings.teamBName}, con ${newSettings.player3Name} e ${newSettings.player4Name}. Servizio per la squadra ${initialTeamName}, batte ${firstServer}. Buon match!`
    );
  };

  // Bluetooth key listener
  const keyListenerRef = useRef<BluetoothKeyListener | null>(null);

  useEffect(() => {
    const listener = new BluetoothKeyListener({
      onTeamA: () => addPoint('teamA'),
      onTeamB: () => addPoint('teamB'),
      onUndo: () => handleUndo(),
      onLog: (msg, type) => addLog(msg, type),
    });
    listener.start();
    keyListenerRef.current = listener;

    return () => {
      listener.stop();
    };
  }, [addPoint, handleUndo, addLog]);

  useEffect(() => {
    if (keyListenerRef.current) {
      keyListenerRef.current.updateCallbacks({
        onTeamA: () => addPoint('teamA'),
        onTeamB: () => addPoint('teamB'),
        onUndo: () => handleUndo(),
        onLog: (msg, type) => addLog(msg, type),
      });
    }
  }, [addPoint, handleUndo, addLog]);

  useEffect(() => {
    const handleFsChange = () => {
      setIsFullscreen(Boolean(document.fullscreenElement));
    };
    document.addEventListener('fullscreenchange', handleFsChange);
    return () => document.removeEventListener('fullscreenchange', handleFsChange);
  }, []);

  const isDeuce = !snapshot.isTieBreak && snapshot.rawPointsA === 3 && snapshot.rawPointsB === 3;
  const isGoldenPointSituation =
    isDeuce &&
    settings.isGoldenPoint &&
    (snapshot.deuceCount ?? 0) >= (settings.advantagesBeforeGoldenPoint ?? 0);
  const currentServingPlayer = getCurrentServingPlayer();
  const isMatchInProgress = snapshot.completedSets.length > 0 || snapshot.currentGamesA > 0 || snapshot.currentGamesB > 0 || snapshot.rawPointsA > 0 || snapshot.rawPointsB > 0;

  // RENDER 1: SCHERMATA INIZIALE SETUP MATCH COME VISTA PRINCIPALE ("/")
  if (currentView === 'setup') {
    return (
      <>
        <MatchSetupScreen
          currentSettings={settings}
          onStartMatch={handleStartMatchFromSetup}
          onGoToScoreboard={() => setCurrentView('scoreboard')}
          isMatchInProgress={isMatchInProgress}
          onOpenRemoteHelper={() => setIsRemoteHelperOpen(true)}
        />

        <RemoteHelperModal
          isOpen={isRemoteHelperOpen}
          onClose={() => setIsRemoteHelperOpen(false)}
          onSimulateVolUpSingle={() => addPoint('teamA')}
          onSimulateVolUpDouble={() => addPoint('teamB')}
          onSimulateVolDown={handleUndo}
          lastLogs={lastLogs}
        />
      </>
    );
  }

  // RENDER 2: SCHERMATA DI RIEPILOGO FINALE (MATCH RESULT)
  if (currentView === 'summary') {
    return (
      <MatchSummaryScreen
        snapshot={snapshot}
        settings={settings}
        matchDurationFormatted={formatMatchTime(matchSeconds)}
        onGoToSetup={() => {
          setHistory([]);
          setSnapshot(INITIAL_SNAPSHOT);
          setMatchSeconds(0);
          setCurrentView('setup');
        }}
        onReturnToScoreboard={() => setCurrentView('scoreboard')}
      />
    );
  }

  // RENDER 3: SMARTWATCH SCOREBOARD (Apple Watch & Wear OS)
  if (currentView === 'scoreboard' && isSmartwatchMode) {
    return (
      <SmartwatchScoreboard
        snapshot={snapshot}
        settings={settings}
        canUndo={history.length > 0}
        matchTimeFormatted={formatMatchTime(matchSeconds)}
        isTimerRunning={isTimerRunning}
        servingPlayerName={currentServingPlayer}
        onAddPoint={addPoint}
        onUndo={handleUndo}
        onToggleServingTeam={handleToggleServingTeam}
        onStartBreak={() => startBreakTimer(90)}
        onExitSmartwatchMode={() => setIsSmartwatchMode(false)}
      />
    );
  }

  // RENDER 4: TABELLONE SEGNAPUNTI ORIZZONTALE (LANDSCAPE SCOREBOARD)
  return (
    <div className="relative w-full h-screen bg-[#070B14] text-white flex flex-col overflow-hidden select-none font-sans">
      <LandscapeEnforcer />

      {/* MATCH NOTIFICATION OVERLAY */}
      {snapshot.matchWinner && (
        <div className="absolute top-3 left-0 right-0 z-30 flex justify-center px-4 animate-in fade-in slide-in-from-top-4 duration-300 pointer-events-auto">
          <div className="px-6 py-2.5 rounded-2xl bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-600 text-white font-black text-sm sm:text-base tracking-widest uppercase shadow-2xl shadow-emerald-500/50 flex items-center gap-3 border border-emerald-300/40">
            <Trophy className="w-5 h-5 text-amber-300" />
            <span>PARTITA VINTA DA {getTeamName(snapshot.matchWinner).toUpperCase()}!</span>
            <button
              onClick={() => setCurrentView('setup')}
              className="ml-3 px-3 py-1 rounded-lg bg-black/40 hover:bg-black/60 text-xs font-bold transition-colors cursor-pointer"
            >
              Nuova Partita
            </button>
          </div>
        </div>
      )}

      {isGoldenPointSituation && !snapshot.matchWinner && (
        <div className="absolute top-3 left-0 right-0 z-30 flex justify-center px-4 animate-pulse pointer-events-none">
          <div className="px-6 py-1.5 rounded-xl bg-rose-600 text-white font-black text-xs sm:text-sm tracking-widest uppercase shadow-xl shadow-rose-600/40 flex items-center gap-2 border border-rose-400">
            <Sparkles className="w-4 h-4 text-amber-300" />
            <span>40 PARI — PUNTO D'ORO DECISIVO!</span>
          </div>
        </div>
      )}

      {snapshot.isTieBreak && !snapshot.matchWinner && (
        <div className="absolute top-3 left-0 right-0 z-30 flex justify-center px-4 pointer-events-none">
          <div className="px-6 py-1.5 rounded-xl bg-purple-600 text-white font-black text-xs sm:text-sm tracking-widest uppercase shadow-xl shadow-purple-600/40 flex items-center gap-2 border border-purple-400">
            <span>⚡ TIE-BREAK A 7 PUNTI (SERVIZIO 1-2-2-2) ⚡</span>
          </div>
        </div>
      )}

      {/* CAMBIO CAMPO (BREAK TIMER OVERLAY) */}
      {isBreakActive && (
        <div className="absolute inset-0 z-40 bg-black/85 backdrop-blur-md flex flex-col items-center justify-center p-4">
          <div className="p-8 max-w-md w-full rounded-3xl bg-slate-900 border border-cyan-500/50 shadow-2xl text-center flex flex-col items-center space-y-4">
            <div className="p-3 rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/40">
              <Hourglass className="w-8 h-8 animate-spin" />
            </div>
            <h3 className="text-xl font-black tracking-wider uppercase text-white">
              Pausa Cambio Campo (FIP)
            </h3>
            <div className="text-8xl font-black font-mono text-cyan-400 tracking-tighter">
              {breakSecondsLeft}s
            </div>
            <p className="text-xs text-slate-400">
              I giocatori possono idratarsi e scambiare il campo.
            </p>
            <button
              onClick={stopBreakTimer}
              className="flex items-center gap-2 px-6 py-3 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black text-sm tracking-wider uppercase shadow-lg shadow-cyan-500/30 transition-all cursor-pointer active:scale-95"
            >
              <Play className="w-4 h-4" />
              <span>Riprendi Gioco</span>
            </button>
          </div>
        </div>
      )}

      {/* MAIN THREE-COLUMN LANDSCAPE SCOREBOARD - MASSIMO SPAZIO AI PUNTEGGI */}
      <main className="flex-1 flex flex-row relative divide-x divide-slate-800/80 overflow-hidden">
        {/* LEFT COLUMN: TEAM 1 */}
        <TeamColumn
          team="teamA"
          teamName={settings.teamAName}
          playersText={`${settings.player1Name} & ${settings.player2Name}`}
          servingPlayerName={currentServingPlayer}
          scoreText={snapshot.isTieBreak ? snapshot.tieBreakPointsA.toString() : getPointLabel(snapshot.rawPointsA)}
          gamesWon={snapshot.currentGamesA}
          isServing={snapshot.servingTeam === 'teamA'}
          accentColor="lime"
          isTieBreak={snapshot.isTieBreak}
          isGoldenPoint={isGoldenPointSituation}
          isDeuce={isDeuce}
          onAddPoint={() => addPoint('teamA')}
        />

        {/* CENTRAL COLUMN: COMPACT VERTICAL CONTROLS (SOLO ICONE) */}
        <CentralScoreboardColumn
          snapshot={snapshot}
          settings={settings}
          canUndo={history.length > 0}
          matchTimeFormatted={formatMatchTime(matchSeconds)}
          isTimerRunning={isTimerRunning}
          onToggleTimer={() => setIsTimerRunning(!isTimerRunning)}
          onToggleServingTeam={handleToggleServingTeam}
          onToggleGoldenPoint={handleToggleGoldenPoint}
          onUndo={handleUndo}
          onStartBreak={() => startBreakTimer(90)}
          onSwitchSides={handleSwitchSides}
          onReset={handleOpenResetDialog}
          onOpenMatchInfo={() => setIsMatchInfoOpen(true)}
          onTerminate={() => setIsTerminateModalOpen(true)}
          onOpenSettings={() => setIsSettingsOpen(true)}
        />

        {/* RIGHT COLUMN: TEAM 2 */}
        <TeamColumn
          team="teamB"
          teamName={settings.teamBName}
          playersText={`${settings.player3Name} & ${settings.player4Name}`}
          servingPlayerName={currentServingPlayer}
          scoreText={snapshot.isTieBreak ? snapshot.tieBreakPointsB.toString() : getPointLabel(snapshot.rawPointsB)}
          gamesWon={snapshot.currentGamesB}
          isServing={snapshot.servingTeam === 'teamB'}
          accentColor="cyan"
          isTieBreak={snapshot.isTieBreak}
          isGoldenPoint={isGoldenPointSituation}
          isDeuce={isDeuce}
          onAddPoint={() => addPoint('teamB')}
        />
      </main>

      {/* MODALS */}
      <ResetConfirmModal
        isOpen={isResetConfirmOpen}
        onClose={() => setIsResetConfirmOpen(false)}
        onConfirmReset={handleConfirmReset}
        onGoToSetup={handleResetAndGoToSetup}
      />

      <TerminateConfirmModal
        isOpen={isTerminateModalOpen}
        onClose={() => setIsTerminateModalOpen(false)}
        onConfirm={handleTerminateMatch}
      />

      <MatchInfoModal
        isOpen={isMatchInfoOpen}
        onClose={() => setIsMatchInfoOpen(false)}
        snapshot={snapshot}
        settings={settings}
        matchDurationFormatted={formatMatchTime(matchSeconds)}
        servingPlayerName={currentServingPlayer}
      />

      <SettingsModal
        isOpen={isSettingsOpen}
        settings={settings}
        onClose={() => setIsSettingsOpen(false)}
        onSave={(updated) => setSettings(prev => ({ ...prev, ...updated }))}
        onOpenRemoteHelper={() => setIsRemoteHelperOpen(true)}
        onToggleSmartwatchMode={() => setIsSmartwatchMode(!isSmartwatchMode)}
        isSmartwatchMode={isSmartwatchMode}
      />

      <RemoteHelperModal
        isOpen={isRemoteHelperOpen}
        onClose={() => setIsRemoteHelperOpen(false)}
        onSimulateVolUpSingle={() => addPoint('teamA')}
        onSimulateVolUpDouble={() => addPoint('teamB')}
        onSimulateVolDown={handleUndo}
        lastLogs={lastLogs}
      />
    </div>
  );
}
