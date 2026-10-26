import React from 'react';
import { Info, X, Trophy, Clock, Sparkles } from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot } from '../types/padel';

interface MatchInfoModalProps {
  isOpen: boolean;
  onClose: () => void;
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  matchDurationFormatted: string;
  servingPlayerName: string;
}

export const MatchInfoModal: React.FC<MatchInfoModalProps> = ({
  isOpen,
  onClose,
  snapshot,
  settings,
  matchDurationFormatted,
  servingPlayerName,
}) => {
  if (!isOpen) return null;

  const currentSetNum = snapshot.completedSets.length + 1;
  const setsToWin = Math.ceil(settings.bestOfSets / 2);

  // Calculate sets won so far
  let setsWonA = 0;
  let setsWonB = 0;
  snapshot.completedSets.forEach(set => {
    if (set.winner === 'teamA') setsWonA++;
    if (set.winner === 'teamB') setsWonB++;
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md select-none animate-in fade-in duration-200">
      <div className="w-full max-w-lg bg-slate-900 border border-slate-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-cyan-500/20 border border-cyan-500/40 flex items-center justify-center text-cyan-400">
              <Info className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-black tracking-wide text-white uppercase">
                Info & Risultati Match
              </h3>
              <p className="text-xs text-slate-400">
                Riepilogo set, statistiche e regole in vigore
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-5 overflow-y-auto">
          {/* 1. Sets Table */}
          <div className="rounded-2xl bg-slate-950 border border-slate-800 overflow-hidden">
            <div className="grid grid-cols-12 bg-slate-900/80 px-4 py-2.5 text-xs font-black uppercase tracking-wider text-slate-400 border-b border-slate-800">
              <span className="col-span-5">Squadra</span>
              {Array.from({ length: settings.bestOfSets }).map((_, idx) => (
                <span key={idx} className="col-span-2 text-center">
                  Set {idx + 1}
                </span>
              ))}
              <span className="col-span-1 text-right">Tot</span>
            </div>

            {/* Team A Row */}
            <div className="grid grid-cols-12 px-4 py-3 items-center border-b border-slate-800/60 text-sm">
              <div className="col-span-5 pr-2 truncate">
                <span className="font-black text-[#CCFF00] tracking-wide block truncate">
                  {settings.teamAName}
                </span>
                <span className="text-[11px] text-slate-400 truncate block">
                  {settings.player1Name} / {settings.player2Name}
                </span>
              </div>
              {Array.from({ length: settings.bestOfSets }).map((_, idx) => {
                const completedSet = snapshot.completedSets[idx];
                const isCurrent = idx === snapshot.completedSets.length && !snapshot.matchWinner;
                const score = completedSet
                  ? (completedSet.isMatchTieBreak ? completedSet.tieBreakPointsA : completedSet.gamesA)
                  : isCurrent
                  ? (snapshot.isMatchTieBreak ? snapshot.tieBreakPointsA : snapshot.currentGamesA)
                  : '-';
                const tb = !completedSet?.isMatchTieBreak && completedSet?.tieBreakPointsA !== undefined
                  ? `(${completedSet.tieBreakPointsA})`
                  : '';
                return (
                  <div
                    key={idx}
                    className={`col-span-2 text-center font-mono font-black ${
                      completedSet?.winner === 'teamA'
                        ? 'text-[#CCFF00] font-black text-base'
                        : isCurrent
                        ? 'text-white'
                        : 'text-slate-600'
                    }`}
                  >
                    {score}
                    {tb && <span className="text-[10px] text-slate-400 block">{tb}</span>}
                  </div>
                );
              })}
              <div className="col-span-1 text-right font-mono font-black text-base text-[#CCFF00]">
                {setsWonA}
              </div>
            </div>

            {/* Team B Row */}
            <div className="grid grid-cols-12 px-4 py-3 items-center text-sm">
              <div className="col-span-5 pr-2 truncate">
                <span className="font-black text-[#00E5FF] tracking-wide block truncate">
                  {settings.teamBName}
                </span>
                <span className="text-[11px] text-slate-400 truncate block">
                  {settings.player3Name} / {settings.player4Name}
                </span>
              </div>
              {Array.from({ length: settings.bestOfSets }).map((_, idx) => {
                const completedSet = snapshot.completedSets[idx];
                const isCurrent = idx === snapshot.completedSets.length && !snapshot.matchWinner;
                const score = completedSet
                  ? (completedSet.isMatchTieBreak ? completedSet.tieBreakPointsB : completedSet.gamesB)
                  : isCurrent
                  ? (snapshot.isMatchTieBreak ? snapshot.tieBreakPointsB : snapshot.currentGamesB)
                  : '-';
                const tb = !completedSet?.isMatchTieBreak && completedSet?.tieBreakPointsB !== undefined
                  ? `(${completedSet.tieBreakPointsB})`
                  : '';
                return (
                  <div
                    key={idx}
                    className={`col-span-2 text-center font-mono font-black ${
                      completedSet?.winner === 'teamB'
                        ? 'text-[#00E5FF] font-black text-base'
                        : isCurrent
                        ? 'text-white'
                        : 'text-slate-600'
                    }`}
                  >
                    {score}
                    {tb && <span className="text-[10px] text-slate-400 block">{tb}</span>}
                  </div>
                );
              })}
              <div className="col-span-1 text-right font-mono font-black text-base text-[#00E5FF]">
                {setsWonB}
              </div>
            </div>
          </div>

          {/* 2. Key Match Cards */}
          <div className="grid grid-cols-2 gap-3">
            <div className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-400 uppercase tracking-wider">
                <Clock className="w-3.5 h-3.5 text-cyan-400" />
                <span>Tempo Trascorso</span>
              </div>
              <div className="font-mono text-xl font-black text-white">
                {matchDurationFormatted}
              </div>
            </div>

            <div className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-400 uppercase tracking-wider">
                <Trophy className="w-3.5 h-3.5 text-amber-400" />
                <span>Formato</span>
              </div>
              <div className="text-sm font-black text-white">
                Al meglio dei {settings.bestOfSets} Set ({setsToWin} per vincere)
              </div>
            </div>

            <div className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-400 uppercase tracking-wider">
                <svg className="w-3.5 h-3.5 text-[#CCFF00]" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="9" fill="#CCFF00" />
                </svg>
                <span>In Battuta</span>
              </div>
              <div className="text-sm font-black text-white truncate">
                {servingPlayerName}
              </div>
              <span className="text-[10px] font-bold text-slate-400 block truncate">
                {snapshot.servingTeam === 'teamA' ? settings.teamAName : settings.teamBName}
              </span>
            </div>

            <div className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 space-y-1">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-400 uppercase tracking-wider">
                <Sparkles className="w-3.5 h-3.5 text-amber-400" />
                <span>Regola 40 Pari</span>
              </div>
              <div className="text-sm font-black text-white">
                {settings.isGoldenPoint
                  ? settings.advantagesBeforeGoldenPoint
                    ? `Punto d'Oro (${settings.advantagesBeforeGoldenPoint} ${
                        settings.advantagesBeforeGoldenPoint === 1 ? 'vantaggio' : 'vantaggi'
                      } prima)`
                    : "Punto d'Oro (Subito a 40-40)"
                  : 'Vantaggi Classici (AV)'}
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 bg-slate-950 border-t border-slate-800 flex justify-end">
          <button
            onClick={onClose}
            className="w-full sm:w-auto px-6 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs uppercase tracking-wider transition-all cursor-pointer"
          >
            Chiudi
          </button>
        </div>
      </div>
    </div>
  );
};
