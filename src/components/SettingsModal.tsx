import React, { useState } from 'react';
import { X, Volume2, Sparkles, Trophy, Users } from 'lucide-react';
import { MatchSettings } from '../types/padel';
import { padelAudio } from '../utils/padelAudio';

interface SettingsModalProps {
  isOpen: boolean;
  settings: MatchSettings;
  onClose: () => void;
  onSave: (updated: Partial<MatchSettings>) => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  settings,
  onClose,
  onSave,
}) => {
  const [teamAName, setTeamAName] = useState(settings.teamAName);
  const [teamBName, setTeamBName] = useState(settings.teamBName);
  const [isGoldenPoint, setIsGoldenPoint] = useState(settings.isGoldenPoint);
  const [bestOfSets, setBestOfSets] = useState(settings.bestOfSets);
  const [ttsSpeed, setTtsSpeed] = useState(settings.ttsSpeed);

  if (!isOpen) return null;

  const handleTestVoice = () => {
    padelAudio.setSpeed(ttsSpeed);
    padelAudio.speak(`Test audio sintesi vocale. Quindici a trenta, servizio ${teamAName}. Punto d'Oro attivo!`);
  };

  const handleSave = () => {
    padelAudio.setSpeed(ttsSpeed);
    onSave({
      teamAName: teamAName.trim() || 'Squadra A',
      teamBName: teamBName.trim() || 'Squadra B',
      isGoldenPoint,
      bestOfSets,
      ttsSpeed,
    });
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
      <div className="w-full max-w-xl bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950">
          <div className="flex items-center gap-2">
            <Trophy className="w-5 h-5 text-[#CCFF00]" />
            <h3 className="text-lg font-black tracking-wide text-white">
              Impostazioni Padel ScoreBot
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-6 overflow-y-auto text-slate-200">
          {/* Team Names */}
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-sm font-bold text-slate-300">
              <Users className="w-4 h-4 text-[#CCFF00]" />
              <span>Nomi Squadre</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">
                  Squadra A (Sinistra)
                </label>
                <input
                  type="text"
                  value={teamAName}
                  onChange={(e) => setTeamAName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-white font-bold focus:outline-none focus:border-[#CCFF00]"
                  placeholder="Es. Lebrón / Galán"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">
                  Squadra B (Destra)
                </label>
                <input
                  type="text"
                  value={teamBName}
                  onChange={(e) => setTeamBName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-white font-bold focus:outline-none focus:border-[#00E5FF]"
                  placeholder="Es. Coello / Tapia"
                />
              </div>
            </div>
          </div>

          <hr className="border-slate-800" />

          {/* Scoring Mode: Golden Point vs Advantages */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2 text-sm font-bold text-white">
                  <Sparkles className="w-4 h-4 text-amber-400" />
                  <span>Regola Punto d'Oro (Golden Point)</span>
                </div>
                <p className="text-xs text-slate-400 mt-0.5">
                  Sul 40-40 (pari), chi conquista il punto successivo vince direttamente il Game.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsGoldenPoint(!isGoldenPoint)}
                className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                  isGoldenPoint ? 'bg-[#CCFF00]' : 'bg-slate-700'
                }`}
              >
                <span
                  className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-slate-950 shadow ring-0 transition duration-200 ease-in-out ${
                    isGoldenPoint ? 'translate-x-5' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>
            {!isGoldenPoint && (
              <div className="p-2.5 rounded-lg bg-cyan-950/30 border border-cyan-800/40 text-xs text-cyan-300">
                Modalità Vantaggi Classici: sul 40-40 si procede a Vantaggio (AV) e occorrono 2 punti di scarto per vincere il Game.
              </div>
            )}
          </div>

          <hr className="border-slate-800" />

          {/* Match Format: Sets */}
          <div className="space-y-3">
            <label className="block text-sm font-bold text-white">
              Formato Partita
            </label>
            <div className="grid grid-cols-3 gap-3">
              {[
                { count: 1, label: '1 Set Secco' },
                { count: 3, label: 'Al meglio dei 3 Set' },
                { count: 5, label: 'Al meglio dei 5 Set' },
              ].map((item) => (
                <button
                  key={item.count}
                  type="button"
                  onClick={() => setBestOfSets(item.count)}
                  className={`py-2 px-3 rounded-xl border text-xs font-bold transition-all ${
                    bestOfSets === item.count
                      ? 'bg-[#CCFF00] text-slate-950 border-[#CCFF00] shadow-md shadow-[#CCFF00]/20 font-black'
                      : 'bg-slate-950 text-slate-400 border-slate-800 hover:border-slate-700'
                  }`}
                >
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          <hr className="border-slate-800" />

          {/* Voice Audio Settings */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-bold text-white">
                <Volume2 className="w-4 h-4 text-emerald-400" />
                <span>Sintesi Vocale Italiana (TTS)</span>
              </div>
              <button
                type="button"
                onClick={handleTestVoice}
                className="px-3 py-1 text-xs font-bold bg-slate-800 text-emerald-400 border border-slate-700 rounded-lg hover:bg-slate-700 transition-colors"
              >
                Prova Voce
              </button>
            </div>

            <div>
              <div className="flex justify-between text-xs text-slate-400 mb-1">
                <span>Velocità Annuncio:</span>
                <span className="font-mono text-emerald-400 font-bold">{ttsSpeed.toFixed(2)}x</span>
              </div>
              <input
                type="range"
                min="0.8"
                max="1.3"
                step="0.05"
                value={ttsSpeed}
                onChange={(e) => setTtsSpeed(parseFloat(e.target.value))}
                className="w-full accent-[#CCFF00] cursor-pointer"
              />
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-slate-800 bg-slate-950">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-bold text-slate-400 hover:text-white transition-colors"
          >
            Annulla
          </button>
          <button
            onClick={handleSave}
            className="px-6 py-2 text-sm font-black text-slate-950 bg-[#CCFF00] rounded-xl hover:bg-[#b8e600] transition-colors shadow-lg shadow-[#CCFF00]/30"
          >
            Salva Impostazioni
          </button>
        </div>
      </div>
    </div>
  );
};
