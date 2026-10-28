import React from 'react';
import { calculatePointAnalytics, type PointEvent } from '../engine/matchPointAnalytics';

interface Props { pointEvents?: PointEvent[]; teamAName: string; teamBName: string; }
const fmt = (n: number | null) => n === null ? '—' : `${n.toFixed(1)}%`;
/** Analisi offline dei punti realmente tracciati; nessuna stima sui match legacy. */
export const MatchPointAnalyticsPanel: React.FC<Props> = ({ pointEvents, teamAName, teamBName }) => {
  const stats = pointEvents === undefined ? null : calculatePointAnalytics(pointEvents);
  if (!stats) return <section className="rounded-2xl border border-slate-700 bg-slate-900 p-4 text-slate-300 text-sm">
    Analisi punto per punto non disponibile per questa partita. Il tracciamento inizia dalle nuove partite.
  </section>;
  const points = stats.timeline;
  // Solo il rendering del grafico è campionato: i conteggi usano TUTTI gli eventi.
  const stride = Math.max(1, Math.ceil((points.length - 1) / 140));
  const shown = points.filter((_, i) => i === 0 || i === points.length - 1 || i % stride === 0);
  const x = (index: number) => 12 + index / Math.max(1, stats.totalPoints) * 376;
  const y = (n: number) => 164 - n / Math.max(1, stats.pointsA, stats.pointsB) * 145;
  const path = (team: 'a' | 'b') => shown.map((point, i) => `${i ? 'L' : 'M'}${x(point.index).toFixed(2)} ${y(point[team]).toFixed(2)}`).join(' ');
  return <section className="rounded-2xl border border-slate-700 bg-slate-900 p-4 sm:p-6 space-y-4 text-white" aria-label="Analisi punto per punto">
    <div className="flex flex-wrap items-center justify-between gap-2"><h3 className="font-black text-base uppercase tracking-wide">Analisi punto per punto</h3><span className="text-xs text-slate-400">{stats.totalPoints} punti tracciati</span></div>
    <div className="grid grid-cols-2 gap-3">
      {[{name:teamAName,score:stats.pointsA,share:stats.pointShareA,color:'#CCFF00'}, {name:teamBName,score:stats.pointsB,share:stats.pointShareB,color:'#00E5FF'}].map(team =>
        <div key={team.color} className="rounded-xl border border-slate-700 p-3 bg-slate-950/50"><div className="truncate text-xs" title={team.name}>{team.name}</div><div className="text-3xl font-black" style={{ color:team.color }}>{team.score}</div><div className="text-xs text-slate-400">{fmt(team.share)} dei punti</div></div>)}
    </div>
    <div className="space-y-2"><div className="text-sm text-slate-300 font-bold">Progressione dei punti cumulativi</div>
      <svg viewBox="0 0 400 180" role="img" aria-label={`Progressione dei punti: ${teamAName} ${stats.pointsA}, ${teamBName} ${stats.pointsB}`} className="w-full rounded-xl bg-slate-950 border border-slate-800">
        {[0,1,2,3,4].map(i => <line key={i} x1="12" x2="388" y1={19+i*36.25} y2={19+i*36.25} stroke="#2e3a4c" strokeWidth="0.7"/>)}
        <path d={path('a')} fill="none" stroke="#CCFF00" strokeWidth="3" strokeLinejoin="round"/>
        <path d={path('b')} fill="none" stroke="#00E5FF" strokeWidth="3" strokeLinejoin="round"/>
      </svg>
      <div className="flex gap-4 text-xs"><span className="text-[#CCFF00]">● {teamAName}</span><span className="text-[#00E5FF]">● {teamBName}</span></div>
    </div>
    <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-xs">
      {[
        ['Serie massima', `${stats.longestStreakA} – ${stats.longestStreakB}`],
        ['Cambi di vantaggio', String(stats.leadChanges)],
        ["Punti d'oro", `${stats.goldenPointsA} – ${stats.goldenPointsB}`],
        ['Punti in tie-break', `${stats.tieBreakPointsA} – ${stats.tieBreakPointsB}`],
        ['Game conquistati', `${stats.gamesWonA} – ${stats.gamesWonB}`],
        ['Game in risposta', `${stats.breakGamesA} – ${stats.breakGamesB}`],
      ].map(([label, value]) => <div key={label} className="rounded-xl bg-slate-950/70 p-3"><div className="text-slate-400">{label}</div><div className="font-black text-white text-base">{value}</div></div>)}
    </div>
    {stats.lastTen.length > 0 && <div className="space-y-2"><h4 className="text-xs font-bold uppercase text-slate-300">Ultimi 10 punti</h4>
      <ol className="grid gap-1 text-xs">{stats.lastTen.map(ev => <li key={ev.index} className="flex justify-between gap-3 rounded-lg p-2 bg-slate-950/70"><span className="text-slate-400">#{ev.index} · Set {ev.setNumber} · {Math.floor(ev.elapsedSeconds / 60)}:{String(ev.elapsedSeconds % 60).padStart(2,'0')}</span><span className={ev.team === 'teamA' ? 'text-[#CCFF00]' : 'text-[#00E5FF]'}>{ev.team === 'teamA' ? teamAName : teamBName}{ev.isGoldenPoint ? " · Oro" : ''}{ev.isTieBreak ? ' · TB' : ''}</span></li>)}</ol>
    </div>}
    <p className="text-[11px] text-slate-400">Le analisi riguardano le squadre: colpi vincenti ed errori dei singoli giocatori non vengono misurati automaticamente.</p>
  </section>;
};
