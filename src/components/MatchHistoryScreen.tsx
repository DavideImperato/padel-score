import React, { useState } from 'react';
import { ArrowLeft, CalendarDays, Clock3, Trash2, Trophy, AlertTriangle } from 'lucide-react';
import { ArchivedMatch, loadMatchHistory, removeArchivedMatch } from '../engine/matchHistory';

interface Props { onBack: () => void }
const formatDuration = (n: number) => `${Math.floor(n / 3600).toString().padStart(2, '0')}:${Math.floor(n % 3600 / 60).toString().padStart(2, '0')}:${(n % 60).toString().padStart(2, '0')}`;
const setLabel = (s: ArchivedMatch['sets'][number]): string =>
  s.isMatchTieBreak ? `MTB ${s.tieBreakPointsA ?? 0}–${s.tieBreakPointsB ?? 0}` :
  `${s.gamesA}–${s.gamesB}${s.tieBreakPointsA != null && s.tieBreakPointsB != null ? ` (TB ${s.tieBreakPointsA}–${s.tieBreakPointsB})` : ''}`;

export const MatchHistoryScreen: React.FC<Props> = ({ onBack }) => {
  const [items, setItems] = useState<ArchivedMatch[]>(() => loadMatchHistory(window.localStorage));
  const [opened, setOpened] = useState<string | null>(null);
  const [pendingDelete, setPendingDelete] = useState<ArchivedMatch | null>(null);
  const [feedback, setFeedback] = useState<{ error: boolean; text: string } | null>(null);

  const requestDelete = (item: ArchivedMatch) => {
    setFeedback(null);
    setPendingDelete(item);
  };

  const confirmDelete = () => {
    if (!pendingDelete) return;
    const id = pendingDelete.id;
    if (!removeArchivedMatch(window.localStorage, id)) {
      setFeedback({
        error: true,
        text: 'Impossibile eliminare il risultato. I dati dello storico non sono stati modificati.',
      });
      setPendingDelete(null);
      return;
    }
    setItems(loadMatchHistory(window.localStorage));
    setOpened(previous => previous === id ? null : previous);
    setPendingDelete(null);
    setFeedback({ error: false, text: 'Partita eliminata dallo storico.' });
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white overflow-y-auto p-5 sm:p-8">
      <div className="mx-auto max-w-4xl space-y-5">
        <header className="flex flex-wrap items-center gap-4 border-b border-slate-800 pb-5">
          <button type="button" onClick={onBack} className="flex items-center gap-2 rounded-xl bg-slate-800 px-4 py-3 text-sm font-bold"><ArrowLeft size={17}/> Setup</button>
          <div><h1 className="text-xl font-black tracking-wide text-[#CCFF00]">STORICO PARTITE</h1><p className="text-sm text-slate-400">{items.length} partite concluse · Dati salvati sul dispositivo</p></div>
        </header>
        {feedback && (
          <div role="status" aria-live="polite" className={`rounded-xl border p-3 text-sm ${feedback.error ? 'border-rose-700 bg-rose-950/60 text-rose-200' : 'border-emerald-700 bg-emerald-950/50 text-emerald-200'}`}>
            {feedback.text}
          </div>
        )}
        {!items.length && <div className="rounded-2xl border border-slate-700 bg-slate-900 p-8 text-center text-slate-300">Nessuna partita conclusa salvata. Termina un match e scegli di archiviarlo dal riepilogo.</div>}
        {items.map(item => (
          <article key={item.id} className="rounded-2xl border border-slate-700 bg-slate-900 p-4 sm:p-5 space-y-3">
            <div className="flex flex-wrap justify-between items-center gap-3">
              <div className="flex items-center gap-2 text-[#CCFF00] font-black"><Trophy size={17}/>{item.winner === 'teamA' ? item.teamAName : item.teamBName} · Vincitore</div>
              <button type="button" onClick={() => requestDelete(item)} aria-label={`Elimina ${item.teamAName} contro ${item.teamBName} dallo storico`} title="Elimina risultato" className="rounded-lg border border-rose-700/50 p-2 text-rose-300 hover:bg-rose-900/20"><Trash2 size={17}/></button>
            </div>
            <div className="grid grid-cols-[1fr_auto_1fr] gap-2 items-center text-center font-black text-base sm:text-xl">
              <span>{item.teamAName}</span><span className="text-slate-500 text-xs">VS</span><span>{item.teamBName}</span>
            </div>
            <div className="flex gap-4 flex-wrap justify-center text-sm text-slate-400">
              <span className="flex items-center gap-1"><CalendarDays size={15}/>{new Date(item.completedAt).toLocaleString('it-IT')}</span>
              <span className="flex items-center gap-1"><Clock3 size={15}/>{formatDuration(item.durationSeconds)}</span>
            </div>
            <div className="flex justify-center flex-wrap gap-2 text-sm font-bold">{item.sets.map((s, i) => <span key={i} className="rounded-lg bg-slate-800 px-3 py-2">Set {i + 1}: {setLabel(s)}</span>)}</div>
            <button type="button" onClick={() => setOpened(opened === item.id ? null : item.id)} className="text-sm font-bold text-cyan-300 underline underline-offset-4">{opened === item.id ? 'Nascondi dettagli' : 'Dettagli e giocatori'}</button>
            {opened === item.id && <div className="grid gap-2 sm:grid-cols-2 text-sm text-slate-300 border-t border-slate-700 pt-3"><div><strong className="text-[#CCFF00]">{item.teamAName}</strong><p>{item.players[0]} · {item.players[1]}</p></div><div><strong className="text-cyan-300">{item.teamBName}</strong><p>{item.players[2]} · {item.players[3]}</p></div><p>Formato: al meglio di {item.bestOfSets} set · {item.gamesPerSet} game</p></div>}
          </article>
        ))}
      </div>

      {/* Conferma interna all'app: window.confirm può essere bloccato nelle anteprime iframe. */}
      {pendingDelete && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/85 p-4 backdrop-blur-sm">
          <div role="alertdialog" aria-modal="true" aria-labelledby="history-delete-title" aria-describedby="history-delete-description" onKeyDown={event => { if (event.key === 'Escape') setPendingDelete(null); }} className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl space-y-5">
            <div className="flex items-center gap-3 text-rose-300"><AlertTriangle size={22}/><h2 id="history-delete-title" className="text-lg font-black text-white">Eliminare questa partita?</h2></div>
            <p id="history-delete-description" className="text-sm leading-relaxed text-slate-300">
              {pendingDelete.teamAName} vs {pendingDelete.teamBName}. Il risultato verrà rimosso definitivamente dallo storico di questo dispositivo.
            </p>
            <div className="flex flex-wrap justify-end gap-3">
              <button type="button" autoFocus onClick={() => setPendingDelete(null)} className="rounded-xl border border-slate-600 bg-slate-800 px-5 py-3 text-sm font-bold text-white hover:bg-slate-700">Annulla</button>
              <button type="button" onClick={confirmDelete} className="rounded-xl bg-rose-600 px-5 py-3 text-sm font-black text-white hover:bg-rose-500">Elimina definitivamente</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
