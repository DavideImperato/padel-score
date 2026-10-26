import React, { useState } from 'react';
import { MatchSettings } from '../types/padel';
import { Play, Users, Trophy, Sparkles, RefreshCw } from 'lucide-react';

interface MatchSetupModalProps {
  isOpen: boolean;
  currentSettings: MatchSettings;
  onStartMatch: (updated: MatchSettings) => void;
  onClose?: () => void;
  isInitial?: boolean;
}

export const MatchSetupModal: React.FC<MatchSetupModalProps> = ({
  isOpen,
  currentSettings,
  onStartMatch,
  onClose,
  isInitial = false,
}) => {
  const [team1, setTeam1] = useState(currentSettings.teamAName);
  const [team2, setTeam2] = useState(currentSettings.teamBName);

  const [p1, setP1] = useState(currentSettings.player1Name);
  const [p2, setP2] = useState(currentSettings.player2Name);
  const [p3, setP3] = useState(currentSettings.player3Name);
  const [p4, setP4] = useState(currentSettings.player4Name);

  const [firstServerId, setFirstServerId] = useState(currentSettings.firstServerPlayerId || 1);
  const [isGoldenPoint, setIsGoldenPoint] = useState(currentSettings.isGoldenPoint);
  const [bestOfSets, setBestOfSets] = useState(currentSettings.bestOfSets);
  const [gamesPerSet, setGamesPerSet] = useState<4 | 6>(currentSettings.gamesPerSet === 4 ? 4 : 6);
  const [decidingMatchTieBreak, setDecidingMatchTieBreak] = useState(currentSettings.decidingMatchTieBreak === true);
  const [decidingTieBreakPoints, setDecidingTieBreakPoints] = useState<7 | 10>(currentSettings.decidingTieBreakPoints === 7 ? 7 : 10);

  if (!isOpen) return null;

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
      advantagesBeforeGoldenPoint: currentSettings.advantagesBeforeGoldenPoint ?? 0,
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
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/90 backdrop-blur-md overflow-y-auto">
      <div className="w-full max-w-4xl bg-slate-900 border border-slate-700/80 rounded-2xl sm:rounded-3xl shadow-2xl overflow-hidden my-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 bg-slate-950 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-[#CCFF00] text-slate-950 shadow-md shadow-[#CCFF00]/30">
              <Trophy className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base sm:text-lg font-black tracking-wider uppercase text-white">
                Setup Partita Padel
              </h2>
              <p className="text-xs text-slate-400">
                Inserisci squadre, coppie e stabilisci chi batte per primo.
              </p>
            </div>
          </div>

          {!isInitial && onClose && (
            <button
              onClick={onClose}
              className="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-400 hover:text-white bg-slate-800 hover:bg-slate-700 transition-colors cursor-pointer"
            >
              Chiudi
            </button>
          )}
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-6 sm:p-8 space-y-6">
          {/* TEAMS AND 4 PLAYERS */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {/* Squadra 1 */}
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
                  <label className="block text-[11px] font-bold text-slate-400 mb-1">
                    Giocatore 1
                  </label>
                  <input
                    type="text"
                    value={p1}
                    onChange={(e) => setP1(e.target.value)}
                    placeholder="Mario Rossi"
                    required
                    className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs font-semibold focus:outline-none focus:border-[#CCFF00]"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-slate-400 mb-1">
                    Giocatore 2 (Compagno)
                  </label>
                  <input
                    type="text"
                    value={p2}
                    onChange={(e) => setP2(e.target.value)}
                    placeholder="Luigi Verdi"
                    required
                    className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs font-semibold focus:outline-none focus:border-[#CCFF00]"
                  />
                </div>
              </div>
            </div>

            {/* Squadra 2 */}
            <div className="p-5 rounded-2xl bg-slate-950/80 border border-[#00E5FF]/40 space-y-4 shadow-lg shadow-[#00E5FF]/5">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-[#00E5FF]" />
                <h3 className="text-sm font-black tracking-wider uppercase text-[#00E5FF]">
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
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-white font-bold text-sm focus:outline-none focus:border-[#00E5FF]"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                <div>
                  <label className="block text-[11px] font-bold text-slate-400 mb-1">
                    Giocatore 3
                  </label>
                  <input
                    type="text"
                    value={p3}
                    onChange={(e) => setP3(e.target.value)}
                    placeholder="Paolo Bianchi"
                    required
                    className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs font-semibold focus:outline-none focus:border-[#00E5FF]"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-slate-400 mb-1">
                    Giocatore 4 (Compagno)
                  </label>
                  <input
                    type="text"
                    value={p4}
                    onChange={(e) => setP4(e.target.value)}
                    placeholder="Marco Neri"
                    required
                    className="w-full px-3 py-2 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs font-semibold focus:outline-none focus:border-[#00E5FF]"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* SERVING ROTATION SELECTOR */}
          <div className="p-5 rounded-2xl bg-slate-950/90 border border-slate-800 space-y-3">
            <div className="flex items-center gap-2 text-sm font-black uppercase tracking-wider text-white">
              <Users className="w-4 h-4 text-[#CCFF00]" />
              <span>Chi batte per primo? (Rotazione Ufficiale a 4)</span>
            </div>
            <p className="text-xs text-slate-400">
              L'app alternerà rigorosamente i turni di battuta tra i 4 giocatori ad ogni cambio game.
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5 pt-1">
              {[
                { id: 1, name: player1Display, team: team1 || 'Sq.1', accent: 'border-[#CCFF00] text-[#CCFF00]' },
                { id: 2, name: player2Display, team: team1 || 'Sq.1', accent: 'border-[#CCFF00] text-[#CCFF00]' },
                { id: 3, name: player3Display, team: team2 || 'Sq.2', accent: 'border-[#00E5FF] text-[#00E5FF]' },
                { id: 4, name: player4Display, team: team2 || 'Sq.2', accent: 'border-[#00E5FF] text-[#00E5FF]' },
              ].map((item) => {
                const isSelected = firstServerId === item.id;
                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => setFirstServerId(item.id)}
                    className={`p-3 rounded-xl border text-left transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-slate-800 border-2 border-white shadow-lg shadow-white/10'
                        : 'bg-slate-900/60 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-center justify-between text-[11px] font-bold text-slate-400">
                      <span>{item.team}</span>
                      {isSelected && <span className="text-emerald-400 text-xs">● Inizia</span>}
                    </div>
                    <div className="text-sm font-black text-white truncate mt-1">
                      {item.name}
                    </div>
                  </button>
                );
              })}
            </div>

            {/* Sequence preview badge */}
            <div className="flex items-center gap-2 p-3 rounded-xl bg-slate-900 border border-slate-800 text-xs text-emerald-300 font-semibold mt-2">
              <RefreshCw className="w-4 h-4 text-emerald-400 shrink-0" />
              <span>{getRotationPreview()}</span>
            </div>
          </div>

          {/* RULES TOGGLES */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Golden point */}
            <div className="flex items-center justify-between p-4 rounded-xl bg-slate-950 border border-slate-800">
              <div>
                <div className="flex items-center gap-2 text-xs font-black uppercase tracking-wider text-white">
                  <Sparkles className="w-4 h-4 text-amber-400" />
                  <span>Punto d'Oro sul 40-40</span>
                </div>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Chi vince il punto sul 40-40 vince subito il game.
                </p>
              </div>
              <input
                type="checkbox"
                checked={isGoldenPoint}
                onChange={(e) => setIsGoldenPoint(e.target.checked)}
                className="w-5 h-5 accent-[#CCFF00] cursor-pointer"
              />
            </div>

            {/* Best of sets */}
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

          <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 flex flex-wrap items-center justify-between gap-2">
            <span className="text-xs font-black text-white">Formato set</span>
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

          {/* SUBMIT BUTTON: INIZIA PARTITA */}
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
    </div>
  );
};
