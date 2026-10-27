import React, { useState } from 'react';
import { MatchSettings } from '../types/padel';
import { Play, Trophy, Sparkles, RefreshCw, Radio, ArrowRight } from 'lucide-react';

interface MatchSetupScreenProps {
  currentSettings: MatchSettings;
  onStartMatch: (updated: MatchSettings) => void;
  onGoToScoreboard?: () => void;
  isMatchInProgress: boolean;
  onOpenRemoteHelper: () => void;
  onOpenHistory: () => void;
}

export const MatchSetupScreen: React.FC<MatchSetupScreenProps> = ({
  currentSettings,
  onStartMatch,
  onGoToScoreboard,
  isMatchInProgress,
  onOpenRemoteHelper,
  onOpenHistory,
}) => {
  const [team1, setTeam1] = useState(currentSettings.teamAName);
  const [team2, setTeam2] = useState(currentSettings.teamBName);

  const [p1, setP1] = useState(currentSettings.player1Name);
  const [p2, setP2] = useState(currentSettings.player2Name);
  const [p3, setP3] = useState(currentSettings.player3Name);
  const [p4, setP4] = useState(currentSettings.player4Name);

  const [firstServerId, setFirstServerId] = useState(currentSettings.firstServerPlayerId || 1);
  const [isGoldenPoint, setIsGoldenPoint] = useState(currentSettings.isGoldenPoint);
  const [advantagesBeforeGoldenPoint, setAdvantagesBeforeGoldenPoint] = useState(
    currentSettings.advantagesBeforeGoldenPoint ?? 0
  );
  const [bestOfSets, setBestOfSets] = useState(currentSettings.bestOfSets);
  const [gamesPerSet, setGamesPerSet] = useState<4 | 6>(currentSettings.gamesPerSet === 4 ? 4 : 6);
  const [decidingMatchTieBreak, setDecidingMatchTieBreak] = useState(currentSettings.decidingMatchTieBreak === true);
  const [decidingTieBreakPoints, setDecidingTieBreakPoints] = useState<7 | 10>(currentSettings.decidingTieBreakPoints === 7 ? 7 : 10);

  const player1Display = p1.trim() || 'Giocatore 1';
  const player2Display = p2.trim() || 'Giocatore 2';
  const player3Display = p3.trim() || 'Giocatore 3';
  const player4Display = p4.trim() || 'Giocatore 4';

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onStartMatch({
      teamAName: team1.trim() || 'Gli Smashtori',
      teamBName: team2.trim() || 'I Timemasters',
      player1Name: player1Display,
      player2Name: player2Display,
      player3Name: player3Display,
      player4Name: player4Display,
      firstServerPlayerId: firstServerId,
      isGoldenPoint,
      advantagesBeforeGoldenPoint,
      bestOfSets,
      gamesPerSet,
      decidingMatchTieBreak: bestOfSets > 1 && decidingMatchTieBreak,
      decidingTieBreakPoints,
      ttsSpeed: currentSettings.ttsSpeed,
      ttsVolume: currentSettings.ttsVolume,
      isMuted: currentSettings.isMuted,
      isVoiceMuted: currentSettings.isVoiceMuted ?? false,
      isSfxMuted: currentSettings.isSfxMuted ?? false,
    });
  };

  const getRotationPreview = () => {
    if (firstServerId === 1) {
      return `Turno 1: ${player1Display} ➔ Turno 2: ${player3Display} ➔ Turno 3: ${player2Display} ➔ Turno 4: ${player4Display} (poi ciclico)`;
    } else if (firstServerId === 2) {
      return `Turno 1: ${player2Display} ➔ Turno 2: ${player3Display} ➔ Turno 3: ${player1Display} ➔ Turno 4: ${player4Display} (poi ciclico)`;
    } else if (firstServerId === 3) {
      return `Turno 1: ${player3Display} ➔ Turno 2: ${player1Display} ➔ Turno 3: ${player4Display} ➔ Turno 4: ${player2Display} (poi ciclico)`;
    } else {
      return `Turno 1: ${player4Display} ➔ Turno 2: ${player1Display} ➔ Turno 3: ${player3Display} ➔ Turno 4: ${player2Display} (poi ciclico)`;
    }
  };

  return (
    <div className="min-h-screen w-full bg-[#070B14] text-white flex flex-col font-sans select-none overflow-y-auto">
      {/* Top Navigation */}
      <header className="px-6 py-4 bg-slate-950 border-b border-slate-800 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-[#CCFF00] text-slate-950 shadow-md shadow-[#CCFF00]/30">
            <Trophy className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-base sm:text-lg font-black tracking-wider uppercase text-white">
              PADEL SCOREBOT
            </h1>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* If match is in progress, allow jumping back to scoreboard */}
          {isMatchInProgress && onGoToScoreboard && (
            <button
              onClick={onGoToScoreboard}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs border border-slate-700 transition-colors cursor-pointer"
            >
              <span>Torna al Tabellone</span>
              <ArrowRight className="w-3.5 h-3.5 text-[#CCFF00]" />
            </button>
          )}

          <button type="button" onClick={onOpenHistory}
            className="rounded-lg bg-slate-900 border border-slate-700 px-3 py-2 text-xs font-bold text-[#CCFF00] hover:bg-slate-800">
            Storico partite
          </button>
          <button
            onClick={onOpenRemoteHelper}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:border-emerald-500/60 text-xs text-slate-300 font-bold transition-colors cursor-pointer"
          >
            <Radio className="w-3.5 h-3.5 text-emerald-400" />
            <span className="hidden sm:inline">Telecomando BT</span>
          </button>
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 flex items-center justify-center p-4 sm:p-6 lg:p-8">
        <div className="w-full max-w-4xl bg-slate-900/90 border border-slate-800 rounded-3xl p-6 sm:p-8 shadow-2xl backdrop-blur-sm">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* 1. SQUADRE E 4 GIOCATORI */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              {/* SQUADRA 1 */}
              <div className="p-5 rounded-2xl bg-slate-950/80 border border-[#CCFF00]/40 space-y-4 shadow-lg shadow-[#CCFF00]/5">
                <div className="flex items-center gap-2">
                  <span className="w-3 h-3 rounded-full bg-[#CCFF00]" />
                  <h3 className="text-sm font-black tracking-wider uppercase text-[#CCFF00]">
                    Squadra 1 (Sinistra)
                  </h3>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-400 mb-1">
                    Nome Squadra
                  </label>
                  <input
                    type="text"
                    value={team1}
                    onChange={(e) => setTeam1(e.target.value)}
                    placeholder="Es. Gli Smashtori"
                    required
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-[#CCFF00]"
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                  <div>
                    <label className="block text-xs font-bold text-slate-400 mb-1">
                      Giocatore 1
                    </label>
                    <input
                      type="text"
                      value={p1}
                      onChange={(e) => setP1(e.target.value)}
                      placeholder="Mario Rossi"
                      required
                      className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-white font-bold text-xs focus:outline-none focus:border-[#CCFF00]"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-400 mb-1">
                      Giocatore 2
                    </label>
                    <input
                      type="text"
                      value={p2}
                      onChange={(e) => setP2(e.target.value)}
                      placeholder="Luigi Verdi"
                      required
                      className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-white font-bold text-xs focus:outline-none focus:border-[#CCFF00]"
                    />
                  </div>
                </div>
              </div>

              {/* SQUADRA 2 */}
              <div className="p-5 rounded-2xl bg-slate-950/80 border border-cyan-400/40 space-y-4 shadow-lg shadow-cyan-400/5">
                <div className="flex items-center gap-2">
                  <span className="w-3 h-3 rounded-full bg-cyan-400" />
                  <h3 className="text-sm font-black tracking-wider uppercase text-cyan-400">
                    Squadra 2 (Destra)
                  </h3>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-400 mb-1">
                    Nome Squadra
                  </label>
                  <input
                    type="text"
                    value={team2}
                    onChange={(e) => setTeam2(e.target.value)}
                    placeholder="Es. I Timemasters"
                    required
                    className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-cyan-400"
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                  <div>
                    <label className="block text-xs font-bold text-slate-400 mb-1">
                      Giocatore 3
                    </label>
                    <input
                      type="text"
                      value={p3}
                      onChange={(e) => setP3(e.target.value)}
                      placeholder="Paolo Bianchi"
                      required
                      className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-white font-bold text-xs focus:outline-none focus:border-cyan-400"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-400 mb-1">
                      Giocatore 4
                    </label>
                    <input
                      type="text"
                      value={p4}
                      onChange={(e) => setP4(e.target.value)}
                      placeholder="Marco Neri"
                      required
                      className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-white font-bold text-xs focus:outline-none focus:border-cyan-400"
                    />
                  </div>
                </div>
              </div>
            </div>

            {/* 2. CHI SERVE PER PRIMO & ROTAZIONE A 4 */}
            <div className="p-5 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                <div>
                  <h3 className="text-sm font-black tracking-wider uppercase text-white">
                    Chi serve per primo nel match?
                  </h3>
                  <p className="text-xs text-slate-400">
                    L'ordine di battuta seguirà automaticamente l'alternanza ufficiale delle coppie.
                  </p>
                </div>
              </div>

              {/* Grid di selezione del primo battitore */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                {[
                  { id: 1, name: player1Display, team: team1 || 'Squadra 1', color: 'lime' },
                  { id: 2, name: player2Display, team: team1 || 'Squadra 1', color: 'lime' },
                  { id: 3, name: player3Display, team: team2 || 'Squadra 2', color: 'cyan' },
                  { id: 4, name: player4Display, team: team2 || 'Squadra 2', color: 'cyan' },
                ].map((item) => {
                  const isSelected = firstServerId === item.id;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => setFirstServerId(item.id)}
                      className={`p-3 rounded-xl border text-left transition-all cursor-pointer ${
                        isSelected
                          ? item.color === 'lime'
                            ? 'bg-[#CCFF00]/15 border-[#CCFF00] shadow-md shadow-[#CCFF00]/20'
                            : 'bg-cyan-500/15 border-cyan-400 shadow-md shadow-cyan-500/20'
                          : 'bg-slate-900/60 border-slate-800 hover:border-slate-700'
                      }`}
                    >
                      <div className="flex items-center justify-between text-[11px] font-bold text-slate-400">
                        <span>{item.team}</span>
                        {isSelected && <span className="text-emerald-400 font-bold">● Inizia</span>}
                      </div>
                      <div className="text-sm font-black text-white truncate mt-1">
                        {item.name}
                      </div>
                    </button>
                  );
                })}
              </div>

              {/* Anteprima Sequenza */}
              <div className="flex items-center gap-2 p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs text-emerald-300 font-semibold mt-2">
                <RefreshCw className="w-4 h-4 text-emerald-400 shrink-0" />
                <span>{getRotationPreview()}</span>
              </div>
            </div>

            {/* 3. REGOLE PADEL */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex flex-col gap-2 p-4 rounded-xl bg-slate-950 border border-slate-800">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="flex items-center gap-2 text-xs font-black uppercase tracking-wider text-white">
                      <Sparkles className="w-4 h-4 text-amber-400" />
                      <span>Punto d'Oro sul 40-40</span>
                    </div>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      Attiva regola Punto d'Oro sul 40 pari.
                    </p>
                  </div>
                  <input
                    type="checkbox"
                    checked={isGoldenPoint}
                    onChange={(e) => setIsGoldenPoint(e.target.checked)}
                    className="w-5 h-5 accent-[#CCFF00] cursor-pointer"
                  />
                </div>

                {isGoldenPoint && (
                  <div className="pt-2 border-t border-slate-800/80">
                    <div className="flex items-center justify-between text-[11px] font-bold text-slate-300 mb-1.5">
                      <span>Vantaggi prima del punto d'oro:</span>
                      <span className="text-amber-400 font-mono">
                        {advantagesBeforeGoldenPoint === 0
                          ? '0 (Subito Punto d\'oro)'
                          : advantagesBeforeGoldenPoint === 1
                          ? '1 Vantaggio poi Punto d\'oro'
                          : '2 Vantaggi poi Punto d\'oro'}
                      </span>
                    </div>
                    <div className="grid grid-cols-3 gap-1.5">
                      {[
                        { num: 0, title: '0 Vantaggi', desc: 'Subito Punto d\'oro' },
                        { num: 1, title: '1 Vantaggio', desc: 'Poi Punto d\'oro' },
                        { num: 2, title: '2 Vantaggi', desc: 'Poi Punto d\'oro' },
                      ].map((item) => (
                        <button
                          key={item.num}
                          type="button"
                          onClick={() => setAdvantagesBeforeGoldenPoint(item.num)}
                          className={`py-1.5 px-2 rounded-lg text-xs font-bold flex flex-col items-center transition-all cursor-pointer ${
                            advantagesBeforeGoldenPoint === item.num
                              ? 'bg-amber-500 text-slate-950 font-black shadow'
                              : 'bg-slate-900 text-slate-400 hover:text-white border border-slate-800'
                          }`}
                        >
                          <span className="font-mono text-sm">{item.num}</span>
                          <span className="text-[10px] leading-tight">{item.title}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              <div className="flex items-center justify-between p-4 rounded-xl bg-slate-950 border border-slate-800">
                <span className="text-xs font-black uppercase tracking-wider text-white">
                  Formato Partita
                </span>
                <div className="flex items-center gap-2">
                  {[1, 3, 5].map((count) => (
                    <button
                      key={count}
                      type="button"
                      onClick={() => setBestOfSets(count)}
                      className={`px-3 py-1 rounded-lg text-xs font-black transition-colors cursor-pointer ${
                        bestOfSets === count
                          ? 'bg-[#CCFF00] text-slate-950'
                          : 'bg-slate-900 text-slate-400 hover:text-white'
                      }`}
                    >
                      {count} {count === 1 ? 'Set' : 'Set'}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs font-black uppercase text-white">Durata del set</div>
                <p className="text-[11px] text-slate-400">Set breve: 4 game con 2 di vantaggio, tie-break sul 4-4.</p>
              </div>
              <div className="flex gap-2">
                {([6, 4] as const).map(target => (
                  <button key={target} type="button" onClick={() => setGamesPerSet(target)}
                    aria-pressed={gamesPerSet === target}
                    className={`px-3 py-2 rounded-lg text-xs font-black ${gamesPerSet === target ? 'bg-[#CCFF00] text-slate-950' : 'bg-slate-800 text-white'}`}>
                    {target === 6 ? 'Standard (6)' : 'Breve (4)'}
                  </button>
                ))}
              </div>
            </div>

          <label className="flex items-center justify-between gap-3 p-3 rounded-xl bg-slate-950 border border-slate-700 text-sm text-white">
            <span>
              <strong className="block">Tie-break decisivo (7 o 10 punti)</strong>
              <small className="text-slate-400">Sostituisce l'ultimo set quando le coppie sono in parità (1-1 oppure 2-2).</small>
            </span>
            <input type="checkbox" checked={bestOfSets > 1 && decidingMatchTieBreak}
              disabled={bestOfSets === 1} onChange={e => setDecidingMatchTieBreak(e.target.checked)}
              className="h-5 w-5 accent-lime-400" aria-label="Match tie-break decisivo" />
          </label>
          {bestOfSets > 1 && decidingMatchTieBreak && (
            <div className="flex items-center gap-2 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl" role="group" aria-label="Punti del tie-break decisivo">
              <span className="text-xs text-slate-300 mr-auto">Punteggio decisivo</span>
              {([7, 10] as const).map(points => (
                <button type="button" key={points} aria-pressed={decidingTieBreakPoints === points}
                  onClick={() => setDecidingTieBreakPoints(points)}
                  className={`px-3 py-2 rounded-lg text-xs font-bold ${decidingTieBreakPoints === points ? 'bg-[#CCFF00] text-slate-950' : 'bg-slate-800 text-white'}`}>
                  {points} punti
                </button>
              ))}
            </div>
          )}

            {/* GROSSO PULSANTE CENTRALE "INIZIA PARTITA" */}
            <div className="pt-2">
              <button
                type="submit"
                className="w-full py-4 rounded-2xl bg-[#CCFF00] hover:bg-[#b8e600] text-slate-950 font-black text-lg tracking-widest uppercase shadow-xl shadow-[#CCFF00]/30 transition-all flex items-center justify-center gap-3 cursor-pointer active:scale-[0.99]"
              >
                <Play className="w-6 h-6 fill-current" />
                <span>Inizia Partita</span>
              </button>
            </div>
          </form>
        </div>
      </main>
    </div>
  );
};
