import React, { useState, useEffect } from 'react';
import {
  X,
  Volume2,
  VolumeX,
  Sparkles,
  Trophy,
  Users,
  Radio,
  ExternalLink,
} from 'lucide-react';
import { MatchSettings } from '../types/padel';
import { padelAudio } from '../utils/padelAudio';

interface SettingsModalProps {
  isOpen: boolean;
  settings: MatchSettings;
  onClose: () => void;
  onSave: (updated: Partial<MatchSettings>) => void;
  onOpenRemoteHelper?: () => void;
  onToggleSmartwatchMode?: () => void;
  isSmartwatchMode?: boolean;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  settings,
  onClose,
  onSave,
  onOpenRemoteHelper,
  onToggleSmartwatchMode,
  isSmartwatchMode,
}) => {
  const [teamAName, setTeamAName] = useState(settings.teamAName);
  const [teamBName, setTeamBName] = useState(settings.teamBName);
  const [isGoldenPoint, setIsGoldenPoint] = useState(settings.isGoldenPoint);
  const [bestOfSets, setBestOfSets] = useState(settings.bestOfSets);
  const [ttsSpeed, setTtsSpeed] = useState(settings.ttsSpeed);
  const [isVoiceMuted, setIsVoiceMuted] = useState(settings.isVoiceMuted ?? false);
  const [advantagesBeforeGoldenPoint, setAdvantagesBeforeGoldenPoint] = useState<number>(
    settings.advantagesBeforeGoldenPoint ?? 0
  );
  const [testFeedback, setTestFeedback] = useState(false);

  // Sync settings when modal opens
  useEffect(() => {
    if (isOpen) {
      setTeamAName(settings.teamAName);
      setTeamBName(settings.teamBName);
      setIsGoldenPoint(settings.isGoldenPoint);
      setBestOfSets(settings.bestOfSets);
      setTtsSpeed(settings.ttsSpeed);
      setIsVoiceMuted(settings.isVoiceMuted ?? false);
      setAdvantagesBeforeGoldenPoint(settings.advantagesBeforeGoldenPoint ?? 0);
      setTestFeedback(false);
    }
  }, [isOpen, settings]);

  if (!isOpen) return null;

  const handleTestVoice = () => {
    padelAudio.unlockAudio();
    padelAudio.setVoiceMuted(false);
    padelAudio.setSpeed(ttsSpeed);
    setIsVoiceMuted(false);
    padelAudio.speak(`15 - 30, servizio ${teamBName || 'Squadra B'}, batte Marco.`);
    setTestFeedback(true);
    setTimeout(() => setTestFeedback(false), 2000);
  };

  const handleSave = () => {
    padelAudio.setVoiceMuted(isVoiceMuted);
    padelAudio.setSpeed(ttsSpeed);
    onSave({
      teamAName: teamAName.trim() || 'Squadra A',
      teamBName: teamBName.trim() || 'Squadra B',
      isGoldenPoint,
      advantagesBeforeGoldenPoint,
      bestOfSets,
      ttsSpeed,
      isVoiceMuted,
      isSfxMuted: true,
    });
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md select-none">
      <div className="w-full max-w-xl bg-slate-900 border border-slate-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950">
          <div className="flex items-center gap-2.5">
            <Trophy className="w-5 h-5 text-[#CCFF00]" />
            <h3 className="text-lg font-black tracking-wide text-white uppercase">
              Impostazioni Partita
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-6 overflow-y-auto text-slate-200">
          {/* 1. SEZIONE AUDIO: VOCE ARBITRALE ITALIANA DEDICATA (SFX RIMOSSI PER PRIORITÀ VOCE) */}
          <div className="p-4 rounded-2xl bg-slate-950/90 border border-slate-800 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-black text-white uppercase tracking-wider">
                <Volume2 className="w-4 h-4 text-[#CCFF00]" />
                <span>Voce Arbitrale Automatica</span>
              </div>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                Lingua: it-IT (Nativa)
              </span>
            </div>

            {/* Switch Attiva / Disattiva Voce */}
            <div className="flex items-center justify-between p-3 rounded-xl bg-slate-900 border border-slate-800">
              <div className="pr-3">
                <div className="flex items-center gap-2 text-sm font-bold text-white">
                  {isVoiceMuted ? (
                    <VolumeX className="w-4 h-4 text-rose-400" />
                  ) : (
                    <Volume2 className="w-4 h-4 text-emerald-400" />
                  )}
                  <span>{isVoiceMuted ? 'Voce Arbitrale Disattivata' : 'Voce Arbitrale Attiva'}</span>
                </div>
                <p className="text-xs text-slate-400 mt-0.5">
                  Annuncio automatico ad ogni punto ("15 - 30, servizio Squadra B, batte Marco"), game, set e punto d'oro.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsVoiceMuted(!isVoiceMuted)}
                className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                  isVoiceMuted ? 'bg-rose-500' : 'bg-emerald-500'
                }`}
              >
                <span
                  className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow transition duration-200 ease-in-out ${
                    !isVoiceMuted ? 'translate-x-5' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>

            {/* Velocità Voce e Pulsante Test Immediato */}
            <div className="px-1 space-y-2 pt-1">
              <div className="flex justify-between items-center text-xs">
                <span className="text-slate-400 font-semibold">Velocità Pronuncia Arbitro:</span>
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

            {/* Test Pronuncia Voce */}
            <div className="pt-1">
              <button
                type="button"
                onClick={handleTestVoice}
                className="w-full py-2.5 px-3 rounded-xl bg-slate-900 hover:bg-slate-800 border border-emerald-500/40 text-xs font-black text-emerald-300 flex items-center justify-center gap-2 transition-colors cursor-pointer shadow-sm hover:shadow-emerald-500/10"
              >
                <Volume2 className="w-4 h-4 text-emerald-400" />
                <span>{testFeedback ? '🔊 Annuncio in corso...' : 'Ascolta Test Voce Arbitro'}</span>
              </button>
            </div>
          </div>

          {/* 2. SEZIONE REGOLE (PUNTO D'ORO VS VANTAGGI & FORMATO SET) */}
          <div className="p-4 rounded-2xl bg-slate-950/90 border border-slate-800 space-y-4">
            <div className="flex items-center gap-2 text-sm font-black text-white uppercase tracking-wider">
              <Sparkles className="w-4 h-4 text-amber-400" />
              <span>Sezione Regole di Gioco</span>
            </div>

            {/* Modalità Vantaggi: Vantaggi classici o Punto d'oro */}
            <div className="space-y-2">
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider">
                Modalità sul 40 Pari (Deuce):
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsGoldenPoint(true)}
                  className={`p-3 rounded-xl border text-left transition-all cursor-pointer ${
                    isGoldenPoint
                      ? 'bg-amber-500/20 border-amber-500 text-white shadow-md shadow-amber-500/20'
                      : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700'
                  }`}
                >
                  <div className="flex items-center gap-2 font-black text-sm text-amber-300">
                    <Sparkles className="w-4 h-4" />
                    <span>Punto d'Oro (Golden Point)</span>
                  </div>
                  <p className="text-[11px] text-slate-400 mt-1 leading-snug">
                    Sul 40-40, chi vince lo scambio successivo vince istantaneamente il game.
                  </p>
                </button>

                <button
                  type="button"
                  onClick={() => setIsGoldenPoint(false)}
                  className={`p-3 rounded-xl border text-left transition-all cursor-pointer ${
                    !isGoldenPoint
                      ? 'bg-cyan-500/20 border-cyan-500 text-white shadow-md shadow-cyan-500/20'
                      : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700'
                  }`}
                >
                  <div className="flex items-center gap-2 font-black text-sm text-cyan-300">
                    <Trophy className="w-4 h-4" />
                    <span>Vantaggi Classici (AV)</span>
                  </div>
                  <p className="text-[11px] text-slate-400 mt-1 leading-snug">
                    Sul 40-40 si va ai vantaggi e servono due punti consecutivi per vincere.
                  </p>
                </button>
              </div>
            </div>

            {/* SEZIONE: VANTAGGI PRIMA DEL PUNTO D'ORO (SUBITO SOTTO PUNTO D'ORO, PRIMA DI FORMATO PARTITA) */}
            <div className="space-y-2 pt-2 border-t border-slate-800/80">
              <div className="flex items-center justify-between">
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider">
                  Vantaggi prima del punto d'oro:
                </label>
                <span className="text-[11px] font-bold text-amber-400">
                  {advantagesBeforeGoldenPoint === 0
                    ? 'Subito Punto d\'oro'
                    : advantagesBeforeGoldenPoint === 1
                    ? '1 Vantaggio poi Punto d\'oro'
                    : '2 Vantaggi poi Punto d\'oro'}
                </span>
              </div>

              <div className="grid grid-cols-3 gap-2">
                {[
                  {
                    val: 0,
                    label: '0 Vantaggi',
                    desc: 'Sul 40-40 si gioca subito il Punto d\'oro.',
                  },
                  {
                    val: 1,
                    label: '1 Vantaggio',
                    desc: 'Sul 40-40 si gioca 1 vantaggio; se si torna in parità, il punto successivo è il Punto d\'oro.',
                  },
                  {
                    val: 2,
                    label: '2 Vantaggi',
                    desc: 'Sul 40-40 si giocano fino a 2 vantaggi; in caso di ulteriore parità, si gioca il Punto d\'oro.',
                  },
                ].map((opt) => (
                  <button
                    key={opt.val}
                    type="button"
                    onClick={() => {
                      setAdvantagesBeforeGoldenPoint(opt.val);
                      if (!isGoldenPoint) setIsGoldenPoint(true);
                    }}
                    className={`p-2.5 rounded-xl border flex flex-col items-center text-center transition-all cursor-pointer ${
                      advantagesBeforeGoldenPoint === opt.val && isGoldenPoint
                        ? 'bg-amber-500/25 border-amber-500 text-white shadow-md shadow-amber-500/20'
                        : 'bg-slate-900 border-slate-800 text-slate-400 hover:border-slate-700'
                    }`}
                  >
                    <span className="font-mono text-lg font-black text-amber-400">
                      {opt.val}
                    </span>
                    <span className="text-xs font-bold mt-0.5 text-slate-200">
                      {opt.label}
                    </span>
                    <span className="text-[10px] text-slate-400 mt-1 leading-snug">
                      {opt.desc}
                    </span>
                  </button>
                ))}
              </div>
            </div>

            {/* Formato Partita (Set) */}
            <div className="space-y-2 pt-2 border-t border-slate-800/80">
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider">
                Formato Partita:
              </label>
              <div className="grid grid-cols-3 gap-2.5">
                {[
                  { count: 1, label: '1 Set Secco' },
                  { count: 3, label: 'Al meglio dei 3 Set' },
                  { count: 5, label: 'Al meglio dei 5 Set' },
                ].map((item) => (
                  <button
                    key={item.count}
                    type="button"
                    onClick={() => setBestOfSets(item.count)}
                    className={`py-2 px-3 rounded-xl border text-xs font-bold transition-all cursor-pointer text-center ${
                      bestOfSets === item.count
                        ? 'bg-[#CCFF00] text-slate-950 border-[#CCFF00] shadow-md shadow-[#CCFF00]/20 font-black'
                        : 'bg-slate-900 text-slate-400 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* 3. NOMI SQUADRE */}
          <div className="p-4 rounded-2xl bg-slate-950/90 border border-slate-800 space-y-3">
            <div className="flex items-center gap-2 text-sm font-black text-white uppercase tracking-wider">
              <Users className="w-4 h-4 text-[#CCFF00]" />
              <span>Nomi Squadre</span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">
                  Squadra A (Sinistra)
                </label>
                <input
                  type="text"
                  value={teamAName}
                  onChange={(e) => setTeamAName(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-white font-bold focus:outline-none focus:border-[#CCFF00]"
                  placeholder="Es. Gli Smashtori"
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
                  className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-white font-bold focus:outline-none focus:border-[#00E5FF]"
                  placeholder="Es. I Timemasters"
                />
              </div>
            </div>
          </div>

          {/* 4. TELECOMANDO BLUETOOTH */}
          <div className="p-4 rounded-2xl bg-slate-950/90 border border-emerald-500/30 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Radio className="w-4 h-4 text-emerald-400 animate-pulse" />
                <span className="text-xs font-black text-emerald-400 uppercase tracking-wider">
                  Telecomando Bluetooth
                </span>
              </div>
              <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                ATTIVO
              </span>
            </div>

            <div className="grid grid-cols-3 gap-2 font-mono text-[11px]">
              <div className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-center">
                <div className="text-emerald-400 font-bold">Vol+ (1 Click)</div>
                <div className="text-slate-400 text-[10px] mt-0.5">+1 Squadra A</div>
              </div>
              <div className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-center">
                <div className="text-cyan-400 font-bold">Vol+ (Doppio)</div>
                <div className="text-slate-400 text-[10px] mt-0.5">+1 Squadra B</div>
              </div>
              <div className="p-2 rounded-xl bg-slate-900 border border-slate-800 text-center">
                <div className="text-amber-400 font-bold">Vol- (Singolo)</div>
                <div className="text-slate-400 text-[10px] mt-0.5">Undo</div>
              </div>
            </div>

            {onOpenRemoteHelper && (
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onOpenRemoteHelper();
                }}
                className="w-full flex items-center justify-center gap-2 py-2 px-3 rounded-xl bg-slate-900 hover:bg-slate-800 text-slate-200 border border-slate-700 text-xs font-bold transition-colors cursor-pointer"
              >
                <ExternalLink className="w-3.5 h-3.5 text-emerald-400" />
                <span>Test & Simulatore Telecomando</span>
              </button>
            )}
          </div>

          {/* 5. SMARTWATCH */}
          {onToggleSmartwatchMode && (
            <div className="p-4 rounded-2xl bg-slate-950/90 border border-slate-800 flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2 text-xs font-bold text-white">
                  <span>⌚</span>
                  <span>Interfaccia Smartwatch (Apple Watch & Wear OS)</span>
                </div>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Modalità ottimizzata per display da polso.
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onToggleSmartwatchMode();
                }}
                className="px-3.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-black text-[#CCFF00] border border-slate-700 transition-colors cursor-pointer"
              >
                {isSmartwatchMode ? 'Disattiva' : 'Attiva'}
              </button>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-slate-800 bg-slate-950">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs font-bold text-slate-400 hover:text-white transition-colors cursor-pointer"
          >
            Annulla
          </button>
          <button
            onClick={handleSave}
            className="px-6 py-2.5 text-xs font-black text-slate-950 bg-[#CCFF00] rounded-xl hover:bg-[#b8e600] transition-colors shadow-lg shadow-[#CCFF00]/30 cursor-pointer active:scale-95 uppercase tracking-wider"
          >
            Salva Impostazioni
          </button>
        </div>
      </div>
    </div>
  );
};
