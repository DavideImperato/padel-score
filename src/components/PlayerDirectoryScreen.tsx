import React, { useState } from 'react';
import { ArrowLeft, Trash2, UserRoundPlus, Users } from 'lucide-react';
import { addPair, addPlayer, readPlayerDirectory, removePair, removePlayer, renamePlayer, PlayerDirectory } from '../engine/playerDirectory';

const dark = 'rounded-xl bg-slate-950 border border-slate-700 px-3 py-2 text-white text-sm';

export const PlayerDirectoryScreen: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  const [directory, setDirectory] = useState<PlayerDirectory | null>(() => readPlayerDirectory(window.localStorage));
  const [name, setName] = useState('');
  const [pairName, setPairName] = useState('');
  const [first, setFirst] = useState('');
  const [second, setSecond] = useState('');
  const [error, setError] = useState('');
  const [confirm, setConfirm] = useState<{ kind: 'player' | 'pair'; id: string; name: string } | null>(null);
  const [rename, setRename] = useState<{ id: string; name: string } | null>(null);
  const transact = (action: () => ReturnType<typeof addPlayer>) => {
    const result = action();
    if (!result.ok) { setError(result.reason); return false; }
    setDirectory(result.directory);
    setError('');
    return true;
  };
  const addNewPlayer = () => { if (transact(() => addPlayer(window.localStorage, name))) setName(''); };
  const addNewPair = () => { if (transact(() => addPair(window.localStorage, pairName, first, second))) { setPairName(''); setFirst(''); setSecond(''); } };
  const saveRename = () => {
    if (rename && transact(() => renamePlayer(window.localStorage, rename.id, rename.name))) setRename(null);
  };
  const confirmDelete = () => {
    if (!confirm) return;
    if (transact(() => confirm.kind === 'player'
      ? removePlayer(window.localStorage, confirm.id)
      : removePair(window.localStorage, confirm.id))) setConfirm(null);
  };

  return <main className="min-h-screen bg-[#070B14] text-white p-5 sm:p-8 overflow-y-auto">
    <div className="mx-auto max-w-4xl space-y-6">
      <button onClick={onBack} className="flex items-center gap-2 text-slate-300 hover:text-white"><ArrowLeft size={17}/> Torna al setup</button>
      <div><h1 className="text-2xl font-black text-[#CCFF00]">Giocatori e coppie</h1><p className="text-sm text-slate-400 mt-2">Archivio offline del dispositivo. I nomi delle partite già salvate non vengono modificati.</p></div>
      {!directory && <section role="alert" className="p-4 rounded-xl border border-red-500 text-red-200">Archivio non leggibile. Non verrà sovrascritto. Controlla i dati locali prima di aggiungere giocatori.</section>}
      {error && <div role="alert" className="p-3 bg-red-950 border border-red-700 rounded-xl text-sm text-red-200">{error}</div>}
      {directory && <>
        <section className="bg-slate-900 rounded-2xl p-5 border border-slate-800 space-y-4">
          <h2 className="font-bold text-lg flex items-center gap-2"><UserRoundPlus size={20}/> Giocatori ({directory.players.length})</h2>
          <form onSubmit={e => { e.preventDefault(); addNewPlayer(); }} className="flex flex-wrap gap-2">
            <input aria-label="Nome nuovo giocatore" maxLength={60} value={name} onChange={e => setName(e.target.value)} placeholder="Nome e cognome" className={`${dark} flex-1 min-w-44`} />
            <button className="bg-[#CCFF00] text-black rounded-xl px-4 py-2 font-bold text-sm" type="submit">Aggiungi giocatore</button>
          </form>
          {directory.players.length === 0 && <p className="text-sm text-slate-400">Nessun giocatore salvato.</p>}
          <div className="grid md:grid-cols-2 gap-2">{directory.players.map(p => <div key={p.id} className="flex items-center justify-between bg-slate-950 p-3 rounded-xl gap-3">
            <span className="text-sm truncate">{p.name}</span>
            <div className="flex gap-2 shrink-0"><button className="text-xs text-cyan-300" onClick={() => setRename({ id: p.id, name: p.name })}>Rinomina</button><button aria-label={`Elimina ${p.name}`} className="text-rose-400" onClick={() => setConfirm({ kind: 'player', id: p.id, name: p.name })}><Trash2 size={16}/></button></div>
          </div>)}</div>
        </section>
        <section className="bg-slate-900 rounded-2xl p-5 border border-slate-800 space-y-4">
          <h2 className="font-bold text-lg flex items-center gap-2"><Users size={20}/> Coppie ({directory.pairs.length})</h2>
          <form onSubmit={e => { e.preventDefault(); addNewPair(); }} className="grid sm:grid-cols-4 gap-2">
            <input aria-label="Nome coppia" maxLength={60} value={pairName} onChange={e => setPairName(e.target.value)} placeholder="Nome coppia" className={dark}/>
            <select aria-label="Primo giocatore" value={first} onChange={e => setFirst(e.target.value)} className={dark}><option value="">Primo giocatore</option>{directory.players.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}</select>
            <select aria-label="Secondo giocatore" value={second} onChange={e => setSecond(e.target.value)} className={dark}><option value="">Secondo giocatore</option>{directory.players.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}</select>
            <button type="submit" className="bg-[#CCFF00] text-black rounded-xl px-3 py-2 font-bold text-sm">Salva coppia</button>
          </form>
          {directory.pairs.length === 0 && <p className="text-sm text-slate-400">Nessuna coppia salvata.</p>}
          {directory.pairs.map(p => <div key={p.id} className="flex items-center justify-between bg-slate-950 rounded-xl p-3 gap-4">
            <div><div className="font-bold text-sm">{p.name}</div><div className="text-slate-400 text-xs">{p.playerIds.map(id => directory.players.find(player => player.id === id)?.name ?? '—').join(' + ')}</div></div>
            <button aria-label={`Elimina coppia ${p.name}`} className="text-rose-400" onClick={() => setConfirm({ kind: 'pair', id: p.id, name: p.name })}><Trash2 size={16}/></button>
          </div>)}
        </section>
      </>}
    </div>
    {rename && <div role="dialog" aria-modal="true" aria-label="Rinomina giocatore" className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-900 border border-slate-700 p-6 rounded-2xl max-w-md w-full space-y-4">
        <h2 className="font-bold text-xl">Rinomina giocatore</h2>
        <form onSubmit={e => { e.preventDefault(); saveRename(); }} className="space-y-4">
          <input aria-label="Nuovo nome" maxLength={60} autoFocus className={`${dark} w-full`} value={rename.name} onChange={e => setRename({ ...rename, name: e.target.value })} />
          <div className="flex justify-end gap-2"><button type="button" onClick={() => setRename(null)} className="px-4 py-2 rounded-lg bg-slate-700">Annulla</button><button type="submit" className="px-4 py-2 rounded-lg bg-[#CCFF00] text-black font-bold">Salva</button></div>
        </form>
        {error && <p role="alert" className="text-rose-400 text-sm">{error}</p>}
      </div>
    </div>}
    {confirm && <div role="dialog" aria-modal="true" aria-label="Conferma eliminazione" className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
      <div className="bg-slate-900 border border-slate-700 p-6 rounded-2xl max-w-md w-full space-y-4"><h2 className="font-bold text-xl">Eliminare {confirm.name}?</h2><p className="text-slate-300 text-sm">Questa operazione non cancella i risultati delle partite già archiviate.</p>
        <div className="flex justify-end gap-3"><button onClick={() => setConfirm(null)} className="px-4 py-2 rounded-lg bg-slate-700">Annulla</button><button onClick={confirmDelete} className="px-4 py-2 rounded-lg bg-rose-600 font-bold">Elimina</button></div>
      </div>
    </div>}
  </main>;
};
