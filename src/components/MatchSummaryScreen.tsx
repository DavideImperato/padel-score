import React from 'react';
import { Trophy, Clock, ArrowLeft, RotateCcw, Award, CheckCircle2, Sparkles, Eye } from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot, SetScore, Team } from '../types/padel';

interface MatchSummaryScreenProps {
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  matchDurationFormatted: string;
  onGoToSetup: () => void;
  onReturnToScoreboard?: () => void;
}

export const MatchSummaryScreen: React.FC<MatchSummaryScreenProps> = ({
  snapshot,
  settings,
  matchDurationFormatted,
  onGoToSetup,
  onReturnToScoreboard,
}) => {
  // Combine completed sets and any in-progress set
  const allSets: Array<{
    setNumber: number;
    gamesA: number;
    gamesB: number;
    tieBreakA?: number;
    tieBreakB?: number;
    winner?: Team;
    isIncomplete?: boolean;
  }> = snapshot.completedSets.map((s, idx) => ({
    setNumber: idx + 1,
    gamesA: s.gamesA,
    gamesB: s.gamesB,
    tieBreakA: s.tieBreakPointsA,
    tieBreakB: s.tieBreakPointsB,
    winner: s.winner,
    isIncomplete: false,
  }));

  // If there were games played in the current uncompleted set
  if (
    snapshot.currentGamesA > 0 ||
    snapshot.currentGamesB > 0 ||
    snapshot.rawPointsA > 0 ||
    snapshot.rawPointsB > 0 ||
    snapshot.tieBreakPointsA > 0 ||
    snapshot.tieBreakPointsB > 0
  ) {
    allSets.push({
      setNumber: snapshot.completedSets.length + 1,
      gamesA: snapshot.currentGamesA,
      gamesB: snapshot.currentGamesB,
      tieBreakA: snapshot.isTieBreak ? snapshot.tieBreakPointsA : undefined,
      tieBreakB: snapshot.isTieBreak ? snapshot.tieBreakPointsB : undefined,
      winner:
        snapshot.currentGamesA > snapshot.currentGamesB
          ? 'teamA'
          : snapshot.currentGamesB > snapshot.currentGamesA
          ? 'teamB'
          : undefined,
      isIncomplete: true,
    });
  }

  // Determine overall winner
  const setsWonA = snapshot.completedSets.filter((s) => s.winner === 'teamA').length;
  const setsWonB = snapshot.completedSets.filter((s) => s.winner === 'teamB').length;

  let overallWinner: Team | 'tie' = 'tie';
  if (snapshot.matchWinner) {
    overallWinner = snapshot.matchWinner;
  } else if (setsWonA > setsWonB) {
    overallWinner = 'teamA';
  } else if (setsWonB > setsWonA) {
    overallWinner = 'teamB';
  } else {
    // Check total games
    const totalGamesA =
      snapshot.completedSets.reduce((sum, s) => sum + s.gamesA, 0) + snapshot.currentGamesA;
    const totalGamesB =
      snapshot.completedSets.reduce((sum, s) => sum + s.gamesB, 0) + snapshot.currentGamesB;
    if (totalGamesA > totalGamesB) overallWinner = 'teamA';
    else if (totalGamesB > totalGamesA) overallWinner = 'teamB';
    else overallWinner = 'tie';
  }

  const isTeamAWinner = overallWinner === 'teamA';
  const isTeamBWinner = overallWinner === 'teamB';
  const isTie = overallWinner === 'tie';

  const winnerTeamName = isTeamAWinner
    ? settings.teamAName
    : isTeamBWinner
    ? settings.teamBName
    : 'Parità';

  const winnerPlayers = isTeamAWinner
    ? `${settings.player1Name} & ${settings.player2Name}`
    : isTeamBWinner
    ? `${settings.player3Name} & ${settings.player4Name}`
    : `${settings.player1Name}, ${settings.player2Name}, ${settings.player3Name}, ${settings.player4Name}`;

  const totalGamesTeamA =
    snapshot.completedSets.reduce((acc, s) => acc + s.gamesA, 0) + snapshot.currentGamesA;
  const totalGamesTeamB =
    snapshot.completedSets.reduce((acc, s) => acc + s.gamesB, 0) + snapshot.currentGamesB;

  return (
    <div className="min-h-screen w-full bg-[#070B14] text-white flex flex-col font-sans select-none overflow-y-auto">
      {/* Header */}
      <header className="px-6 py-4 bg-slate-950 border-b border-slate-800 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-[#CCFF00] text-slate-950 shadow-md shadow-[#CCFF00]/30">
            <Trophy className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-base sm:text-lg font-black tracking-wider uppercase text-white">
              PADEL SCOREBOT — RIEPILOGO FINALE MATCH
            </h1>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {onReturnToScoreboard && (
            <button
              onClick={onReturnToScoreboard}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 hover:border-slate-700 text-xs text-slate-300 font-bold transition-colors cursor-pointer"
            >
              <Eye className="w-3.5 h-3.5 text-slate-400" />
              <span>Rivedi Tabellone</span>
            </button>
          )}
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 flex flex-col items-center justify-center p-4 sm:p-6 lg:p-8 max-w-5xl mx-auto w-full space-y-6">
        {/* WINNER HERO BANNER */}
        <div className="w-full relative overflow-hidden rounded-3xl p-6 sm:p-8 text-center bg-gradient-to-b from-slate-900 to-slate-950 border border-slate-800 shadow-2xl">
          <div className="absolute inset-0 bg-radial from-[#CCFF00]/5 via-transparent to-transparent pointer-events-none" />

          <div className="flex justify-center mb-3">
            <div className="p-4 rounded-2xl bg-amber-500/20 text-amber-300 border border-amber-500/40 shadow-lg shadow-amber-500/20 animate-bounce">
              <Trophy className="w-10 h-10 sm:w-12 sm:h-12" />
            </div>
          </div>

          <div className="text-xs sm:text-sm font-black uppercase tracking-widest text-slate-400 mb-1">
            {isTie ? 'RISULTATO FINALE' : 'SQUADRA VINCITRICE'}
          </div>

          <h2
            className={`text-3xl sm:text-5xl font-black uppercase tracking-wider ${
              isTeamAWinner
                ? 'text-[#CCFF00]'
                : isTeamBWinner
                ? 'text-[#00E5FF]'
                : 'text-amber-300'
            }`}
            style={{
              textShadow: isTeamAWinner
                ? '0 0 30px rgba(204, 255, 0, 0.4)'
                : isTeamBWinner
                ? '0 0 30px rgba(0, 229, 255, 0.4)'
                : 'none',
            }}
          >
            {winnerTeamName}
          </h2>

          <p className="text-sm sm:text-base text-slate-300 font-bold mt-2">
            {winnerPlayers}
          </p>

          <div className="inline-flex items-center gap-2 mt-4 px-4 py-1.5 rounded-full bg-slate-800/90 border border-slate-700 text-xs sm:text-sm font-mono font-bold text-slate-200">
            <Clock className="w-4 h-4 text-emerald-400" />
            <span>Tempo Totale di Gioco: <strong className="text-white">{matchDurationFormatted}</strong></span>
          </div>
        </div>

        {/* DETAILED SETS SCORE TABLE */}
        <div className="w-full bg-slate-900/90 border border-slate-800 rounded-3xl p-5 sm:p-6 shadow-xl backdrop-blur-sm space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div className="flex items-center gap-2">
              <Award className="w-5 h-5 text-[#CCFF00]" />
              <h3 className="text-base font-black tracking-wide text-white uppercase">
                Punteggio Dettagliato dei Set
              </h3>
            </div>
            <div className="text-xs text-slate-400 font-bold">
              {settings.isGoldenPoint ? "Punto d'Oro" : 'Vantaggi'} • Al meglio dei {settings.bestOfSets} Set
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-800 text-[11px] font-black uppercase tracking-wider text-slate-400">
                  <th className="py-3 px-4">Squadra</th>
                  {allSets.map((s) => (
                    <th key={s.setNumber} className="py-3 px-4 text-center">
                      SET {s.setNumber}
                      {s.isIncomplete && <span className="block text-[9px] text-amber-400 font-normal">in corso</span>}
                    </th>
                  ))}
                  <th className="py-3 px-4 text-center text-[#CCFF00]">Totale Game</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-sm font-bold">
                {/* TEAM A ROW */}
                <tr className={`transition-colors ${isTeamAWinner ? 'bg-[#CCFF00]/5' : ''}`}>
                  <td className="py-4 px-4">
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-[#CCFF00] shrink-0" />
                      <span className="text-base font-black text-white">{settings.teamAName}</span>
                      {isTeamAWinner && (
                        <CheckCircle2 className="w-4 h-4 text-[#CCFF00] ml-1 shrink-0" />
                      )}
                    </div>
                    <div className="text-xs text-slate-400 font-medium pl-4">
                      {settings.player1Name} & {settings.player2Name}
                    </div>
                  </td>
                  {allSets.map((s) => {
                    const isSetWinner = s.winner === 'teamA';
                    return (
                      <td key={s.setNumber} className="py-4 px-4 text-center">
                        <span
                          className={`inline-block px-3 py-1.5 rounded-xl font-mono text-base font-black ${
                            isSetWinner
                              ? 'bg-[#CCFF00]/20 text-[#CCFF00] border border-[#CCFF00]/40'
                              : 'text-slate-300'
                          }`}
                        >
                          {s.gamesA}
                          {s.tieBreakA !== undefined && s.tieBreakB !== undefined && (
                            <sup className="text-[10px] ml-0.5 text-slate-400">
                              ({s.tieBreakA})
                            </sup>
                          )}
                        </span>
                      </td>
                    );
                  })}
                  <td className="py-4 px-4 text-center font-mono text-lg font-black text-[#CCFF00]">
                    {totalGamesTeamA}
                  </td>
                </tr>

                {/* TEAM B ROW */}
                <tr className={`transition-colors ${isTeamBWinner ? 'bg-cyan-500/5' : ''}`}>
                  <td className="py-4 px-4">
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-[#00E5FF] shrink-0" />
                      <span className="text-base font-black text-white">{settings.teamBName}</span>
                      {isTeamBWinner && (
                        <CheckCircle2 className="w-4 h-4 text-[#00E5FF] ml-1 shrink-0" />
                      )}
                    </div>
                    <div className="text-xs text-slate-400 font-medium pl-4">
                      {settings.player3Name} & {settings.player4Name}
                    </div>
                  </td>
                  {allSets.map((s) => {
                    const isSetWinner = s.winner === 'teamB';
                    return (
                      <td key={s.setNumber} className="py-4 px-4 text-center">
                        <span
                          className={`inline-block px-3 py-1.5 rounded-xl font-mono text-base font-black ${
                            isSetWinner
                              ? 'bg-cyan-500/20 text-[#00E5FF] border border-cyan-400/40'
                              : 'text-slate-300'
                          }`}
                        >
                          {s.gamesB}
                          {s.tieBreakA !== undefined && s.tieBreakB !== undefined && (
                            <sup className="text-[10px] ml-0.5 text-slate-400">
                              ({s.tieBreakB})
                            </sup>
                          )}
                        </span>
                      </td>
                    );
                  })}
                  <td className="py-4 px-4 text-center font-mono text-lg font-black text-[#00E5FF]">
                    {totalGamesTeamB}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        {/* BOTTOM ACTION BUTTON: "TORNA ALLA PAGINA INIZIALE" */}
        <div className="w-full pt-2 flex flex-col sm:flex-row items-center justify-center gap-4">
          <button
            onClick={onGoToSetup}
            className="w-full sm:w-auto px-8 py-4 rounded-2xl bg-[#CCFF00] hover:bg-[#b8e600] text-slate-950 font-black text-base sm:text-lg tracking-wider uppercase shadow-xl shadow-[#CCFF00]/30 transition-all flex items-center justify-center gap-3 cursor-pointer active:scale-95"
          >
            <ArrowLeft className="w-5 h-5" />
            <span>Torna alla Pagina Iniziale</span>
          </button>
        </div>
      </main>
    </div>
  );
};
