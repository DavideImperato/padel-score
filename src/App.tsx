import React, { useState, useEffect, useRef, useCallback, useSyncExternalStore } from 'react';
import { PadelMatchSnapshot, SetScore, MatchSettings, Team } from './types/padel';
import {
  getCurrentServerPlayerId,
  getPlayerNameById,
  getTeamForPlayerId,
  createInitialSnapshot,
  PlayerId,
  ScoringEvent,
} from './engine/padelScoringEngine';
import { PadelMatchStore } from './engine/padelMatchStore';
import { loadCheckpoint, saveCheckpoint, clearCheckpoint, MatchCheckpoint, MatchRuntime } from './engine/matchPersistence';
import { padelAudio } from './utils/padelAudio';
import { BluetoothKeyListener } from './utils/bluetoothListener';
import { TeamColumn } from './components/TeamColumn';
import { HeaderBar } from './components/HeaderBar';
import { ScoreboardMenuModal } from './components/ScoreboardMenuModal';
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
  gamesPerSet: 6,
  decidingMatchTieBreak: false,
  decidingTieBreakPoints: 10,
  ttsSpeed: 0.95, // Cadenza arbitrale naturale
  ttsVolume: 1.0,
  isMuted: false,
  isVoiceMuted: false,
  isSfxMuted: false,
};

