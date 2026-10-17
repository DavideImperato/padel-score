import React from 'react';
import { X, Radio, ArrowUp, ArrowDown, HelpCircle, CheckCircle2 } from 'lucide-react';

interface RemoteHelperModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSimulateVolUpSingle: () => void;
  onSimulateVolUpDouble: () => void;
  onSimulateVolDown: () => void;
  lastLogs: Array<{ text: string; time: string; type: 'up1' | 'up2' | 'down' | 'other' }>;
}

export const RemoteHelperModal: React.FC<RemoteHelperModalProps> = ({
  isOpen,
  onClose,
  onSimulateVolUpSingle,
  onSimulateVolUpDouble,
  onSimulateVolDown,
  lastLogs,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm select-none">
      <div className="w-full max-w-2xl bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950">
          <div className="flex items-center gap-2">
            <Radio className="w-5 h-5 text-emerald-400 animate-pulse" />
            <h3 className="text-lg font-black tracking-wide text-white">
              Controllo Telecomando Bluetooth Economico
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6 overflow-y-auto text-slate-200">
          {/* Explanation banner */}
          <div className="p-4 rounded-xl bg-slate-950/80 border border-slate-800 space-y-2">
            <div className="flex items-center gap-2 text-sm font-bold text-[#CCFF00]">
              <HelpCircle className="w-4 h-4" />
              <span>Come funziona con qualsiasi telecomando selfie (da 3-5€)</span>
            </div>
            <p className="text-xs text-slate-300 leading-relaxed">
              I telecomandi Bluetooth da selfie (tipo <em>AB Shutter 3</em> o pulsanti multimediali) inviano al telefono i codici dei tasti <strong>Volume Su</strong> o <strong>Volume Giù</strong>. L'app intercetta questi segnali sia da browser che nell'app Flutter nativa:
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 pt-2">
              <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-center">
                <div className="text-xs font-bold text-emerald-400">1 Click Vol+</div>
                <div className="text-sm font-black text-white mt-1">+1 Squadra A</div>
                <div className="text-[10px] text-slate-500">Sinistra</div>
              </div>
              <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-center">
                <div className="text-xs font-bold text-cyan-400">2 Click Vol+ (&lt;400ms)</div>
                <div className="text-sm font-black text-white mt-1">+1 Squadra B</div>
                <div className="text-[10px] text-slate-500">Destra</div>
              </div>
              <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-center">
                <div className="text-xs font-bold text-rose-400">1 Click Vol-</div>
                <div className="text-sm font-black text-white mt-1">Undo</div>
                <div className="text-[10px] text-slate-500">Annulla Punto</div>
              </div>
            </div>
          </div>

          {/* Interactive Simulation buttons */}
          <div className="space-y-3">
            <h4 className="text-xs font-black uppercase tracking-wider text-slate-400">
              Test Interattivo Comandi (Simulatore a Schermo)
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <button
                onClick={onSimulateVolUpSingle}
                className="flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-slate-800 hover:bg-slate-700 border border-emerald-500/50 text-emerald-300 font-bold text-xs transition-all active:scale-95 shadow-md"
              >
                <ArrowUp className="w-4 h-4 text-emerald-400" />
                <span>Simula 1x Vol+ (Sq. A)</span>
              </button>

              <button
                onClick={onSimulateVolUpDouble}
                className="flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-slate-800 hover:bg-slate-700 border border-cyan-500/50 text-cyan-300 font-bold text-xs transition-all active:scale-95 shadow-md"
              >
                <div className="flex -space-x-1">
                  <ArrowUp className="w-3.5 h-3.5 text-cyan-400" />
                  <ArrowUp className="w-3.5 h-3.5 text-cyan-400" />
                </div>
                <span>Simula 2x Vol+ (Sq. B)</span>
              </button>

              <button
                onClick={onSimulateVolDown}
                className="flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-slate-800 hover:bg-slate-700 border border-rose-500/50 text-rose-300 font-bold text-xs transition-all active:scale-95 shadow-md"
              >
                <ArrowDown className="w-4 h-4 text-rose-400" />
                <span>Simula 1x Vol- (Undo)</span>
              </button>
            </div>
          </div>

          {/* Live Log of hardware key presses */}
          <div className="space-y-2">
            <div className="flex items-center justify-between text-xs font-bold text-slate-400">
              <span>Log Ricezione Segnali Hardware in Tempo Reale:</span>
              <span className="text-[11px] text-slate-500">Premi tasti della tastiera (o clicker) per testare</span>
            </div>
            <div className="h-36 overflow-y-auto p-3 rounded-xl bg-black/60 border border-slate-800 font-mono text-xs space-y-1">
              {lastLogs.length === 0 ? (
                <div className="text-slate-500 italic py-6 text-center">
                  In attesa di segnali... Premi i tasti del telecomando o della tastiera (Frecce Su/Giù, A, B, U, Vol+/Vol-)
                </div>
              ) : (
                lastLogs.map((log, i) => (
                  <div
                    key={i}
                    className={`flex items-center gap-2 ${
                      log.type === 'up1'
                        ? 'text-emerald-400'
                        : log.type === 'up2'
                        ? 'text-cyan-400 font-bold'
                        : log.type === 'down'
                        ? 'text-amber-400'
                        : 'text-slate-400'
                    }`}
                  >
                    <span className="text-slate-600 text-[10px]">[{log.time}]</span>
                    <span>{log.text}</span>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Compatibility Tips */}
          <div className="p-3 rounded-lg bg-emerald-950/20 border border-emerald-800/40 text-xs text-emerald-300 flex items-start gap-2">
            <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-400 mt-0.5" />
            <span>
              <strong>Consiglio:</strong> Nei telefoni Android e iOS, associa il telecomando Bluetooth via Impostazioni &gt; Bluetooth. Non serve alcuna app speciale, viene riconosciuto direttamente come tastiera multimediale!
            </span>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-slate-800 bg-slate-950 flex justify-end">
          <button
            onClick={onClose}
            className="px-6 py-2 rounded-xl bg-slate-800 text-white font-bold text-sm hover:bg-slate-700 transition-colors"
          >
            Chiudi
          </button>
        </div>
      </div>
    </div>
  );
};
