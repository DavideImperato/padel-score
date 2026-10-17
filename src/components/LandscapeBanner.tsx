import React, { useEffect, useState } from 'react';
import { Smartphone, Maximize2 } from 'lucide-react';

interface LandscapeBannerProps {
  onForceFullscreen: () => void;
}

export const LandscapeBanner: React.FC<LandscapeBannerProps> = ({ onForceFullscreen }) => {
  const [isPortrait, setIsPortrait] = useState(false);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    const checkOrientation = () => {
      if (typeof window === 'undefined') return;
      const portrait = window.innerHeight > window.innerWidth && window.innerWidth < 768;
      setIsPortrait(portrait);
    };

    checkOrientation();
    window.addEventListener('resize', checkOrientation);
    window.addEventListener('orientationchange', checkOrientation);
    return () => {
      window.removeEventListener('resize', checkOrientation);
      window.removeEventListener('orientationchange', checkOrientation);
    };
  }, []);

  if (!isPortrait || dismissed) return null;

  return (
    <div className="fixed top-12 left-4 right-4 z-40 p-3 bg-gradient-to-r from-amber-950/95 to-slate-900/95 border border-amber-500/60 rounded-xl shadow-xl flex items-center justify-between gap-3 text-xs text-white backdrop-blur-md animate-bounce">
      <div className="flex items-center gap-2.5">
        <Smartphone className="w-5 h-5 text-amber-400 rotate-90 shrink-0" />
        <div>
          <span className="font-black text-amber-300">MODALITÀ TABELLONE PADEL:</span>
          <p className="text-[11px] text-slate-300">
            Ruota lo smartphone in <strong>Orizzontale (Landscape)</strong> per la massima visibilità da fondo campo (15m).
          </p>
        </div>
      </div>

      <div className="flex items-center gap-2 shrink-0">
        <button
          onClick={onForceFullscreen}
          className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-amber-500 hover:bg-amber-400 text-slate-950 font-black text-xs transition-colors"
        >
          <Maximize2 className="w-3.5 h-3.5" />
          <span>Orizzontale</span>
        </button>
        <button
          onClick={() => setDismissed(true)}
          className="text-slate-400 hover:text-white p-1"
        >
          ✕
        </button>
      </div>
    </div>
  );
};
