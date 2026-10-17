import React from 'react';
import { Settings } from 'lucide-react';

interface HeaderBarProps {
  onOpenSettings: () => void;
}

export const HeaderBar: React.FC<HeaderBarProps> = ({ onOpenSettings }) => {
  return (
    <header className="bg-slate-950/80 px-4 py-2 flex items-center justify-end shrink-0 z-20 border-b border-slate-900 select-none">
      <button
        onClick={onOpenSettings}
        title="Impostazioni"
        className="p-2 rounded-xl bg-slate-900 border border-slate-800 hover:bg-slate-800 hover:border-slate-600 text-slate-300 hover:text-white transition-all cursor-pointer shadow-sm active:scale-95"
      >
        <Settings className="w-5 h-5 text-slate-200" />
      </button>
    </header>
  );
};
