import React from 'react';
import {
  Undo2,
  Hourglass,
  Menu,
  Play,
  Pause,
} from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot } from '../types/padel';

interface HeaderBarProps {
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  canUndo: boolean;
  matchTimeFormatted: string;
  isTimerRunning: boolean;
  onToggleTimer: () => void;
  onUndo: () => void;
  onStartBreak: () => void;
  onOpenMenu: () => void;
}

export const HeaderBar: React.FC<HeaderBarProps> = ({
  snapshot,
  settings,
  canUndo,
  matchTimeFormatted,
  isTimerRunning,
  onToggleTimer,
  onUndo,
  onStartBreak,
  onOpenMenu,
}) => {
  const currentSetNum = snapshot.completedSets.length + 1;

  return (
    <header className="h-10 sm:h-11 bg-zinc-950/95 border-b border-zinc-800/80 px-2.5 sm:px-4 flex items-center justify-between gap-1.5 sm:gap-3 select-none shrink-0 z-20">
      {/* LEFT: Cronometro, Set Corrente & Riepilogo Set Completati */}
      <div className="flex items-center gap-1.5 sm:gap-2.5 min-w-0">
        {/* Match Timer */}
        <button
          onClick={onToggleTimer}
          title={isTimerRunning ? 'Pausa cronometro (clicca per mettere in pausa)' : 'Riprendi cronometro'}
          className="flex items-center gap-1.5 px-2 py-0.5 sm:py-1 rounded-md bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-mono font-bold text-zinc-200 transition-colors cursor-pointer shrink-0"
        >
          {isTimerRunning ? (
            <Pause className="w-3 h-3 text-zinc-400" />
          ) : (
            <Play className="w-3 h-3 text-emerald-400" />
          )}
          <span className="tabular-nums">{matchTimeFormatted}</span>
        </button>

        {/* Set Indicator */}
        <div className="flex items-center gap-1 px-1.5 py-0.5 rounded bg-zinc-900 border border-zinc-800 shrink-0">
          <span className="text-[11px] sm:text-xs font-black uppercase tracking-wider text-white">
            Set {currentSetNum}
          </span>
          {snapshot.isTieBreak && (
            <span className="px-1 py-0.2 rounded text-[9px] font-black uppercase tracking-wider bg-purple-500/20 text-purple-300 border border-purple-500/30">
              TB
            </span>
          )}
        </div>

        {/* Completed Sets Chips - Sempre visibili anche su mobile landscape */}
        {snapshot.completedSets.length > 0 && (
          <div className="flex items-center gap-1 overflow-x-auto shrink-0">
            {snapshot.completedSets.map((set, idx) => {
              const isWonA = set.winner === 'teamA';
              return (
                <span
                  key={idx}
                  className="px-1.5 py-0.5 rounded bg-zinc-900 border border-zinc-800 text-[10px] sm:text-[11px] font-mono font-bold text-zinc-300 shrink-0"
                  title={`Set ${idx + 1}: ${set.gamesA}-${set.gamesB}`}
                >
                  <span className={isWonA ? 'text-[#CCFF00]' : 'text-zinc-400'}>{set.gamesA}</span>
                  <span className="text-zinc-600 mx-0.5">-</span>
                  <span className={!isWonA ? 'text-[#00E5FF]' : 'text-zinc-400'}>{set.gamesB}</span>
                  {set.tieBreakPointsA !== undefined && set.tieBreakPointsB !== undefined && (
                    <span className="text-[9px] text-zinc-500 ml-0.5">
                      ({set.tieBreakPointsA}-{set.tieBreakPointsB})
                    </span>
                  )}
                </span>
              );
            })}
          </div>
        )}

        {/* Discrete Rule Tag */}
        <span className="hidden xl:inline-flex text-[10px] font-medium text-zinc-500">
          {settings.isGoldenPoint ? "Punto d'Oro" : 'Vantaggi'}
        </span>
      </div>

      {/* RIGHT: Quick Immediate Controls (Pausa 90s, Annulla, Menu) */}
      <div className="flex items-center gap-1 sm:gap-2 shrink-0">
        {/* Pausa 90s */}
        <button
          onClick={onStartBreak}
          title="Avvia pausa cambio campo 90s (regola FIP)"
          className="flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded-md bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-semibold text-zinc-200 hover:text-white transition-colors cursor-pointer"
        >
          <Hourglass className="w-3 h-3 text-cyan-400" />
          <span className="hidden xs:inline sm:inline">Pausa 90s</span>
          <span className="xs:hidden sm:hidden">Pausa</span>
        </button>

        {/* Annulla (Undo) */}
        <button
          onClick={onUndo}
          disabled={!canUndo}
          title="Annulla ultimo punto (Undo)"
          className={`flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded-md border text-xs font-bold transition-all cursor-pointer ${
            canUndo
              ? 'bg-zinc-900 hover:bg-zinc-800 text-white border-zinc-700 active:scale-95 shadow-sm'
              : 'bg-zinc-950 text-zinc-600 border-zinc-900 cursor-not-allowed opacity-40'
          }`}
        >
          <Undo2 className="w-3 h-3 text-amber-400" />
          <span>Annulla</span>
        </button>

        {/* Menu */}
        <button
          onClick={onOpenMenu}
          title="Apri menu opzioni partita"
          className="flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded-md bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-semibold text-zinc-200 hover:text-white transition-colors cursor-pointer active:scale-95"
        >
          <Menu className="w-3.5 h-3.5 text-zinc-300" />
          <span>Menu</span>
        </button>
      </div>
    </header>
  );
};
