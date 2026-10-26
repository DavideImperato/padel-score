import React from 'react';
import { SetScore } from '../types/padel';

interface SetsBarProps {
  completedSets: SetScore[];
  currentGamesA: number;
  currentGamesB: number;
  teamAName: string;
  teamBName: string;
}

export const SetsBar: React.FC<SetsBarProps> = ({
  completedSets,
  currentGamesA,
  currentGamesB,
  teamAName,
  teamBName,
}) => {
  const currentSetIndex = completedSets.length + 1;

  return (
    <footer className="bg-slate-950 border-t border-slate-800/90 px-4 py-2.5 flex items-center justify-between gap-4 shrink-0 overflow-x-auto select-none z-20">
      <div className="flex items-center gap-2 text-xs font-black tracking-wider uppercase text-slate-400 shrink-0">
        <span className="w-2.5 h-2.5 rounded-sm bg-[#CCFF00]" />
        <span>RISULTATO SET:</span>
      </div>

      <div className="flex items-center gap-3 overflow-x-auto">
        {completedSets.length === 0 && (
          <div className="px-3 py-1 rounded bg-slate-900 border border-slate-800 text-xs font-semibold text-slate-400 italic">
            1° Set in corso ({teamAName} {currentGamesA} - {currentGamesB} {teamBName})
          </div>
        )}

        {completedSets.map((set, idx) => {
          const isWonA = set.winner === 'teamA';
          return (
            <div
              key={idx}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border text-xs font-extrabold ${
                isWonA
                  ? 'bg-slate-900/90 border-[#CCFF00]/50 text-white'
                  : 'bg-slate-900/90 border-[#00E5FF]/50 text-white'
              }`}
            >
              <span className="text-slate-400 font-bold">Set {idx + 1}:</span>
              <span className={`text-sm ${isWonA ? 'text-[#CCFF00]' : 'text-slate-300'}`}>
                {set.isMatchTieBreak ? set.tieBreakPointsA : set.gamesA}
              </span>
              <span className="text-slate-500">-</span>
              <span className={`text-sm ${!isWonA ? 'text-[#00E5FF]' : 'text-slate-300'}`}>
                {set.isMatchTieBreak ? set.tieBreakPointsB : set.gamesB}
              </span>
              {!set.isMatchTieBreak && set.tieBreakPointsA !== undefined && set.tieBreakPointsB !== undefined && (
                <span className="text-[10px] text-purple-400 font-mono font-bold">
                  ({set.tieBreakPointsA}-{set.tieBreakPointsB})
                </span>
              )}
            </div>
          );
        })}

        {/* Current Set live box */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-[#CCFF00]/10 border border-[#CCFF00] text-xs font-black text-white">
          <span className="text-[#CCFF00] font-bold">Set {currentSetIndex} (in corso):</span>
          <span className="text-sm text-[#CCFF00]">{currentGamesA}</span>
          <span className="text-slate-400">-</span>
          <span className="text-sm text-[#00E5FF]">{currentGamesB}</span>
        </div>
      </div>

      <div className="hidden lg:flex items-center gap-2 text-xs font-bold text-slate-500 shrink-0">
        <span>Partita al meglio dei 3 set</span>
      </div>
    </footer>
  );
};
