import React from 'react';
import { Team } from '../types/padel';

interface TeamColumnProps {
  team: Team;
  teamName: string;
  playersText: string;
  servingPlayerName?: string;
  scoreText: string;
  gamesWon: number;
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
  isServing,
  accentColor,
  isTieBreak,
  isGoldenPoint,
  isDeuce,
  onAddPoint,
}) => {
  const isLime = accentColor === 'lime';
  const primaryColorClass = isLime ? 'text-[#CCFF00]' : 'text-[#00E5FF]';
  const borderHighlightClass = isLime ? 'border-[#CCFF00]/40' : 'border-[#00E5FF]/40';
  const glowShadow = isLime ? 'rgba(204, 255, 0, 0.35)' : 'rgba(0, 229, 255, 0.35)';

  const isAdvantage = scoreText === 'AV';

  return (
    <div
      onClick={onAddPoint}
      className={`relative flex-1 flex flex-col justify-between p-4 sm:p-6 lg:p-8 cursor-pointer select-none transition-all duration-150 active:scale-[0.99] group overflow-hidden ${
        isServing ? 'bg-slate-900/50' : 'bg-slate-950/30'
      }`}
      style={{
        boxShadow: isServing
          ? `inset 0 0 100px ${isLime ? 'rgba(204, 255, 0, 0.08)' : 'rgba(0, 229, 255, 0.08)'}`
          : 'none',
      }}
    >
      {/* WATERMARK SEMI-TRASPARENTE PALLINA DA PADEL/TENNIS SULLO SFONDO (SOLO SQUADRA AL SERVIZIO) */}
      {isServing && (
        <div
          aria-hidden="true"
          className="absolute inset-0 flex items-center justify-center pointer-events-none select-none overflow-hidden z-0"
        >
          <svg
            className={`w-72 h-72 sm:w-96 sm:h-96 md:w-[420px] md:h-[420px] transition-all duration-500 transform scale-105 ${
              isLime ? 'text-[#CCFF00]' : 'text-[#00E5FF]'
            } opacity-10 sm:opacity-[0.14]`}
            viewBox="0 0 200 200"
            fill="none"
          >
            {/* Outer Tennis Ball Circle */}
            <circle
              cx="100"
              cy="100"
              r="88"
              fill="currentColor"
              fillOpacity="0.06"
              stroke="currentColor"
              strokeWidth="5"
            />
            {/* Classic Padel / Tennis Seam Curves */}
            <path
              d="M38 46 C 75 65, 88 135, 38 154"
              stroke="currentColor"
              strokeWidth="6"
              strokeLinecap="round"
            />
            <path
              d="M162 46 C 125 65, 112 135, 162 154"
              stroke="currentColor"
              strokeWidth="6"
              strokeLinecap="round"
            />
          </svg>
        </div>
      )}

      {/* Hover ambient highlight */}
      <div
        className={`absolute inset-0 opacity-0 group-hover:opacity-5 transition-opacity pointer-events-none ${
          isLime ? 'bg-[#CCFF00]' : 'bg-[#00E5FF]'
        }`}
      />

      {/* TOP: Team Name & Players info (No bulky "Al Servizio" buttons/badges) */}
      <div className="flex flex-col gap-1 z-10">
        <div className="flex items-center justify-between gap-3">
          <div className="truncate">
            <h2
              className={`text-2xl sm:text-3xl lg:text-4xl font-black tracking-wider uppercase truncate ${primaryColorClass}`}
              style={{ textShadow: `0 0 20px ${glowShadow}` }}
            >
              {teamName}
            </h2>
            <p className="text-xs sm:text-sm text-slate-400 font-semibold truncate mt-0.5">
              {playersText}
            </p>
          </div>
        </div>

        {/* Indicazione discreta ed elegante del giocatore al servizio se la squadra batte */}
        {isServing && servingPlayerName ? (
          <div className="flex items-center gap-2 mt-1">
            <span
              className={`w-2 h-2 rounded-full ${
                isLime ? 'bg-[#CCFF00]' : 'bg-[#00E5FF]'
              } animate-ping`}
            />
            <span className="text-xs font-bold uppercase tracking-wider text-slate-300">
              Battitore:{' '}
              <span className={`font-black ${primaryColorClass}`}>
                {servingPlayerName}
              </span>
            </span>
          </div>
        ) : (
          <div className="h-4" />
        )}
      </div>

      {/* CENTER: GIGANTIC POINT SCORE */}
      <div className="flex-1 flex flex-col items-center justify-center my-2 sm:my-3 z-10">
        <div className="relative flex items-center justify-center">
          <span
            className={`font-mono font-black tracking-tighter leading-none select-none transition-transform duration-100 ${
              isAdvantage
                ? 'text-amber-400 text-7xl sm:text-8xl md:text-9xl lg:text-[140px]'
                : isTieBreak
                ? 'text-white text-8xl sm:text-9xl md:text-[140px] lg:text-[180px]'
                : 'text-white text-8xl sm:text-9xl md:text-[140px] lg:text-[180px]'
            }`}
            style={{
              textShadow: isAdvantage
                ? '0 0 40px rgba(251, 191, 36, 0.6)'
                : `0 0 30px ${glowShadow}, 0 4px 12px rgba(0,0,0,0.8)`,
            }}
          >
            {scoreText}
          </span>

          {/* Golden point indicator tag over the score */}
          {isDeuce && isGoldenPoint && (
            <div className="absolute -top-8 px-4 py-1 rounded-full bg-rose-600 text-white font-black text-xs sm:text-sm tracking-widest uppercase shadow-lg shadow-rose-600/50 animate-bounce">
              🔥 PUNTO DECISIVO 🔥
            </div>
          )}
        </div>

        <span className="text-xs text-slate-500 font-bold uppercase tracking-widest mt-2 group-hover:text-slate-400 transition-colors">
          Tocca per punto
        </span>
      </div>

      {/* BOTTOM: Current Games in Set */}
      <div className="z-10">
        <div
          className={`flex items-center justify-between px-5 py-3 rounded-xl bg-slate-900/90 border ${borderHighlightClass} shadow-md`}
        >
          <span className="text-xs sm:text-sm font-extrabold uppercase tracking-widest text-slate-400">
            Game nel Set:
          </span>
          <span className={`text-2xl sm:text-3xl font-black ${primaryColorClass}`}>
            {gamesWon}
          </span>
        </div>
      </div>
    </div>
  );
};
