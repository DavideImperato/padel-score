import React from 'react';
import { Volume2, VolumeX, Undo2, RotateCcw, Settings, Maximize2, Minimize2, Radio, Code2, Sparkles, RefreshCw, Timer, Hourglass, ArrowLeft } from 'lucide-react';
import { MatchSettings, PadelMatchSnapshot } from '../types/padel';

interface HeaderBarProps {
  snapshot: PadelMatchSnapshot;
  settings: MatchSettings;
  canUndo: boolean;
  isFullscreen: boolean;
  matchTimeFormatted: string;
  isTimerRunning: boolean;
  isWakeLockActive: boolean;
  onToggleTimer: () => void;
  onStartBreak: () => void;
  onUndo: () => void;
  onToggleGoldenPoint: () => void;
  onToggleMute: () => void;
  onReset: () => void;
  onOpenSettings: () => void;
  onGoToSetup: () => void;
  onOpenRemoteHelper: () => void;
  onOpenFlutterCode: () => void;
  onToggleFullscreen: () => void;
  onSwitchSides: () => void;
}

export const HeaderBar: React.FC<HeaderBarProps> = ({
  snapshot,
  settings,
  canUndo,
  isFullscreen,
  matchTimeFormatted,
  isTimerRunning,
  isWakeLockActive,
  onToggleTimer,
  onStartBreak,
  onUndo,
  onToggleGoldenPoint,
  onToggleMute,
  onReset,
  onOpenSettings,
  onGoToSetup,
  onOpenRemoteHelper,
  onOpenFlutterCode,
  onToggleFullscreen,
  onSwitchSides,
}) => {
  const currentSetNum = snapshot.completedSets.length + 1;

  return (
    <header className="bg-slate-950/95 border-b border-slate-800/80 px-3 sm:px-4 py-2 flex items-center justify-between gap-2 shrink-0 select-none z-20 backdrop-blur-sm">
      {/* Left: Go to Setup Button + Mode Badge, Set info & Match Duration */}
      <div className="flex items-center gap-1.5 sm:gap-2.5">
        {/* Button to return to Match Setup screen */}
        <button
          onClick={onGoToSetup}
          title="Torna alla Schermata Setup Match"
          className="flex items-center gap-1 px-2.5 py-1 rounded-md bg-slate-900 border border-slate-700/80 hover:bg-slate-800 hover:border-slate-500 text-xs font-bold text-slate-200 transition-colors cursor-pointer"
        >
          <ArrowLeft className="w-3.5 h-3.5 text-[#CCFF00]" />
          <span className="hidden sm:inline">Setup Match</span>
        </button>

        {/* Golden Point / Advantages */}
        <button
          onClick={onToggleGoldenPoint}
          title="Clicca per alternare Punto d'Oro / Vantaggi"
          className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-black tracking-wider transition-all border cursor-pointer ${
            settings.isGoldenPoint
              ? 'bg-amber-500/15 text-amber-300 border-amber-500/40 hover:bg-amber-500/25'
              : 'bg-cyan-500/15 text-cyan-300 border-cyan-500/40 hover:bg-cyan-500/25'
          }`}
        >
          <Sparkles className="w-3.5 h-3.5" />
          {settings.isGoldenPoint ? "PUNTO D'ORO" : 'VANTAGGI'}
        </button>

        {/* Set Indicator */}
        <div className="hidden md:flex items-center gap-1.5 px-3 py-1 rounded-md bg-slate-900 border border-slate-800 text-xs font-bold tracking-wider text-slate-200">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
          {snapshot.isTieBreak ? (
            <span className="text-purple-400 font-extrabold">SET {currentSetNum}: TIE-BREAK</span>
          ) : (
            <span>SET {currentSetNum}</span>
          )}
        </div>

        {/* Match Duration Stopwatch */}
        <button
          onClick={onToggleTimer}
          title={isTimerRunning ? 'Pausa cronometro match' : 'Avvia cronometro match'}
          className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-900 border border-slate-700/80 hover:border-slate-500 text-xs font-mono font-bold text-slate-200 transition-colors cursor-pointer"
        >
          <Timer className={`w-3.5 h-3.5 ${isTimerRunning ? 'text-emerald-400' : 'text-amber-400'}`} />
          <span>{matchTimeFormatted}</span>
        </button>

        {/* Screen Always ON indicator */}
        {isWakeLockActive && (
          <div
            title="Schermo sempre attivo (non si spegne a bordo campo)"
            className="hidden xl:flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30"
          >
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
            <span>NO SLEEP</span>
          </div>
        )}
      </div>

      {/* Center: Bluetooth remote quick status & Break 90s */}
      <div className="flex items-center gap-2">
        {/* Cambio Campo 90s FIP */}
        <button
          onClick={onStartBreak}
          title="Avvia timer cambio campo regolamentare FIP (90 secondi)"
          className="flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-900 border border-cyan-500/40 hover:bg-cyan-950/40 text-cyan-300 text-xs font-bold transition-all cursor-pointer"
        >
          <Hourglass className="w-3.5 h-3.5 text-cyan-400" />
          <span className="hidden sm:inline">Pausa 90s</span>
        </button>

        {/* Remote Helper Trigger */}
        <button
          onClick={onOpenRemoteHelper}
          className="flex items-center gap-2 px-3 py-1 rounded-md bg-slate-900/90 border border-slate-700/80 hover:border-emerald-500/60 text-xs text-slate-300 transition-colors cursor-pointer group"
          title="Apri pannello di test telecomando Bluetooth"
        >
          <Radio className="w-3.5 h-3.5 text-emerald-400 group-hover:animate-pulse" />
          <span className="hidden lg:inline font-mono text-[11px] text-slate-400">
            <strong className="text-emerald-300">Vol+</strong> 1x: Sq.1 | 2x: Sq.2 | <strong className="text-amber-300">Vol-</strong>: Undo
          </span>
          <span className="lg:hidden font-mono text-[11px] text-emerald-400 font-semibold">
            Telecomando BT
          </span>
        </button>
      </div>

      {/* Right: Quick Action Buttons */}
      <div className="flex items-center gap-1 sm:gap-2">
        {/* Undo */}
        <button
          onClick={onUndo}
          disabled={!canUndo}
          title="Annulla ultimo punto (Vol Down o Tasto U)"
          className={`p-2 rounded-lg transition-colors border cursor-pointer ${
            canUndo
              ? 'bg-slate-900 text-white border-slate-700 hover:bg-slate-800 hover:border-slate-500 active:scale-95'
              : 'bg-slate-950 text-slate-600 border-slate-900 cursor-not-allowed'
          }`}
        >
          <Undo2 className="w-4 h-4" />
        </button>

        {/* Switch Sides */}
        <button
          onClick={onSwitchSides}
          title="Scambia campo tra le squadre (e avvia pausa)"
          className="p-2 rounded-lg bg-slate-900 text-slate-300 border border-slate-700 hover:bg-slate-800 hover:text-white transition-colors cursor-pointer"
        >
          <RefreshCw className="w-4 h-4" />
        </button>

        {/* Mute TTS */}
        <button
          onClick={onToggleMute}
          title={settings.isMuted ? 'Attiva sintesi vocale italiana' : 'Disattiva audio voce'}
          className={`p-2 rounded-lg transition-colors border cursor-pointer ${
            settings.isMuted
              ? 'bg-rose-950/40 text-rose-400 border-rose-800/60 hover:bg-rose-900/40'
              : 'bg-emerald-950/40 text-emerald-400 border-emerald-800/60 hover:bg-emerald-900/40'
          }`}
        >
          {settings.isMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
        </button>

        {/* Reset (apre modale affidabile) */}
        <button
          onClick={onReset}
          title="Azzera Punteggio (Reset)"
          className="p-2 rounded-lg bg-slate-900 text-rose-400 border border-slate-700 hover:bg-rose-950/40 hover:border-rose-700 transition-colors cursor-pointer"
        >
          <RotateCcw className="w-4 h-4" />
        </button>

        {/* Settings */}
        <button
          onClick={onOpenSettings}
          title="Impostazioni match"
          className="p-2 rounded-lg bg-slate-900 text-slate-300 border border-slate-700 hover:bg-slate-800 hover:text-white transition-colors cursor-pointer"
        >
          <Settings className="w-4 h-4" />
        </button>

        {/* Fullscreen / Orientation */}
        <button
          onClick={onToggleFullscreen}
          title={isFullscreen ? 'Esci da schermo intero' : 'Schermo intero (Landscape Lock)'}
          className="p-2 rounded-lg bg-slate-900 text-amber-300 border border-slate-700 hover:bg-slate-800 hover:text-amber-200 transition-colors cursor-pointer"
        >
          {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
        </button>

        {/* Flutter Source Code viewer button */}
        <button
          onClick={onOpenFlutterCode}
          title="Visualizza e scarica codice Flutter completo"
          className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-gradient-to-r from-sky-600 to-blue-600 text-white font-bold text-xs hover:from-sky-500 hover:to-blue-500 shadow-md shadow-sky-900/40 transition-all border border-sky-400/40 cursor-pointer"
        >
          <Code2 className="w-4 h-4" />
          <span className="hidden xl:inline">Codice Flutter</span>
        </button>
      </div>
    </header>
  );
};
