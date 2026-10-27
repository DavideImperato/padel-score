import React, { useState } from 'react';
import { ArrowLeft, CalendarDays, Clock3, Trash2, Trophy, AlertTriangle, Download, Search, RotateCcw } from 'lucide-react';
import { ArchivedMatch, loadMatchHistory, removeArchivedMatch } from '../engine/matchHistory';
import { InterruptedMatch, loadInterruptedMatches, removeInterruptedMatch } from '../engine/matchInterrupted';
import { readPlayerDirectory } from '../engine/playerDirectory';
import { EMPTY_HISTORY_FILTERS, type HistoryFilters, filterFinishedMatches, filterInterruptedMatches, exportHistoryCsv } from '../engine/matchHistoryAdvanced';

interface Props { onBack: () => void; onResumeInterrupted: (id: string) => boolean }
const formatDuration = (n: number) => `${Math.floor(n / 3600).toString().padStart(2, '0')}:${Math.floor(n % 3600 / 60).toString().padStart(2, '0')}:${(n % 60).toString().padStart(2, '0')}`;
const setLabel = (s: ArchivedMatch['sets'][number]): string =>
  s.isMatchTieBreak ? `MTB ${s.tieBreakPointsA ?? 0}–${s.tieBreakPointsB ?? 0}` :
  `${s.gamesA}–${s.gamesB}${s.tieBreakPointsA != null && s.tieBreakPointsB != null ? ` (TB ${s.tieBreakPointsA}–${s.tieBreakPointsB})` : ''}`;

