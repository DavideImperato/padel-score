import React from 'react';
import { Flag, AlertCircle, X } from 'lucide-react';

interface TerminateConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
}

export const TerminateConfirmModal: React.FC<TerminateConfirmModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-sm select-none animate-in fade-in duration-200">
      <div className="w-full max-w-md bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 bg-slate-950 border-b border-slate-800">
          <div className="flex items-center gap-2.5 text-rose-400">
            <Flag className="w-5 h-5 shrink-0" />
            <h3 className="text-base font-black tracking-wide text-white">
              Terminare la Partita?
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
        <div className="p-6 space-y-3">
          <p className="text-sm text-slate-300 leading-relaxed">
            Vuoi concludere adesso l'incontro in corso? Verrà generata la <strong>Schermata di Riepilogo Finale</strong> con i vincitori, la tabella dei set e il tempo di gioco.
          </p>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 bg-slate-950 border-t border-slate-800">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-bold text-slate-300 hover:text-white bg-slate-800 hover:bg-slate-700 transition-colors cursor-pointer"
          >
            Continua a Giocare
          </button>
          <button
            onClick={() => {
              onConfirm();
              onClose();
            }}
            className="flex items-center gap-2 px-5 py-2 rounded-xl text-xs font-black text-white bg-gradient-to-r from-red-600 to-rose-600 hover:from-red-500 hover:to-rose-500 shadow-lg shadow-rose-950/60 transition-all cursor-pointer active:scale-95"
          >
            <Flag className="w-4 h-4" />
            <span>Termina e Mostra Riepilogo</span>
          </button>
        </div>
      </div>
    </div>
  );
};
