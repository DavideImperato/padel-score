import React from 'react';
import {
  Sparkles,
  Undo2,
  Hourglass,
  RefreshCw,
  RotateCcw,
  Info,
  Flag,
  Settings,
} from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot } from '../types/padel';

interface CentralScoreboardColumnProps {
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  canUndo: boolean;
  matchTimeFormatted: string;
  isTimerRunning: boolean;
  onToggleTimer: () => void;
  onToggleServingTeam: () => void;
  onToggleGoldenPoint: () => void;
  onUndo: () => void;
  onStartBreak: () => void;
  onSwitchSides: () => void;
  onReset: () => void;
  onOpenMatchInfo: () => void;
  onTerminate: () => void;
  onOpenSettings: () => void;
}

export const CentralScoreboardColumn: React.FC<CentralScoreboardColumnProps> = ({
  snapshot,
  settings,
  canUndo,
  matchTimeFormatted,
  isTimerRunning,
  onToggleTimer,
  onToggleServingTeam,
  onToggleGoldenPoint,
  onUndo,
  onStartBreak,
  onSwitchSides,
  onReset,
  onOpenMatchInfo,
  onTerminate,
  onOpenSettings,
}) => {
  const currentSetNum = snapshot.completedSets.length + 1;

  return (
    <div className="w-16 sm:w-20 lg:w-22 shrink-0 bg-slate-950/95 border-x border-slate-800/90 flex flex-col items-center justify-between py-2 sm:py-3 px-1 z-20 backdrop-blur-md select-none overflow-y-auto">
      {/* 1. BOX UNIFICATO SET + TEMPO (In cima alla colonna) */}
      <button
        onClick={onToggleTimer}
        title={isTimerRunning ? 'Pausa cronometro match (clicca per pausa)' : 'Riprendi cronometro match'}
        className="w-full py-1.5 px-1 rounded-xl bg-slate-900 border border-slate-700/80 hover:border-slate-500 shadow-md flex flex-col items-center justify-center cursor-pointer transition-all active:scale-95 group"
      >
        <span className="text-[9px] sm:text-[10px] font-black uppercase tracking-wider text-[#CCFF00] truncate">
          {snapshot.isTieBreak ? `SET ${currentSetNum} TB` : `SET ${currentSetNum}`}
        </span>
        <div className="flex items-center gap-1 mt-0.5">
          <span className={`w-1.5 h-1.5 rounded-full ${isTimerRunning ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`} />
          <span className="font-mono text-[11px] sm:text-xs font-black text-slate-100">
            {matchTimeFormatted}
          </span>
        </div>
      </button>

      {/* PULSANTI DI AZIONE - ESCLUSIVAMENTE ICONE SENZA TESTO */}
      <div className="w-full flex flex-col items-center gap-1 sm:gap-1.5 flex-1 justify-center my-1">
        {/* 2. Icona "Servizio" (Pallina da Padel - Ruota turno di battuta ad ogni clic) */}
        <button
          onClick={onToggleServingTeam}
          title="Cambia Servizio / Prossimo Battitore in Battuta"
          className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-[#CCFF00]/15 border border-[#CCFF00]/60 hover:bg-[#CCFF00]/25 flex items-center justify-center shadow-md shadow-[#CCFF00]/10 transition-all cursor-pointer active:scale-90 group"
        >
          <svg className="w-5 h-5 sm:w-6 sm:h-6 group-hover:scale-110 transition-transform" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="9.5" fill="#CCFF00" stroke="#99CC00" strokeWidth="1.5" />
            <path d="M4.5 7.5C8 8.5 10 11.5 10 16.5" stroke="#1E293B" strokeWidth="1.6" strokeLinecap="round" />
            <path d="M19.5 16.5C16 15.5 14 12.5 14 7.5" stroke="#1E293B" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
        </button>

        {/* 3. Icona "Punto d'oro / Vantaggi" (Stella / Scintilla) */}
        <button
          onClick={onToggleGoldenPoint}
          title={
            settings.isGoldenPoint
              ? "Regola attiva: Punto d'Oro (clicca per passare ai Vantaggi classici)"
              : "Regola attiva: Vantaggi classici (clicca per passare al Punto d'Oro)"
          }
          className={`w-10 h-10 sm:w-11 sm:h-11 rounded-2xl border flex items-center justify-center shadow-sm transition-all cursor-pointer active:scale-90 ${
            settings.isGoldenPoint
              ? 'bg-amber-500/15 border-amber-500/50 hover:bg-amber-500/25 text-amber-300'
              : 'bg-cyan-500/15 border-cyan-500/50 hover:bg-cyan-500/25 text-cyan-300'
          }`}
        >
          <Sparkles className="w-5 h-5 sm:w-5.5 sm:h-5.5" />
        </button>

        {/* 4. Icona "Undo / Annulla" (Freccia indietro) */}
        <button
          onClick={onUndo}
          disabled={!canUndo}
          title="Annulla Ultimo Punto (Undo)"
          className={`w-10 h-10 sm:w-11 sm:h-11 rounded-2xl border flex items-center justify-center transition-all cursor-pointer ${
            canUndo
              ? 'bg-slate-900 text-white border-slate-700 hover:bg-slate-800 hover:border-slate-500 active:scale-90 shadow-sm'
              : 'bg-slate-950/60 text-slate-700 border-slate-900 cursor-not-allowed opacity-40'
          }`}
        >
          <Undo2 className="w-5 h-5 sm:w-5.5 sm:h-5.5" />
        </button>

        {/* 5. Icona "Pausa 90s" (Clessidra) */}
        <button
          onClick={onStartBreak}
          title="Avvia Pausa Cambio Campo Regolamentare FIP (90s)"
          className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-slate-900/90 border border-cyan-500/40 hover:bg-cyan-950/40 text-cyan-300 flex items-center justify-center shadow-sm transition-all cursor-pointer active:scale-90"
        >
          <Hourglass className="w-5 h-5 sm:w-5.5 sm:h-5.5 text-cyan-400" />
        </button>

        {/* 6. Icona "Cambio Campo" (Frecce circolari) */}
        <button
          onClick={onSwitchSides}
          title="Scambia Campo (Cambio Lati)"
          className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-slate-900/90 border border-slate-700 hover:bg-slate-800 text-slate-200 flex items-center justify-center shadow-sm transition-all cursor-pointer active:scale-90"
        >
          <RefreshCw className="w-5 h-5 sm:w-5.5 sm:h-5.5 text-[#CCFF00]" />
        </button>

        {/* 7. Icona "Reset" (Circolo di reset) */}
        <button
          onClick={onReset}
          title="Azzera Punteggi o Torna al Setup"
          className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-rose-950/30 border border-rose-800/50 hover:bg-rose-900/40 hover:border-rose-600 text-rose-300 flex items-center justify-center shadow-sm transition-all cursor-pointer active:scale-90"
        >
          <RotateCcw className="w-5 h-5 sm:w-5.5 sm:h-5.5 text-rose-400" />
        </button>

        {/* 8. Icona "Info Match" (lettera "i" dentro cerchio) */}
        <button
          onClick={onOpenMatchInfo}
          title="Informazioni e Risultati dei Set del Match"
          className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-slate-900/90 border border-blue-500/40 hover:bg-blue-950/40 text-blue-300 flex items-center justify-center shadow-sm transition-all cursor-pointer active:scale-90"
        >
          <Info className="w-5 h-5 sm:w-5.5 sm:h-5.5 text-blue-400" />
        </button>

        {/* 9. Icona "Termina Match" (Bandiera / Tasto rosso di stop) */}
        <button
          onClick={onTerminate}
          title="Termina Partita e Mostra Riepilogo Finale"
          className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-gradient-to-tr from-red-600 to-rose-600 hover:from-red-500 hover:to-rose-500 border border-red-400/50 text-white flex items-center justify-center shadow-md shadow-rose-950/60 transition-all cursor-pointer active:scale-90"
        >
          <Flag className="w-5 h-5 sm:w-5.5 sm:h-5.5 text-white" />
        </button>
      </div>

      {/* 10. ICONA "IMPOSTAZIONI" (Ingranaggio collocato in fondo alla colonna centrale) */}
      <button
        onClick={onOpenSettings}
        title="Impostazioni Partita, Audio e Regole"
        className="w-10 h-10 sm:w-11 sm:h-11 rounded-2xl bg-slate-900 border border-slate-700 hover:border-slate-500 text-slate-300 hover:text-white flex items-center justify-center shadow-md transition-all cursor-pointer active:scale-90"
      >
        <Settings className="w-5 h-5 sm:w-5.5 sm:h-5.5" />
      </button>
    </div>
  );
};
