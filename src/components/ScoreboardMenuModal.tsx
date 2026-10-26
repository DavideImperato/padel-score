import React from 'react';
import {
  X,
  UserCheck,
  ArrowLeftRight,
  Hourglass,
  Sparkles,
  Volume2,
  VolumeX,
  Info,
  Bluetooth,
  Maximize2,
  Minimize2,
  Settings,
  Flag,
  RotateCcw,
  LayoutGrid,
} from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot } from '../types/padel';

interface ScoreboardMenuModalProps {
  isOpen: boolean;
  onClose: () => void;
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  servingPlayerName: string;
  isFullscreen: boolean;
  onToggleServingTeam: () => void;
  onSwitchSides: () => void;
  onStartBreak: () => void;
  onToggleGoldenPoint: () => void;
  onToggleMute: () => void;
  onOpenMatchInfo: () => void;
  onOpenRemoteHelper: () => void;
  onToggleFullscreen: () => void;
  onOpenSettings: () => void;
  onTerminate: () => void;
  onReset: () => void;
  onGoToSetup: () => void;
}

export const ScoreboardMenuModal: React.FC<ScoreboardMenuModalProps> = ({
  isOpen,
  onClose,
  settings,
  servingPlayerName,
  isFullscreen,
  onToggleServingTeam,
  onSwitchSides,
  onStartBreak,
  onToggleGoldenPoint,
  onToggleMute,
  onOpenMatchInfo,
  onOpenRemoteHelper,
  onToggleFullscreen,
  onOpenSettings,
  onTerminate,
  onReset,
  onGoToSetup,
}) => {
  if (!isOpen) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="scoreboard-menu-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-black/80 backdrop-blur-sm animate-in fade-in duration-150 select-none"
      onClick={onClose}
    >
      <div
        className="w-full max-w-2xl max-h-[92vh] flex flex-col bg-zinc-950 border border-zinc-800 rounded-2xl shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-zinc-850 shrink-0">
          <div>
            <h2 id="scoreboard-menu-title" className="text-base sm:text-lg font-bold text-white tracking-wide">
              Menu Partita
            </h2>
            <p className="text-xs text-zinc-400">
              Azioni di campo, impostazioni e gestione match
            </p>
          </div>
          <button
            onClick={onClose}
            aria-label="Chiudi menu"
            className="p-1.5 rounded-lg text-zinc-400 hover:text-white hover:bg-zinc-850 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="p-4 sm:p-5 overflow-y-auto space-y-4 sm:space-y-5 text-sm">
          {/* Sezione 1: Azioni di Campo */}
          <div>
            <h3 className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-2 px-1">
              Campo & Battuta
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {/* Cambia Battitore */}
              <button
                onClick={() => {
                  onToggleServingTeam();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-lime-500/10 text-lime-400 shrink-0 mt-0.5">
                  <UserCheck className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Cambia Battitore
                  </span>
                  <span className="text-[11px] text-zinc-400 truncate block mt-0.5">
                    Attuale: <strong className="text-lime-400 font-bold">{servingPlayerName}</strong>
                  </span>
                </div>
              </button>

              {/* Cambio Campo */}
              <button
                onClick={() => {
                  onClose();
                  onSwitchSides();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-sky-500/10 text-sky-400 shrink-0 mt-0.5">
                  <ArrowLeftRight className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Cambio Campo
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Inverte lati e avvia pausa 90s
                  </span>
                </div>
              </button>

              {/* Pausa 90s */}
              <button
                onClick={() => {
                  onClose();
                  onStartBreak();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-cyan-500/10 text-cyan-400 shrink-0 mt-0.5">
                  <Hourglass className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Pausa 90s (FIP)
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Timer riposo regolamentare
                  </span>
                </div>
              </button>
            </div>
          </div>

          {/* Sezione 2: Regole & Audio */}
          <div>
            <h3 className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-2 px-1">
              Regole & Audio
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {/* Punto d'oro / Vantaggi */}
              <button
                onClick={() => {
                  onToggleGoldenPoint();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-amber-500/10 text-amber-400 shrink-0 mt-0.5">
                  <Sparkles className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Regola Parità
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    {settings.isGoldenPoint ? (
                      <strong className="text-amber-400 font-bold">Punto d'Oro attivo</strong>
                    ) : (
                      <strong className="text-sky-400 font-bold">Vantaggi classici</strong>
                    )}
                  </span>
                </div>
              </button>

              {/* Voce Arbitro */}
              <button
                onClick={() => {
                  onToggleMute();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className={`p-2 rounded-lg shrink-0 mt-0.5 ${settings.isVoiceMuted ? 'bg-rose-500/10 text-rose-400' : 'bg-emerald-500/10 text-emerald-400'}`}>
                  {settings.isVoiceMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Voce Arbitro
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    {settings.isVoiceMuted ? (
                      <strong className="text-rose-400 font-bold">Silenziosa (Muta)</strong>
                    ) : (
                      <strong className="text-emerald-400 font-bold">Attiva (Italiano)</strong>
                    )}
                  </span>
                </div>
              </button>

              {/* Dettagli Match */}
              <button
                onClick={() => {
                  onClose();
                  onOpenMatchInfo();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-indigo-500/10 text-indigo-400 shrink-0 mt-0.5">
                  <Info className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Dettagli & Set
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Riepilogo punteggi e storico
                  </span>
                </div>
              </button>
            </div>
          </div>

          {/* Sezione 3: Dispositivo & Sistema */}
          <div>
            <h3 className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-2 px-1">
              Dispositivo & Preferenze
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {/* Telecomando Bluetooth */}
              <button
                onClick={() => {
                  onClose();
                  onOpenRemoteHelper();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-emerald-500/10 text-emerald-400 shrink-0 mt-0.5">
                  <Bluetooth className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Telecomando
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Guida e test tasti Bluetooth
                  </span>
                </div>
              </button>

              {/* Schermo Intero */}
              <button
                onClick={() => {
                  onToggleFullscreen();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-zinc-800 text-zinc-300 shrink-0 mt-0.5">
                  {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Schermo Intero
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    {isFullscreen ? 'Disattiva fullscreen' : 'Attiva fullscreen'}
                  </span>
                </div>
              </button>

              {/* Impostazioni */}
              <button
                onClick={() => {
                  onClose();
                  onOpenSettings();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-zinc-800 text-zinc-300 shrink-0 mt-0.5">
                  <Settings className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Impostazioni
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Velocità voce, regole e nomi
                  </span>
                </div>
              </button>
            </div>
          </div>

          {/* Sezione 4: Gestione Match */}
          <div className="pt-2 border-t border-zinc-850">
            <h3 className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-2 px-1">
              Conclusione Match
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {/* Termina Match */}
              <button
                onClick={() => {
                  onClose();
                  onTerminate();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-rose-950/20 hover:bg-rose-950/40 border border-rose-900/40 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-rose-500/10 text-rose-400 shrink-0 mt-0.5">
                  <Flag className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-rose-200 block text-xs sm:text-sm">
                    Termina Partita
                  </span>
                  <span className="text-[11px] text-rose-300/70 block mt-0.5">
                    Chiude match e genera riepilogo
                  </span>
                </div>
              </button>

              {/* Azzera Punteggio */}
              <button
                onClick={() => {
                  onClose();
                  onReset();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-zinc-800 text-zinc-400 shrink-0 mt-0.5">
                  <RotateCcw className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Azzera Partita
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Resetta punti e cronometro
                  </span>
                </div>
              </button>

              {/* Configurazione Iniziale */}
              <button
                onClick={() => {
                  onClose();
                  onGoToSetup();
                }}
                className="flex items-start gap-3 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800/90 text-left transition-colors cursor-pointer"
              >
                <div className="p-2 rounded-lg bg-zinc-800 text-zinc-400 shrink-0 mt-0.5">
                  <LayoutGrid className="w-4 h-4" />
                </div>
                <div className="min-w-0">
                  <span className="font-semibold text-white block text-xs sm:text-sm">
                    Setup Iniziale
                  </span>
                  <span className="text-[11px] text-zinc-400 block mt-0.5">
                    Nuovi giocatori e squadre
                  </span>
                </div>
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-zinc-850 bg-zinc-900/40 flex items-center justify-end shrink-0">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-white font-medium text-xs tracking-wider transition-colors cursor-pointer"
          >
            Chiudi
          </button>
        </div>
      </div>
    </div>
  );
};