export default function App() {
  // Schermata: 'setup' (default per "/"), 'scoreboard', o 'summary' (riepilogo finale)
  const [currentView, setCurrentView] = useState<'setup' | 'scoreboard' | 'summary'>('setup');

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
          gamesPerSet: parsed.gamesPerSet === 4 ? 4 : 6,
          decidingMatchTieBreak: parsed.decidingMatchTieBreak === true,
          decidingTieBreakPoints: parsed.decidingTieBreakPoints === 7 ? 7 : 10,
        };
      }
    } catch {}
    return DEFAULT_SETTINGS;
  });

  // Store transazionale per aggiornamenti atomici del punteggio ed elaborazione sequenziale
  const storeRef = useRef<PadelMatchStore | null>(null);
  if (!storeRef.current) {
    storeRef.current = new PadelMatchStore(settings);
  }
  const store = storeRef.current;

  // Iscrizione reattiva tramite useSyncExternalStore (nessun disallineamento React/Engine)
  const { snapshot, history } = useSyncExternalStore(
    store.subscribe,
    store.getState,
    store.getState
  );

  // Un checkpoint esistente non viene mai sovrascritto prima della scelta Riprendi/Scarta.
  const [recoveryCandidate, setRecoveryCandidate] = useState<MatchCheckpoint | null>(() => {
    if (typeof window === 'undefined') return null;
    return loadCheckpoint(window.localStorage);
  });
  const persistenceActiveRef = useRef(false);

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
  const [isScoreboardMenuOpen, setIsScoreboardMenuOpen] = useState(false);
  const [isSidesSwapped, setIsSidesSwapped] = useState(false);
  const [isRemoteHelperOpen, setIsRemoteHelperOpen] = useState(false);
  const [isTerminateModalOpen, setIsTerminateModalOpen] = useState(false);
  const [isSmartwatchMode, setIsSmartwatchMode] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return (window.innerWidth <= 330 && window.innerHeight <= 380) || (window.innerWidth <= 380 && window.innerHeight <= 330);
  });
  const [lastLogs, setLastLogs] = useState<Array<{ text: string; time: string; type: 'up1' | 'up2' | 'down' | 'other' }>>([]);

  const runtimeRef = useRef<MatchRuntime>({
    matchSeconds, isTimerRunning, isSidesSwapped, breakSecondsLeft, isBreakActive,
    view: currentView === 'summary' ? 'summary' : 'scoreboard',
  });
  runtimeRef.current = {
    matchSeconds, isTimerRunning, isSidesSwapped, breakSecondsLeft, isBreakActive,
    view: currentView === 'summary' ? 'summary' : 'scoreboard',
  };

  const persistCurrentMatch = useCallback((runtime?: MatchRuntime) => {
    if (!persistenceActiveRef.current || typeof window === 'undefined') return;
    saveCheckpoint(window.localStorage, store.getSettings(), store.getState(), runtime ?? runtimeRef.current);
  }, [store]);

  // Salvataggio sincrono a ogni mutazione transazionale: punti, Undo e servizio.
  useEffect(() => store.subscribe(() => persistCurrentMatch()), [store, persistCurrentMatch]);
  // Stato UI e cronometro: una scrittura al secondo mentre il match è attivo.
  useEffect(() => { persistCurrentMatch(); }, [matchSeconds, isTimerRunning, isSidesSwapped,
    breakSecondsLeft, isBreakActive, currentView, settings, persistCurrentMatch]);

  const resumeCheckpoint = () => {
    if (!recoveryCandidate) return;
    const saved = recoveryCandidate;
    store.restoreMatch(saved.settings, saved.state);
    setSettings(saved.settings);
    setMatchSeconds(saved.runtime.matchSeconds);
    setIsTimerRunning(saved.runtime.isTimerRunning && !saved.state.snapshot.matchWinner);
    setIsSidesSwapped(saved.runtime.isSidesSwapped);
    setBreakSecondsLeft(saved.runtime.breakSecondsLeft);
    setIsBreakActive(saved.runtime.isBreakActive && saved.runtime.breakSecondsLeft > 0);
    setCurrentView(saved.state.snapshot.matchWinner || saved.runtime.view === 'summary' ? 'summary' : 'scoreboard');
    setRecoveryCandidate(null);
    persistenceActiveRef.current = true;
  };

  const discardCheckpoint = () => {
    if (typeof window !== 'undefined') clearCheckpoint(window.localStorage);
    setRecoveryCandidate(null);
  };

  const stopCheckpoint = () => {
    persistenceActiveRef.current = false;
    if (typeof window !== 'undefined') clearCheckpoint(window.localStorage);
  };

  // Feedback visivo a schermo per telecomando Bluetooth
  const [remoteFeedback, setRemoteFeedback] = useState<{ text: string; color: string } | null>(null);
  const feedbackDismissTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showRemoteFeedback = useCallback((action: 'teamA' | 'teamB' | 'undo', label: string) => {
    if (feedbackDismissTimerRef.current) {
      clearTimeout(feedbackDismissTimerRef.current);
    }
    const color = action === 'teamA' ? '#ccff00' : (action === 'teamB' ? '#00e5ff' : '#f43f5e');
    setRemoteFeedback({ text: label, color });
    feedbackDismissTimerRef.current = setTimeout(() => {
      setRemoteFeedback(null);
    }, 1400);
  }, []);

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
    store.updateSettings(settings);
  }, [settings, store]);

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

  // Get current serving player's name via stable PlayerId
  const getCurrentServingPlayer = useCallback((): string => {
    const serverPlayerId = getCurrentServerPlayerId(snapshot, settings.firstServerPlayerId);
    return getPlayerNameById(serverPlayerId, settings);
  }, [settings, snapshot]);

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

  const isAnyModalOpen = Boolean(
    isScoreboardMenuOpen ||
    isSettingsOpen ||
    isResetConfirmOpen ||
    isTerminateModalOpen ||
    isMatchInfoOpen ||
    isRemoteHelperOpen
  );

  const isAnyModalOpenRef = useRef(isAnyModalOpen);
  isAnyModalOpenRef.current = isAnyModalOpen;

  const currentViewRef = useRef(currentView);
  currentViewRef.current = currentView;

  // Sincronizza stato di blocco dello store
  useEffect(() => {
    store.setBlocked(currentView !== 'scoreboard' || isAnyModalOpen);
  }, [store, currentView, isAnyModalOpen]);

  const summaryRedirectTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const startBreakTimer = useCallback((duration: number = 90) => {
    triggerHaptic(50);
    setBreakSecondsLeft(duration);
    setIsBreakActive(true);
    padelAudio.speak(`Pausa cambio campo di ${duration} secondi.`);
  }, []);

  const stopBreakTimer = useCallback(() => {
    setIsBreakActive(false);
    setBreakSecondsLeft(0);
  }, []);

  // Gestione eventi sportivi con feedback sonoro e aptico fuori dal motore puro
  const handleScoreEvent = useCallback((event: ScoringEvent) => {
    const currentSettings = store.getSettings();

    if (event.type === 'tieBreakPoint') {
      triggerHaptic(30);
      const serverTeamName = event.servingTeam === 'teamA' ? currentSettings.teamAName : currentSettings.teamBName;
      padelAudio.speak(`${event.tieBreakPointsA} a ${event.tieBreakPointsB}, servizio ${serverTeamName}.`);
    } else if (event.type === 'point') {
      triggerHaptic(30);
      const serverName = getPlayerNameById(event.serverPlayerId, currentSettings);
      const serverTeamName = event.servingTeam === 'teamA' ? currentSettings.teamAName : currentSettings.teamBName;

      if (event.isDeuce) {
        if (event.isGoldenPoint) {
          padelAudio.speak("40 pari, Punto d'Oro!");
        } else {
          padelAudio.speak(`40 pari, servizio ${serverTeamName}, batte ${serverName}.`);
        }
      } else if (event.isAdvantage) {
        const advTeamName = event.rawPointsA === 4 ? currentSettings.teamAName : currentSettings.teamBName;
        padelAudio.speak(`Vantaggio ${advTeamName}, servizio ${serverTeamName}, batte ${serverName}.`);
      } else if (event.rawPointsA === event.rawPointsB) {
        if (event.rawPointsA === 0) {
          padelAudio.speak(`0 pari, servizio ${serverTeamName}, batte ${serverName}.`);
        } else if (event.rawPointsA === 1) {
          padelAudio.speak(`15 pari, servizio ${serverTeamName}, batte ${serverName}.`);
        } else if (event.rawPointsA === 2) {
          padelAudio.speak(`30 pari, servizio ${serverTeamName}, batte ${serverName}.`);
        }
      } else {
        const scoreA = getPointLabel(event.rawPointsA);
        const scoreB = getPointLabel(event.rawPointsB);
        padelAudio.speak(`${scoreA} - ${scoreB}, servizio ${serverTeamName}, batte ${serverName}.`);
      }
    } else if (event.type === 'tieBreakStarted') {
      triggerHaptic([60, 40, 60]);
      const nextServerName = getPlayerNameById(event.serverPlayerId, currentSettings);
      padelAudio.speak(`Sei pari. Tie-break. Serve ${nextServerName}.`);
    } else if (event.type === 'gameWon') {
      triggerHaptic([60, 40, 60]);
      const winnerName = event.winner === 'teamA' ? currentSettings.teamAName : currentSettings.teamBName;
      padelAudio.speak(`Vince Game ${winnerName}.`);
    } else if (event.type === 'setWon') {
      triggerHaptic([100, 50, 100, 50, 100]);
      padelAudio.playCourtBeep('game');
      const setWinnerName = event.winner === 'teamA' ? currentSettings.teamAName : currentSettings.teamBName;
      const setNum = event.setNumber ?? 1;
      const setOrdinal = setNum === 1 ? 'primo' : (setNum === 2 ? 'secondo' : (setNum === 3 ? 'terzo' : (setNum === 4 ? 'quarto' : 'quinto')));
      padelAudio.speak(`Vince Game e ${setOrdinal} Set la squadra ${setWinnerName}.`);
      startBreakTimer(120);
    } else if (event.type === 'matchWon') {
      triggerHaptic([100, 50, 100, 50, 100]);
      padelAudio.playCourtBeep('game');
      const matchWinnerName = event.winner === 'teamA' ? currentSettings.teamAName : currentSettings.teamBName;
      padelAudio.speak(`Vince Game, Set e Partita la squadra ${matchWinnerName}!`);
      setIsTimerRunning(false);
      if (summaryRedirectTimerRef.current) clearTimeout(summaryRedirectTimerRef.current);
      summaryRedirectTimerRef.current = setTimeout(() => {
        setCurrentView('summary');
      }, 2500);
    }
  }, [startBreakTimer, store]);

  // Collega listener allo store
  useEffect(() => {
    store.onScoreEvent = (event) => {
      handleScoreEvent(event);
    };
  }, [store, handleScoreEvent]);

  // Aggiunta punto transazionale: nessuna perdita di punti su comandi rapidi
  const addPoint = useCallback((scoringTeam: Team) => {
    if (currentViewRef.current !== 'scoreboard') return;
    if (isAnyModalOpenRef.current) return;
    padelAudio.unlockAudio();
    store.addPoint(scoringTeam);
  }, [store]);

  // Undo transazionale: annulla impulsi pendenti e ripristina lo stato precedente
  const handleUndo = useCallback(() => {
    if (currentViewRef.current !== 'scoreboard') return;
    if (isAnyModalOpenRef.current) return;
    if (store.getHistory().length === 0) return;

    triggerHaptic(20);
    padelAudio.unlockAudio();

    if (summaryRedirectTimerRef.current) {
      clearTimeout(summaryRedirectTimerRef.current);
      summaryRedirectTimerRef.current = null;
    }
    stopBreakTimer();
    setIsTimerRunning(true);

    const prev = store.undo();
    if (prev) {
      padelAudio.speak('Punto annullato.');
    }
  }, [store, stopBreakTimer]);

  // Riferimenti stabili per callback del listener Bluetooth
  const addPointRef = useRef(addPoint);
  addPointRef.current = addPoint;

  const handleUndoRef = useRef(handleUndo);
  handleUndoRef.current = handleUndo;

  // RESET FUNCTIONALITY (In-app confirmation without window.confirm!)
  const handleOpenResetDialog = useCallback(() => {
    setIsResetConfirmOpen(true);
  }, []);

  const handleConfirmReset = useCallback(() => {
    triggerHaptic(50);
    padelAudio.unlockAudio();
    if (summaryRedirectTimerRef.current) {
      clearTimeout(summaryRedirectTimerRef.current);
      summaryRedirectTimerRef.current = null;
    }
    stopBreakTimer();
    setIsSidesSwapped(false);
    setMatchSeconds(0);
    setIsTimerRunning(true);

    const serverId = store.resetMatch();
    const serverName = getPlayerNameById(serverId, store.getSettings());
    padelAudio.speak(`Partita resettata. Serve ${serverName}.`);
  }, [store, stopBreakTimer]);

  const handleResetAndGoToSetup = useCallback(() => {
    triggerHaptic(50);
    padelAudio.unlockAudio();
    if (summaryRedirectTimerRef.current) {
      clearTimeout(summaryRedirectTimerRef.current);
      summaryRedirectTimerRef.current = null;
    }
    stopBreakTimer();
    setIsSidesSwapped(false);
    setMatchSeconds(0);
    setIsTimerRunning(true);

    store.resetMatch();
    stopCheckpoint();
    setCurrentView('setup');
    padelAudio.speak('Partita azzerata. Nuova configurazione match.');
  }, [store, stopBreakTimer]);

  const handleTerminateMatch = useCallback(() => {
    setIsTimerRunning(false);
    if (summaryRedirectTimerRef.current) {
      clearTimeout(summaryRedirectTimerRef.current);
      summaryRedirectTimerRef.current = null;
    }
    triggerHaptic([80, 40, 80]);
    padelAudio.unlockAudio();
    padelAudio.speak('Partita conclusa. Visualizzazione del riepilogo finale.');
    setCurrentView('summary');
  }, []);

  const handleToggleServingTeam = useCallback(() => {
    const nextPlayerId = store.toggleServingTeam();
    const nextPlayerName = getPlayerNameById(nextPlayerId, store.getSettings());
    padelAudio.speak(`Cambio battitore. Serve ${nextPlayerName}.`);
  }, [store]);

  // CAMBIO CAMPO (SOLO INVERSIONE VISIVA DEI LATI, NESSUNA ALTERAZIONE STATO SPORTIVO)
  const handleSwitchSides = useCallback(() => {
    setIsSidesSwapped(prev => !prev);
    padelAudio.speak('Cambio campo.');
    startBreakTimer(90);
  }, [startBreakTimer]);

  const handleToggleMute = useCallback(() => {
    setSettings(prev => {
      const nextMuted = !(prev.isVoiceMuted && prev.isSfxMuted);
      padelAudio.setMuted(nextMuted);
      const next = {
        ...prev,
        isMuted: nextMuted,
        isVoiceMuted: nextMuted,
        isSfxMuted: nextMuted,
      };
      store.updateSettings(next);
      return next;
    });
  }, [store]);

  const handleToggleGoldenPoint = useCallback(() => {
    setSettings(prev => {
      const next = !prev.isGoldenPoint;
      padelAudio.speak(next ? "Punto d'oro attivato." : 'Vantaggi tradizionali attivati.');
      const updated = { ...prev, isGoldenPoint: next };
      store.updateSettings(updated);
      return updated;
    });
  }, [store]);

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
    if (summaryRedirectTimerRef.current) {
      clearTimeout(summaryRedirectTimerRef.current);
      summaryRedirectTimerRef.current = null;
    }
    setSettings(newSettings);
    try {
      localStorage.setItem('padel_settings_v3', JSON.stringify(newSettings));
    } catch {}

    stopBreakTimer();
    setIsSidesSwapped(false);
    setMatchSeconds(0);
    setIsTimerRunning(true); // Cronometro attivo automaticamente da 0

    const initialPlayer = store.startNewMatch(newSettings);
    persistenceActiveRef.current = true;
    persistCurrentMatch({ matchSeconds: 0, isTimerRunning: true, isSidesSwapped: false,
      breakSecondsLeft: 0, isBreakActive: false, view: 'scoreboard' });
    const initialTeam: Team = getTeamForPlayerId(initialPlayer);

    // Switch screen to scoreboard!
    setCurrentView('scoreboard');

    // Annuncio arbitrale
    const firstServer = getPlayerNameById(initialPlayer, newSettings);
    const initialTeamName = initialTeam === 'teamA' ? newSettings.teamAName : newSettings.teamBName;

    padelAudio.unlockAudio();
    padelAudio.speak(
      `Inizia la sfida tra ${newSettings.teamAName}, con ${newSettings.player1Name} e ${newSettings.player2Name}, e ${newSettings.teamBName}, con ${newSettings.player3Name} e ${newSettings.player4Name}. Servizio per la squadra ${initialTeamName}, batte ${firstServer}. Buon match!`
    );
  };

  // Bluetooth key listener persistente con callback aggiornabili
  const keyListenerRef = useRef<BluetoothKeyListener | null>(null);

  useEffect(() => {
    const listener = new BluetoothKeyListener({
      onTeamA: () => addPointRef.current('teamA'),
      onTeamB: () => addPointRef.current('teamB'),
      onUndo: () => handleUndoRef.current(),
      isBlocked: () => currentViewRef.current !== 'scoreboard' || isAnyModalOpenRef.current,
      onLog: (msg, type) => addLog(msg, type),
      onFeedback: (action, label) => showRemoteFeedback(action, label),
    });
    listener.start();
    keyListenerRef.current = listener;

    return () => {
      listener.stop();
      keyListenerRef.current = null;
    };
  }, [addLog, showRemoteFeedback]);

  useEffect(() => {
    if (keyListenerRef.current) {
      keyListenerRef.current.updateCallbacks({
        onTeamA: () => addPointRef.current('teamA'),
        onTeamB: () => addPointRef.current('teamB'),
        onUndo: () => handleUndoRef.current(),
        isBlocked: () => currentViewRef.current !== 'scoreboard' || isAnyModalOpenRef.current,
        onLog: (msg, type) => addLog(msg, type),
        onFeedback: (action, label) => showRemoteFeedback(action, label),
      });
    }
  });

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

  // Recupero esplicito, prima di poter iniziare una nuova partita.
  if (recoveryCandidate) {
    return (
      <div className="min-h-[100dvh] bg-zinc-950 text-white flex items-center justify-center p-5">
        <div className="w-full max-w-md rounded-2xl border border-zinc-700 bg-zinc-900 p-6 shadow-2xl space-y-4">
          <h1 className="text-xl font-bold text-lime-300">Partita salvata</h1>
          <p className="text-sm text-zinc-300">È stata trovata una partita sul dispositivo. Vuoi riprenderla con punteggio, battitore, cronometro e cronologia Undo?</p>
          <p className="text-sm font-semibold">{recoveryCandidate.settings.teamAName} vs {recoveryCandidate.settings.teamBName}</p>
          <div className="flex flex-wrap gap-3">
            <button type="button" onClick={resumeCheckpoint}
              className="rounded-xl bg-lime-300 text-zinc-950 font-bold px-5 py-3">Riprendi partita</button>
            <button type="button" onClick={discardCheckpoint}
              className="rounded-xl bg-zinc-700 text-white px-5 py-3">Scarta salvataggio</button>
          </div>
        </div>
      </div>
    );
  }

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
          if (summaryRedirectTimerRef.current) {
            clearTimeout(summaryRedirectTimerRef.current);
            summaryRedirectTimerRef.current = null;
          }
          stopBreakTimer();
          setIsSidesSwapped(false);
          setMatchSeconds(0);
          setIsTimerRunning(true);
          store.resetMatch();
          stopCheckpoint();
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
  const setsWonA = snapshot.completedSets.filter(s => s.winner === 'teamA').length;
  const setsWonB = snapshot.completedSets.filter(s => s.winner === 'teamB').length;

  return (
    <div className="relative w-full h-screen h-[100dvh] bg-zinc-950 text-white flex flex-col overflow-hidden select-none font-sans">
      <LandscapeEnforcer />

      {/* OVERLAY FEEDBACK VISIVO TELECOMANDO BLUETOOTH */}
      {remoteFeedback && (
        <div className="absolute top-14 left-0 right-0 z-50 flex justify-center pointer-events-none animate-in fade-in duration-150">
          <div
            className="px-4 py-1.5 rounded-full bg-zinc-900/95 backdrop-blur-md border shadow-xl flex items-center gap-2"
            style={{ borderColor: remoteFeedback.color }}
          >
            <span
              className="w-2 h-2 rounded-full"
              style={{ backgroundColor: remoteFeedback.color }}
            />
            <span
              className="font-mono font-bold text-xs tracking-wider uppercase"
              style={{ color: remoteFeedback.color }}
            >
              {remoteFeedback.text}
            </span>
          </div>
        </div>
      )}

      {/* MATCH NOTIFICATION OVERLAY */}
      {snapshot.matchWinner && (
        <div className="absolute top-14 left-0 right-0 z-30 flex justify-center px-4 animate-in fade-in duration-200 pointer-events-auto">
          <div className="px-5 py-2 rounded-xl bg-emerald-600 text-white font-bold text-xs sm:text-sm tracking-wider uppercase shadow-xl flex items-center gap-3 border border-emerald-400">
            <Trophy className="w-4 h-4 text-amber-300" />
            <span>PARTITA VINTA DA {getTeamName(snapshot.matchWinner).toUpperCase()}!</span>
            <button
              onClick={() => {
                if (summaryRedirectTimerRef.current) {
                  clearTimeout(summaryRedirectTimerRef.current);
                  summaryRedirectTimerRef.current = null;
                }
                stopBreakTimer();
                setIsSidesSwapped(false);
                setMatchSeconds(0);
                setIsTimerRunning(true);
                store.resetMatch();
                stopCheckpoint();
                setCurrentView('setup');
              }}
              className="ml-2 px-2.5 py-1 rounded bg-black/40 hover:bg-black/60 text-xs font-bold transition-colors cursor-pointer"
            >
              Nuova Partita
            </button>
          </div>
        </div>
      )}

      {isGoldenPointSituation && !snapshot.matchWinner && (
        <div className="absolute top-14 left-0 right-0 z-30 flex justify-center px-4 pointer-events-none">
          <div className="px-4 py-1.5 rounded-lg bg-amber-500 text-zinc-950 font-black text-xs tracking-wider uppercase shadow-lg flex items-center gap-1.5 border border-amber-300">
            <Sparkles className="w-3.5 h-3.5 text-zinc-950" />
            <span>PUNTO D'ORO DECISIVO</span>
          </div>
        </div>
      )}

      {snapshot.isTieBreak && !snapshot.matchWinner && (
        <div className="absolute top-14 left-0 right-0 z-30 flex justify-center px-4 pointer-events-none">
          <div className="px-4 py-1.5 rounded-lg bg-purple-600 text-white font-bold text-xs tracking-wider uppercase shadow-lg flex items-center gap-1.5 border border-purple-400">
            <span>{snapshot.isMatchTieBreak ? 'MATCH TIE-BREAK A 10 PUNTI' : 'TIE-BREAK A 7 PUNTI'}</span>
          </div>
        </div>
      )}

      {/* CAMBIO CAMPO (BREAK TIMER OVERLAY) */}
      {isBreakActive && (
        <div className="absolute inset-0 z-40 bg-zinc-950/90 backdrop-blur-sm flex flex-col items-center justify-center p-4">
          <div className="p-8 max-w-md w-full rounded-2xl bg-zinc-900 border border-zinc-700 shadow-2xl text-center flex flex-col items-center space-y-4">
            <div className="p-3 rounded-full bg-zinc-800 text-zinc-200 border border-zinc-700">
              <Hourglass className="w-7 h-7" />
            </div>
            <h3 className="text-lg font-bold tracking-wider uppercase text-white">
              Pausa Cambio Campo (90s)
            </h3>
            <div className="text-7xl font-mono font-bold text-white tracking-tight">
              {breakSecondsLeft}s
            </div>
            <p className="text-xs text-zinc-400">
              Idratazione e cambio campo dei giocatori.
            </p>
            <button
              onClick={stopBreakTimer}
              className="flex items-center gap-2 px-6 py-2.5 rounded-lg bg-zinc-100 hover:bg-white text-zinc-950 font-bold text-xs tracking-wider uppercase shadow transition-all cursor-pointer active:scale-95"
            >
              <Play className="w-4 h-4" />
              <span>Riprendi Gioco</span>
            </button>
          </div>
        </div>
      )}

      {/* TOP COMPACT HEADER BAR: CRONOMETRO, SET, PAUSA, ANNULLA, MENU */}
      <HeaderBar
        snapshot={snapshot}
        settings={settings}
        canUndo={history.length > 0}
        matchTimeFormatted={formatMatchTime(matchSeconds)}
        isTimerRunning={isTimerRunning}
        onToggleTimer={() => setIsTimerRunning(!isTimerRunning)}
        onUndo={handleUndo}
        onStartBreak={() => startBreakTimer(90)}
        onOpenMenu={() => setIsScoreboardMenuOpen(true)}
      />

      {/* MAIN TWO-COLUMN SCOREBOARD - SQUADRA A E SQUADRA B AFFIANCATE (INVERTIBILI CON CAMBIO CAMPO) */}
      <main className="flex-1 flex flex-row relative divide-x divide-zinc-800/80 overflow-hidden pl-[env(safe-area-inset-left)] pr-[env(safe-area-inset-right)] pb-[env(safe-area-inset-bottom)]">
        {isSidesSwapped ? (
          <>
            {/* SQUADRA B (VISUALIZZATA A SINISTRA) */}
            <TeamColumn
              key="teamB"
              team="teamB"
              teamName={settings.teamBName}
              playersText={`${settings.player3Name} & ${settings.player4Name}`}
              servingPlayerName={currentServingPlayer}
              scoreText={snapshot.isTieBreak ? snapshot.tieBreakPointsB.toString() : getPointLabel(snapshot.rawPointsB)}
              gamesWon={snapshot.currentGamesB}
              setsWon={setsWonB}
              currentSetNumber={snapshot.completedSets.length + 1}
              isServing={snapshot.servingTeam === 'teamB'}
              accentColor="cyan"
              isTieBreak={snapshot.isTieBreak}
              isGoldenPoint={isGoldenPointSituation}
              isDeuce={isDeuce}
              onAddPoint={() => addPoint('teamB')}
            />

            {/* SQUADRA A (VISUALIZZATA A DESTRA) */}
            <TeamColumn
              key="teamA"
              team="teamA"
              teamName={settings.teamAName}
              playersText={`${settings.player1Name} & ${settings.player2Name}`}
              servingPlayerName={currentServingPlayer}
              scoreText={snapshot.isTieBreak ? snapshot.tieBreakPointsA.toString() : getPointLabel(snapshot.rawPointsA)}
              gamesWon={snapshot.currentGamesA}
              setsWon={setsWonA}
              currentSetNumber={snapshot.completedSets.length + 1}
              isServing={snapshot.servingTeam === 'teamA'}
              accentColor="lime"
              isTieBreak={snapshot.isTieBreak}
              isGoldenPoint={isGoldenPointSituation}
              isDeuce={isDeuce}
              onAddPoint={() => addPoint('teamA')}
            />
          </>
        ) : (
          <>
            {/* SQUADRA A (VISUALIZZATA A SINISTRA) */}
            <TeamColumn
              key="teamA"
              team="teamA"
              teamName={settings.teamAName}
              playersText={`${settings.player1Name} & ${settings.player2Name}`}
              servingPlayerName={currentServingPlayer}
              scoreText={snapshot.isTieBreak ? snapshot.tieBreakPointsA.toString() : getPointLabel(snapshot.rawPointsA)}
              gamesWon={snapshot.currentGamesA}
              setsWon={setsWonA}
              currentSetNumber={snapshot.completedSets.length + 1}
              isServing={snapshot.servingTeam === 'teamA'}
              accentColor="lime"
              isTieBreak={snapshot.isTieBreak}
              isGoldenPoint={isGoldenPointSituation}
              isDeuce={isDeuce}
              onAddPoint={() => addPoint('teamA')}
            />

            {/* SQUADRA B (VISUALIZZATA A DESTRA) */}
            <TeamColumn
              key="teamB"
              team="teamB"
              teamName={settings.teamBName}
              playersText={`${settings.player3Name} & ${settings.player4Name}`}
              servingPlayerName={currentServingPlayer}
              scoreText={snapshot.isTieBreak ? snapshot.tieBreakPointsB.toString() : getPointLabel(snapshot.rawPointsB)}
              gamesWon={snapshot.currentGamesB}
              setsWon={setsWonB}
              currentSetNumber={snapshot.completedSets.length + 1}
              isServing={snapshot.servingTeam === 'teamB'}
              accentColor="cyan"
              isTieBreak={snapshot.isTieBreak}
              isGoldenPoint={isGoldenPointSituation}
              isDeuce={isDeuce}
              onAddPoint={() => addPoint('teamB')}
            />
          </>
        )}
      </main>

      {/* MENU MODAL CON TUTTE LE AZIONI SECONDARIE ORDINATE */}
      <ScoreboardMenuModal
        isOpen={isScoreboardMenuOpen}
        onClose={() => setIsScoreboardMenuOpen(false)}
        snapshot={snapshot}
        settings={settings}
        servingPlayerName={currentServingPlayer}
        isFullscreen={isFullscreen}
        onToggleServingTeam={handleToggleServingTeam}
        onSwitchSides={handleSwitchSides}
        onStartBreak={() => startBreakTimer(90)}
        onToggleGoldenPoint={handleToggleGoldenPoint}
        onToggleMute={handleToggleMute}
        onOpenMatchInfo={() => setIsMatchInfoOpen(true)}
        onOpenRemoteHelper={() => setIsRemoteHelperOpen(true)}
        onToggleFullscreen={handleToggleFullscreen}
        onOpenSettings={() => setIsSettingsOpen(true)}
        onTerminate={() => setIsTerminateModalOpen(true)}
        onReset={handleOpenResetDialog}
        onGoToSetup={handleResetAndGoToSetup}
      />

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
        onSave={(updated) => {
          setSettings(prev => {
            const next = { ...prev, ...updated };
            store.updateSettings(next);
            return next;
          });
        }}
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
