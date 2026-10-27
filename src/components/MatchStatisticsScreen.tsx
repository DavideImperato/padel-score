import React, { useState } from 'react';
import { ArrowLeft, BarChart3, Trophy, Users } from 'lucide-react';
import { isArchivedMatch, loadMatchHistory, MAX_ARCHIVED_MATCHES, MATCH_HISTORY_KEY } from '../engine/matchHistory';
import { readPlayerDirectory } from '../engine/playerDirectory';
import { calculateMatchStatistics, StatisticsRow } from '../engine/matchStatistics';

function readStatistics() {
  try {
    const directory = readPlayerDirectory(window.localStorage);
    if (!directory) return { error: 'La rubrica giocatori non è leggibile. Nessun dato è stato modificato.' };
    const raw = window.localStorage.getItem(MATCH_HISTORY_KEY);
    if (raw !== null) {
      const decoded: unknown = JSON.parse(raw);
      if (!Array.isArray(decoded) || decoded.length > MAX_ARCHIVED_MATCHES || !decoded.every(isArchivedMatch)) {
        return { error: 'Lo storico partite non è leggibile. Nessun dato è stato modificato.' };
      }
    }
    return { data: calculateMatchStatistics(directory, loadMatchHistory(window.localStorage)) };
  } catch {
    return { error: 'Impossibile leggere le statistiche offline da questo dispositivo.' };
  }
}

const statCell = (label: string, value: string | number) => <div className="bg-slate-950 border border-slate-800 rounded-xl px-4 py-3">
  <div className="text-xs text-slate-400">{label}</div>
  <div className="text-xl font-black text-white mt-1">{value}</div>
</div>;

const rowCard = (row: StatisticsRow, rank: number) => <article key={row.id} className="bg-slate-900 border border-slate-800 rounded-xl p-4 space-y-3">
  <div className="flex items-start justify-between gap-2">
    <div><span className="text-slate-400 text-xs mr-2">#{rank + 1}</span><span className="font-bold">{row.name}</span></div>
    <span className="font-black text-[#CCFF00]">{row.winRate.toLocaleString('it-IT')}%</span>
  </div>
  <div className="grid grid-cols-3 gap-2 text-xs">
    <div>Giocate <strong className="block text-lg">{row.played}</strong></div>
    <div>Vittorie <strong className="block text-lg text-emerald-300">{row.wins}</strong></div>
    <div>Sconfitte <strong className="block text-lg">{row.losses}</strong></div>
  </div>
  <div className="text-slate-400 text-xs">Set vinti/persi: {row.setsWon}/{row.setsLost} · Partite con set brevi: {row.shortSets} · Standard: {row.standardSets}</div>
  {row.lastFive.length > 0 && <div className="flex items-center gap-2 text-xs text-slate-400">Ultime {row.lastFive.length}:
    {row.lastFive.map((v, i) => <span key={i} aria-label={v === 'W' ? 'Vittoria' : 'Sconfitta'} className={`w-6 h-6 flex items-center justify-center rounded font-bold ${v === 'W' ? 'bg-emerald-900 text-emerald-300' : 'bg-rose-950 text-rose-300'}`}>{v === 'W' ? 'V' : 'S'}</span>)}
  </div>}
</article>;

export const MatchStatisticsScreen: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  const [result] = useState(readStatistics);
  const [section, setSection] = useState<'players' | 'pairs'>('players');
  const data = result.data;
  const rows = data ? data[section] : [];
  const played = rows.filter(row => row.played > 0);
  return <main className="min-h-screen overflow-y-auto bg-[#070B14] text-white p-5 sm:p-8">
    <div className="mx-auto max-w-4xl space-y-6">
      <button onClick={onBack} className="flex gap-2 items-center text-slate-300 hover:text-white"><ArrowLeft size={17}/> Torna al setup</button>
      <div className="flex items-center gap-3"><BarChart3 className="text-[#CCFF00]"/><div><h1 className="text-2xl font-black">Statistiche</h1><p className="text-sm text-slate-400">Solo partite concluse e giocatori riconosciuti tramite ID · Tutto offline</p></div></div>
      {result.error ? <div role="alert" className="p-4 rounded-xl border border-red-700 text-red-300">{result.error}</div> : data && <>
        <div className="grid grid-cols-2 gap-3">
          {statCell('Partite concluse archiviate', data.totalCompleted)}
          {statCell('Senza collegamenti riconosciuti', data.unlinkedMatches)}
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={() => setSection('players')} aria-pressed={section === 'players'} className={`px-4 py-2 rounded-lg flex gap-2 items-center ${section === 'players' ? 'bg-[#CCFF00] text-black font-bold' : 'bg-slate-800'}`}><Users size={17}/> Giocatori</button>
          <button onClick={() => setSection('pairs')} aria-pressed={section === 'pairs'} className={`px-4 py-2 rounded-lg flex gap-2 items-center ${section === 'pairs' ? 'bg-[#CCFF00] text-black font-bold' : 'bg-slate-800'}`}><Trophy size={17}/> Coppie</button>
        </div>
        {rows.length === 0 ? <p className="text-slate-400">Nessun {section === 'players' ? 'giocatore' : 'duo'} registrato. Aggiungilo in Giocatori e coppie.</p> : played.length === 0 ? <p className="text-slate-400">Nessuna partita conclusa collegata a {section === 'players' ? 'questi giocatori' : 'queste coppie'}. Per le nuove partite seleziona i giocatori dalla rubrica nel setup.</p> : <div className="grid sm:grid-cols-2 gap-3">{played.map((row, index) => rowCard(row, index))}</div>}
        {played.length > 0 && rows.some(r => r.played === 0) && <p className="text-xs text-slate-400">{rows.length - played.length} {section === 'players' ? 'giocatori' : 'coppie'} senza partite registrate non compaiono in classifica.</p>}
        <p className="text-xs text-slate-400">Le partite interrotte e quelle senza ID non producono vittorie o sconfitte. Le statistiche sono ricalcolate dallo storico: eliminando un risultato, i totali si aggiornano alla successiva apertura.</p>
      </>}
    </div>
  </main>;
};