export const MatchHistoryScreen: React.FC<Props> = ({ onBack, onResumeInterrupted }) => {
  const [items, setItems] = useState<ArchivedMatch[]>(() => loadMatchHistory(window.localStorage));
  const [opened, setOpened] = useState<string | null>(null);
  const [openedInterrupted, setOpenedInterrupted] = useState<string | null>(null);
  const [filters, setFilters] = useState<HistoryFilters>({ ...EMPTY_HISTORY_FILTERS });
  const [manualCsv, setManualCsv] = useState<string | null>(null);
  const directory = readPlayerDirectory(window.localStorage) ?? { version: 1 as const, players: [], pairs: [] };
  const visibleFinished = filterFinishedMatches(items, filters, directory);
  const visibleInterrupted = filterInterruptedMatches(interrupted, filters, directory);
  const visibleCount = section === 'finished' ? visibleFinished.length : visibleInterrupted.length;
  const updateFilter = (field: keyof HistoryFilters, value: string) => setFilters(previous => ({ ...previous, [field]: value }));
  const visibleCsv = () => exportHistoryCsv(section === 'finished' ? visibleFinished : [], section === 'interrupted' ? visibleInterrupted : []);
  const copyVisible = async () => {
    const csv = visibleCsv();
    try {
      if (!navigator.clipboard) throw new Error('Clipboard non disponibile');
      await navigator.clipboard.writeText(csv);
      setFeedback({ error: false, text: 'CSV copiato negli appunti.' });
    } catch {
      setManualCsv(csv); // Fallback se l’anteprima embedded limita la clipboard.
    }
  };
  const exportVisible = () => {
    const csv = visibleCsv();
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const anchor = document.createElement('a');
    anchor.href = url; anchor.download = `padel-storico-${section}-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(anchor); anchor.click(); anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  const [section, setSection] = useState<'finished' | 'interrupted'>('finished');
  const [interrupted, setInterrupted] = useState<InterruptedMatch[]>(() => loadInterruptedMatches(window.localStorage));
  const [pendingInterruptedDelete, setPendingInterruptedDelete] = useState<InterruptedMatch | null>(null);
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

  const confirmInterruptedDelete = () => {
    if (!pendingInterruptedDelete) return;
    if (!removeInterruptedMatch(window.localStorage, pendingInterruptedDelete.id)) {
      setFeedback({error: true, text: 'Non è stato possibile eliminare la partita interrotta.'});
    } else {
      setInterrupted(loadInterruptedMatches(window.localStorage));
      setFeedback({error: false, text: 'Partita interrotta eliminata.'});
    }
    setPendingInterruptedDelete(null);
  };

  return (
    <div className="min-h-screen bg-[#070B14] text-white overflow-y-auto p-5 sm:p-8">
      <div className="mx-auto max-w-4xl space-y-5">
        <header className="flex flex-wrap items-center gap-4 border-b border-slate-800 pb-5">
          <button type="button" onClick={onBack} className="flex items-center gap-2 rounded-xl bg-slate-800 px-4 py-3 text-sm font-bold"><ArrowLeft size={17}/> Setup</button>
          <div><h1 className="text-xl font-black tracking-wide text-[#CCFF00]">STORICO PARTITE</h1><p className="text-sm text-slate-400">{items.length} concluse · {interrupted.length} interrotte · Offline</p></div>
        </header>
        <div className="flex flex-wrap gap-3" role="tablist" aria-label="Tipo di partite">
          <button type="button" role="tab" aria-selected={section === 'finished'} onClick={() => setSection('finished')} className={`rounded-xl px-4 py-3 font-bold ${section === 'finished' ? 'bg-[#CCFF00] text-slate-950' : 'bg-slate-800 text-white'}`}>Concluse ({items.length})</button>
          <button type="button" role="tab" aria-selected={section === 'interrupted'} onClick={() => setSection('interrupted')} className={`rounded-xl px-4 py-3 font-bold ${section === 'interrupted' ? 'bg-[#CCFF00] text-slate-950' : 'bg-slate-800 text-white'}`}>Interrotte ({interrupted.length})</button>
        </div>
        <section aria-label="Ricerca e filtri storico" className="rounded-2xl border border-slate-700 bg-slate-900 p-4 space-y-3">
          <label className="flex items-center gap-2 text-sm font-bold text-slate-200" htmlFor="match-history-query"><Search size={17}/> Cerca squadra o giocatore</label>
          <input id="match-history-query" type="search" value={filters.query} maxLength={100}
            onChange={event => updateFilter('query', event.target.value)} placeholder="Nome squadra o giocatore..."
            className="w-full rounded-xl border border-slate-600 bg-slate-950 p-3 text-white placeholder:text-slate-500"/>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="text-xs text-slate-300">Giocatore registrato
              <select value={filters.playerId} onChange={event => updateFilter('playerId', event.target.value)} className="mt-1 w-full rounded-xl border border-slate-600 bg-slate-950 p-3 text-sm text-white">
                <option value="">Tutti i giocatori</option>
                {directory.players.map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
              </select>
            </label>
            <label className="text-xs text-slate-300">Coppia registrata
              <select value={filters.pairId} onChange={event => updateFilter('pairId', event.target.value)} className="mt-1 w-full rounded-xl border border-slate-600 bg-slate-950 p-3 text-sm text-white">
                <option value="">Tutte le coppie</option>
                {directory.pairs.map(pair => <option key={pair.id} value={pair.id}>{pair.name}</option>)}
              </select>
            </label>
            <label className="text-xs text-slate-300">Dal giorno
              <input type="date" value={filters.fromDate} max="9999-12-31" onChange={event => updateFilter('fromDate', event.target.value)} className="mt-1 w-full rounded-xl border border-slate-600 bg-slate-950 p-3 text-sm text-white"/>
            </label>
            <label className="text-xs text-slate-300">Al giorno (incluso)
              <input type="date" value={filters.toDate} max="9999-12-31" onChange={event => updateFilter('toDate', event.target.value)} className="mt-1 w-full rounded-xl border border-slate-600 bg-slate-950 p-3 text-sm text-white"/>
            </label>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span role="status" className="text-sm text-slate-300">{visibleCount} partite trovate</span>
            <div className="flex flex-wrap gap-2">
              <button type="button" onClick={() => setFilters({ ...EMPTY_HISTORY_FILTERS })} className="flex items-center gap-1 rounded-xl border border-slate-600 px-3 py-2 text-sm font-bold"><RotateCcw size={15}/> Azzera filtri</button>
              <button type="button" disabled={visibleCount === 0} onClick={copyVisible} className="rounded-xl border border-cyan-600 px-3 py-2 text-sm font-bold disabled:opacity-40">Copia CSV</button>
              <button type="button" disabled={visibleCount === 0} onClick={exportVisible} className="flex items-center gap-1 rounded-xl bg-cyan-700 px-3 py-2 text-sm font-bold disabled:opacity-40"><Download size={15}/> Esporta CSV</button>
            </div>
          </div>
        </section>
        {manualCsv !== null && <div className="rounded-xl border border-cyan-700 bg-slate-900 p-3 space-y-2">
          <p className="text-sm text-slate-200">Il browser ha bloccato la copia automatica. Seleziona il testo e copialo manualmente.</p>
          <textarea value={manualCsv} readOnly onFocus={event => event.currentTarget.select()} rows={4}
            aria-label="CSV da copiare" className="w-full rounded-lg bg-slate-950 p-2 text-xs text-white"/>
          <button type="button" onClick={() => setManualCsv(null)} className="rounded-lg bg-slate-700 px-3 py-2 text-sm">Chiudi</button>
        </div>}
        {feedback && (
          <div role="status" aria-live="polite" className={`rounded-xl border p-3 text-sm ${feedback.error ? 'border-rose-700 bg-rose-950/60 text-rose-200' : 'border-emerald-700 bg-emerald-950/50 text-emerald-200'}`}>
            {feedback.text}
          </div>
        )}
        {section === 'finished' && !items.length && <div className="rounded-2xl border border-slate-700 bg-slate-900 p-8 text-center text-slate-300">Nessuna partita conclusa salvata. Termina un match e scegli di archiviarlo dal riepilogo.</div>}
        {section === 'finished' && items.length > 0 && visibleFinished.length === 0 && <p className="rounded-xl bg-slate-900 p-6 text-center text-slate-300">Nessuna partita corrisponde ai filtri.</p>}
        {section === 'finished' && visibleFinished.map(item => (
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
        {section === 'interrupted' && !interrupted.length && <div className="rounded-xl border border-slate-700 bg-slate-900 p-7 text-center text-slate-300">Nessuna partita interrotta archiviata. Puoi interrompere una partita dal riepilogo senza assegnare un vincitore.</div>}
        {section === 'interrupted' && interrupted.length > 0 && visibleInterrupted.length === 0 && <p className="rounded-xl bg-slate-900 p-6 text-center text-slate-300">Nessuna partita interrotta corrisponde ai filtri.</p>}
        {section === 'interrupted' && visibleInterrupted.map(item => {
          const { settings, state, runtime } = item.checkpoint;
          const snap = state.snapshot;
          return <article key={item.id} className="rounded-2xl border border-slate-700 bg-slate-900 p-5 space-y-3">
            <div className="flex justify-between items-center gap-3"><strong className="text-amber-300">Partita interrotta</strong><button type="button" aria-label={`Elimina partita interrotta ${settings.teamAName} contro ${settings.teamBName}`} onClick={() => { setFeedback(null); setPendingInterruptedDelete(item); }} className="rounded-lg border border-rose-700/50 p-2 text-rose-300"><Trash2 size={17}/></button></div>
            <p className="font-bold text-white text-center">{settings.teamAName} <span className="text-slate-500">VS</span> {settings.teamBName}</p>
            <div className="text-center text-sm text-slate-300">Set conclusi: {snap.completedSets.map(s => `${s.gamesA}–${s.gamesB}`).join(', ') || 'nessuno'} · Set in corso: {snap.currentGamesA}–{snap.currentGamesB}{snap.isTieBreak ? ` · TB ${snap.tieBreakPointsA}–${snap.tieBreakPointsB}` : ''}</div>
            <p className="text-center text-xs text-slate-400">Salvata: {new Date(item.interruptedAt).toLocaleString('it-IT')} · Durata: {formatDuration(runtime.matchSeconds)}</p>
            <button type="button" onClick={() => setOpenedInterrupted(previous => previous === item.id ? null : item.id)} className="text-sm font-bold text-cyan-300 underline underline-offset-4">{openedInterrupted === item.id ? 'Nascondi dettagli' : 'Dettagli della partita'}</button>
            {openedInterrupted === item.id && <div className="grid gap-2 border-t border-slate-700 pt-3 text-sm text-slate-300 sm:grid-cols-2">
              <p>Giocatori A: {settings.player1Name} · {settings.player2Name}</p>
              <p>Giocatori B: {settings.player3Name} · {settings.player4Name}</p>
              <p>Formato: al meglio di {settings.bestOfSets} set · {settings.gamesPerSet ?? 6} game</p>
              <p>Battitore: giocatore {snap.servingRotationIndex % 4 + 1} · {snap.servingTeam === 'teamA' ? settings.teamAName : settings.teamBName}</p>
              <p className="sm:col-span-2">Ultimo evento: {snap.lastEventMessage || 'Non disponibile'}</p>
            </div>}
            <button type="button" onClick={() => {
              if (!onResumeInterrupted(item.id)) setFeedback({error:true,text:'Impossibile riprendere la partita. I dati salvati restano disponibili.'});
            }} className="w-full rounded-xl bg-[#CCFF00] py-3 font-black text-slate-950">Riprendi partita</button>
          </article>;
        })}
      </div>

      {pendingInterruptedDelete && <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/85 p-4"><div role="alertdialog" aria-modal="true" className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-900 p-6 space-y-5"><h2 className="text-lg font-black">Eliminare la partita interrotta?</h2><p className="text-sm text-slate-300">Non sarà più possibile riprendere {pendingInterruptedDelete.checkpoint.settings.teamAName} contro {pendingInterruptedDelete.checkpoint.settings.teamBName}.</p><div className="flex justify-end gap-3"><button type="button" onClick={() => setPendingInterruptedDelete(null)} className="rounded-lg bg-slate-700 px-4 py-3">Annulla</button><button type="button" onClick={confirmInterruptedDelete} className="rounded-lg bg-rose-600 px-4 py-3 font-bold">Elimina definitivamente</button></div></div></div>}

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
