import React from 'react';
import { Undo2, Hourglass, RefreshCw, Sparkles, Monitor } from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot, Team } from '../types/padel';

interface SmartwatchScoreboardProps {
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  canUndo: boolean;
  matchTimeFormatted: string;
  isTimerRunning: boolean;
  servingPlayerName: string;
  onAddPoint: (team: Team) => void;
  onUndo: () => void;
  onToggleServingTeam: () => void;
  onStartBreak: () => void;
  onExitSmartwatchMode?: () => void;
}

export const SmartwatchScoreboard: React.FC<SmartwatchScoreboardProps> = ({
  snapshot,
  settings,
  canUndo,
  matchTimeFormatted,
  servingPlayerName,
  onAddPoint,
  onUndo,
  onToggleServingTeam,
  onStartBreak,
  onExitSmartwatchMode,
}) => {
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

  const scoreA = snapshot.isTieBreak
    ? snapshot.tieBreakPointsA.toString()
    : getPointLabel(snapshot.rawPointsA);

  const scoreB = snapshot.isTieBreak
    ? snapshot.tieBreakPointsB.toString()
    : getPointLabel(snapshot.rawPointsB);

  const isServingA = snapshot.servingTeam === 'teamA';
  const isServingB = snapshot.servingTeam === 'teamB';
  const currentSetNum = snapshot.completedSets.length + 1;

  return (
    <div className="w-full h-screen bg-black text-white flex flex-col justify-between p-2 sm:p-3 select-none font-sans overflow-hidden">
      {/* 1. TOP BAR: Set, Timer, Golden Point tag */}
      <div className="flex items-center justify-between px-1 shrink-0 text-[10px] font-black border-b border-slate-900 pb-1">
        <div className="flex items-center gap-1">
          <span className="text-[#CCFF00]">SET {currentSetNum}</span>
          {snapshot.isTieBreak && <span className="text-purple-400 font-bold">TB</span>}
        </div>

        <div className="font-mono text-slate-300 font-bold">
          {matchTimeFormatted}
        </div>

        {onExitSmartwatchMode && (
          <button
            onClick={onExitSmartwatchMode}
            title="Torna alla vista completa"
            className="text-slate-400 hover:text-white p-0.5"
          >
            <Monitor className="w-3.5 h-3.5" />
          </button>
        )}
      </div>

      {/* 2. MAIN SPLIT TOUCH SCORE BUTTONS (Giant tap targets for wrist play) */}
      <div className="flex-1 flex flex-col gap-1.5 py-1 justify-center">
        {/* TEAM 1 BUTTON */}
        <button
          onClick={() => onAddPoint('teamA')}
          className={`w-full flex-1 rounded-2xl p-2 flex items-center justify-between border transition-transform active:scale-95 cursor-pointer ${
            isServingA
              ? 'bg-slate-900 border-[#CCFF00]/80 shadow-md shadow-[#CCFF00]/15'
              : 'bg-slate-950 border-slate-800'
          }`}
        >
          <div className="text-left truncate pr-1">
            <div className="text-xs font-black text-[#CCFF00] truncate flex items-center gap-1">
              {isServingA && <span className="w-2 h-2 rounded-full bg-[#CCFF00] shrink-0" />}
              <span className="truncate">{settings.teamAName}</span>
            </div>
            <div className="text-[10px] text-slate-400 font-bold">
              G: {snapshot.currentGamesA}
            </div>
          </div>

          <div className="text-4xl sm:text-5xl font-black font-mono text-white tracking-tighter">
            {scoreA}
          </div>
        </button>

        {/* TEAM 2 BUTTON */}
        <button
          onClick={() => onAddPoint('teamB')}
          className={`w-full flex-1 rounded-2xl p-2 flex items-center justify-between border transition-transform active:scale-95 cursor-pointer ${
            isServingB
              ? 'bg-slate-900 border-cyan-400/80 shadow-md shadow-cyan-400/15'
              : 'bg-slate-950 border-slate-800'
          }`}
        >
          <div className="text-left truncate pr-1">
            <div className="text-xs font-black text-cyan-400 truncate flex items-center gap-1">
              {isServingB && <span className="w-2 h-2 rounded-full bg-cyan-400 shrink-0" />}
              <span className="truncate">{settings.teamBName}</span>
            </div>
            <div className="text-[10px] text-slate-400 font-bold">
              G: {snapshot.currentGamesB}
            </div>
          </div>

          <div className="text-4xl sm:text-5xl font-black font-mono text-white tracking-tighter">
            {scoreB}
          </div>
        </button>
      </div>

      {/* 3. IN BATTUTA QUICK CHIP */}
      <div className="text-center text-[10px] text-slate-400 truncate py-0.5">
        Batte: <strong className="text-white">{servingPlayerName}</strong>
      </div>

      {/* 4. BOTTOM ACTION CONTROL BUTTONS (Optimized for quick thumb taps) */}
      <div className="grid grid-cols-3 gap-1.5 shrink-0 pt-1 border-t border-slate-900">
        <button
          onClick={onUndo}
          disabled={!canUndo}
          title="Undo"
          className={`py-2 rounded-xl border flex items-center justify-center cursor-pointer active:scale-90 ${
            canUndo
              ? 'bg-slate-900 border-slate-700 text-white'
              : 'bg-slate-950 text-slate-700 border-slate-900 cursor-not-allowed opacity-40'
          }`}
        >
          <Undo2 className="w-4 h-4" />
        </button>

        <button
          onClick={onToggleServingTeam}
          title="Cambia Battitore"
          className="py-2 rounded-xl bg-[#CCFF00]/15 border border-[#CCFF00]/50 text-[#CCFF00] flex items-center justify-center cursor-pointer active:scale-90"
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="9" fill="#CCFF00" stroke="#99CC00" strokeWidth="1.5" />
            <path d="M4.5 7.5C8 8.5 10 11.5 10 16.5" stroke="#1E293B" strokeWidth="1.6" strokeLinecap="round" />
            <path d="M19.5 16.5C16 15.5 14 12.5 14 7.5" stroke="#1E293B" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
        </button>

        <button
          onClick={onStartBreak}
          title="Pausa 90s"
          className="py-2 rounded-xl bg-slate-900 border border-cyan-500/40 text-cyan-300 flex items-center justify-center cursor-pointer active:scale-90"
        >
          <Hourglass className="w-4 h-4 text-cyan-400" />
        </button>
      </div>
    </div>
  );
};
