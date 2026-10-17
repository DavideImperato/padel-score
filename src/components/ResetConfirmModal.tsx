import React from 'react';
import { RotateCcw, AlertTriangle, X, Settings2 } from 'lucide-react';

interface ResetConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirmReset: () => void;
  onGoToSetup: () => void;
}

export const ResetConfirmModal: React.FC<ResetConfirmModalProps> = ({
  isOpen,
  onClose,
  onConfirmReset,
  onGoToSetup,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm select-none animate-in fade-in duration-200">
      <div className="w-full max-w-md bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 bg-slate-950 border-b border-slate-800">
          <div className="flex items-center gap-2.5 text-rose-400">
            <AlertTriangle className="w-5 h-5 shrink-0" />
            <h3 className="text-base font-black tracking-wide text-white">
              Cosa desideri fare?
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-4">
          <p className="text-sm text-slate-300 leading-relaxed">
            Scegli se azzerare solo i punteggi mantenendo le squadre attuali, oppure tornare alla schermata iniziale di Setup per impostare una nuova partita.
          </p>

          <div className="space-y-2.5 pt-1">
            <button
              onClick={() => {
                onConfirmReset();
                onClose();
              }}
              className="w-full flex items-center justify-between p-3.5 rounded-xl bg-slate-800 hover:bg-slate-700/90 border border-slate-700 text-left transition-all cursor-pointer group"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-rose-500/20 text-rose-400 border border-rose-500/30 group-hover:scale-105 transition-transform">
                  <RotateCcw className="w-4 h-4" />
                </div>
                <div>
                  <div className="text-sm font-black text-white">Azzera Solo Punteggi</div>
                  <div className="text-xs text-slate-400">Riparte da 0-0 con le stesse squadre e battitori</div>
                </div>
              </div>
            </button>

            <button
              onClick={() => {
                onGoToSetup();
                onClose();
              }}
              className="w-full flex items-center justify-between p-3.5 rounded-xl bg-slate-800 hover:bg-slate-700/90 border border-slate-700 text-left transition-all cursor-pointer group"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-[#CCFF00]/20 text-[#CCFF00] border border-[#CCFF00]/30 group-hover:scale-105 transition-transform">
                  <Settings2 className="w-4 h-4" />
                </div>
                <div>
                  <div className="text-sm font-black text-white">Nuova Partita (Setup Match)</div>
                  <div className="text-xs text-slate-400">Azzera e torna alla schermata iniziale di configurazione</div>
                </div>
              </div>
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end px-6 py-3.5 bg-slate-950 border-t border-slate-800">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-bold text-slate-400 hover:text-white bg-slate-900 hover:bg-slate-800 border border-slate-800 transition-colors cursor-pointer"
          >
            Annulla
          </button>
        </div>
      </div>
    </div>
  );
};
