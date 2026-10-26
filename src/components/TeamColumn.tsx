import React from 'react';
import { Team } from '../types/padel';

interface TeamColumnProps {
  team: Team;
  teamName: string;
  playersText: string;
  servingPlayerName?: string;
  scoreText: string;
  gamesWon: number;
  setsWon: number;
  currentSetNumber?: number;
  isServing: boolean;
  accentColor: 'lime' | 'cyan';
  isTieBreak: boolean;
  isGoldenPoint: boolean;
  isDeuce: boolean;
  onAddPoint: () => void;
}

export const TeamColumn: React.FC<TeamColumnProps> = ({
  teamName,
  playersText,
  servingPlayerName,
  scoreText,
  gamesWon,
  currentSetNumber = 1,
  isServing,
  accentColor,
  isTieBreak,
  isGoldenPoint,
  isDeuce,
  onAddPoint,
}) => {
  const isLime = accentColor === 'lime';
  const teamTextColor = isLime ? 'text-[#CCFF00]' : 'text-[#00E5FF]';
  const accentDotColor = isLime ? 'bg-[#CCFF00]' : 'bg-[#00E5FF]';
  const isAdvantage = scoreText === 'AV';

  return (
    <div
      onClick={onAddPoint}
      role="button"
      tabIndex={0}
      data-team-column="true"
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          if (e.repeat) return;
          e.preventDefault();
          e.stopPropagation();
          onAddPoint();
        }
      }}
      aria-label={`Assegna punto a ${teamName}`}
      className="relative flex-1 flex flex-col justify-between p-2.5 sm:p-3.5 md:p-4 lg:p-5 cursor-pointer select-none transition-all duration-75 active:scale-[0.993] active:bg-zinc-900/60 hover:bg-zinc-900/20 group overflow-hidden"
    >
      {/* 1. INTESTAZIONE: NOME SQUADRA, GIOCATORI & BATTITORE */}
      <div className="flex flex-col z-10 shrink-0">
        <div className="flex items-center justify-between gap-2">
          <h2
            className={`text-base sm:text-lg md:text-xl lg:text-2xl font-black tracking-wide uppercase truncate ${teamTextColor}`}
          >
            {teamName}
          </h2>

          {isServing && (
            <span
              className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-black uppercase tracking-wider shrink-0 ${
                isLime
                  ? 'bg-[#CCFF00]/15 text-[#CCFF00] border border-[#CCFF00]/30'
                  : 'bg-[#00E5FF]/15 text-[#00E5FF] border border-[#00E5FF]/30'
              }`}
            >
              <span className={`w-1.5 h-1.5 rounded-full ${accentDotColor}`} aria-hidden="true" />
              <span>Servizio</span>
            </span>
          )}
        </div>

        <div className="flex items-center justify-between gap-2 mt-0.5">
          <p className="text-xs sm:text-sm text-zinc-400 font-medium truncate">
            {playersText}
          </p>
          {isServing && servingPlayerName && (
            <span className="text-[11px] text-zinc-400 font-medium truncate shrink-0 hidden sm:inline">
              Batte: <strong className="text-zinc-200">{servingPlayerName}</strong>
            </span>
          )}
        </div>
      </div>

      {/* 2. PUNTEGGIO PRINCIPALE: RESPONSIVE ANCHE SULL'ALTEZZA (CLAMP VH) */}
      <div className="flex-1 flex flex-col items-center justify-center my-1 z-10 min-h-0">
        {/* Tag discreto Punto d'Oro quando si è 40-40 */}
        {isDeuce && isGoldenPoint && (
          <div className="mb-1 px-2.5 py-0.5 rounded border border-rose-500/40 bg-rose-500/10 text-rose-400 text-[10px] sm:text-xs font-bold uppercase tracking-wider shrink-0">
            Punto d'Oro
          </div>
        )}

        <div className="flex items-center justify-center w-full">
          <span
            className={`font-mono font-black tabular-nums tracking-tighter leading-none select-none text-center ${
              isAdvantage
                ? 'text-amber-400 text-[clamp(3.5rem,20vh,8rem)]'
                : 'text-white text-[clamp(4.25rem,27vh,11rem)]'
            }`}
          >
            {scoreText}
          </span>
        </div>
      </div>

      {/* 3. SEZIONE GAME: ULTRA-LEGGIBILE DA DISTANZA */}
      <div className="shrink-0 z-10 pt-1">
        <div
          className={`flex items-center justify-between px-3 sm:px-4 py-1.5 sm:py-2 rounded-xl bg-zinc-900/90 border transition-colors ${
            isServing
              ? isLime
                ? 'border-[#CCFF00]/40'
                : 'border-[#00E5FF]/40'
              : 'border-zinc-800'
          }`}
        >
          <div className="flex flex-col">
            <span className="text-[11px] sm:text-xs font-black uppercase tracking-wider text-zinc-400">
              {isTieBreak ? 'Tie-Break' : `Game • Set ${currentSetNumber}`}
            </span>
            <span className="text-[10px] text-zinc-400 font-medium">
              Set in corso
            </span>
          </div>

          <div className="flex items-center gap-1.5">
            <span className="text-3xl sm:text-4xl md:text-5xl font-mono font-black tabular-nums text-white leading-none">
              {gamesWon}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
