import React from 'react';
import { Team } from '../types/padel';

interface TeamColumnProps {
  team: Team;
  teamName: string;
  playersText: string;
  servingPlayerName: string;
  scoreText: string;
  gamesWon: number;
  isServing: boolean;
  accentColor: 'lime' | 'cyan';
  isTieBreak: boolean;
  isGoldenPoint: boolean;
  isDeuce: boolean;
  onAddPoint: () => void;
  onToggleServer: (e: React.MouseEvent) => void;
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
  onToggleServer,
}) => {
  const isLime = accentColor === 'lime';
  const primaryColorClass = isLime ? 'text-[#CCFF00]' : 'text-[#00E5FF]';
  const borderHighlightClass = isLime ? 'border-[#CCFF00]/40' : 'border-[#00E5FF]/40';
  const glowShadow = isLime ? 'rgba(204, 255, 0, 0.35)' : 'rgba(0, 229, 255, 0.35)';

  const isAdvantage = scoreText === 'AV';

  return (
    <div
      onClick={onAddPoint}
      className={`relative flex-1 flex flex-col justify-between p-4 sm:p-6 lg:p-7 cursor-pointer select-none transition-all duration-150 active:scale-[0.99] group overflow-hidden ${
        isServing ? 'bg-slate-900/40' : 'bg-slate-950/30'
      }`}
      style={{
        boxShadow: isServing ? `inset 0 0 80px ${isLime ? 'rgba(204, 255, 0, 0.05)' : 'rgba(0, 229, 255, 0.05)'}` : 'none',
      }}
    >
      <div className={`absolute inset-0 opacity-0 group-hover:opacity-5 transition-opacity ${isLime ? 'bg-[#CCFF00]' : 'bg-[#00E5FF]'}`} />

      {/* TOP: Team Name, Players & IN BATTUTA Indicator */}
      <div className="flex flex-col gap-2 z-10">
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

          {/* Toggle Service Quick Button */}
          <button
            onClick={onToggleServer}
            title="Clicca per passare il servizio al prossimo battitore"
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full transition-all border cursor-pointer ${
              isServing
                ? 'bg-[#CCFF00] text-slate-950 border-[#CCFF00] shadow-md shadow-[#CCFF00]/40 font-black'
                : 'bg-slate-900/80 text-slate-400 border-slate-800 hover:text-slate-200 hover:border-slate-700'
            }`}
          >
            <svg className="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" fill={isServing ? '#E8FF59' : '#475569'} stroke={isServing ? '#88AA00' : '#1E293B'} strokeWidth="1.5" />
              <path d="M4.5 7.5C8 8.5 10 11.5 10 16.5" stroke={isServing ? '#FFFFFF' : '#334155'} strokeWidth="1.5" strokeLinecap="round" />
              <path d="M19.5 16.5C16 15.5 14 12.5 14 7.5" stroke={isServing ? '#FFFFFF' : '#334155'} strokeWidth="1.5" strokeLinecap="round" />
            </svg>
            <span className="text-[11px] font-black uppercase">
              {isServing ? 'Servizio' : 'Batti'}
            </span>
          </button>
        </div>

        {/* VISUALIZZAZIONE ULTRA CHIARA: IN BATTUTA: [NOME GIOCATORE] */}
        {isServing ? (
          <div className="self-start inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-[#CCFF00] text-slate-950 font-black text-xs sm:text-sm tracking-wider uppercase shadow-lg shadow-[#CCFF00]/50 animate-pulse border border-[#CCFF00]">
            <span className="w-2 h-2 rounded-full bg-slate-950" />
            <span>IN BATTUTA: <strong>{servingPlayerName.toUpperCase()}</strong></span>
          </div>
        ) : (
          <div className="h-6" /> // spacer to balance columns
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
          Tocca per assegnare punto
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
