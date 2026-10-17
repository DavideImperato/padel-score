import React, { useEffect, useState } from 'react';
import { Smartphone, RotateCw } from 'lucide-react';

export const LandscapeEnforcer: React.FC = () => {
  const [isMobileOrTabletPortrait, setIsMobileOrTabletPortrait] = useState(false);

  useEffect(() => {
    const checkOrientationAndDevice = () => {
      if (typeof window === 'undefined') return;

      const width = window.innerWidth;
      const height = window.innerHeight;

      // Detect Smartwatch: very small screen (do NOT force landscape on wrist screens!)
      const isSmartwatch = (width <= 330 && height <= 380) || (width <= 380 && height <= 330);
      if (isSmartwatch) {
        setIsMobileOrTabletPortrait(false);
        return;
      }

      // Detect mobile or tablet
      const ua = navigator.userAgent || '';
      const isMobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(ua);
      const isTouchTablet = navigator.maxTouchPoints > 1 && (width <= 1180 || height <= 1180);
      const isMobileOrTablet = isMobileUA || isTouchTablet;

      // Portrait: height is greater than width
      const isPortrait = height > width;

      // Only enforce on mobile and tablet devices when in portrait
      setIsMobileOrTabletPortrait(isMobileOrTablet && isPortrait);
    };

    checkOrientationAndDevice();
    window.addEventListener('resize', checkOrientationAndDevice);
    window.addEventListener('orientationchange', checkOrientationAndDevice);

    // Attempt orientation lock if supported
    const tryLockLandscape = async () => {
      try {
        if ('orientation' in screen && 'lock' in (screen.orientation as any)) {
          await (screen.orientation as any).lock('landscape').catch(() => {});
        }
      } catch {}
    };

    tryLockLandscape();

    return () => {
      window.removeEventListener('resize', checkOrientationAndDevice);
      window.removeEventListener('orientationchange', checkOrientationAndDevice);
    };
  }, []);

  const handleRequestLandscape = async () => {
    try {
      if (!document.fullscreenElement) {
        await document.documentElement.requestFullscreen().catch(() => {});
      }
      if ('orientation' in screen && 'lock' in (screen.orientation as any)) {
        await (screen.orientation as any).lock('landscape').catch(() => {});
      }
    } catch {}
  };

  if (!isMobileOrTabletPortrait) return null;

  return (
    <div className="fixed inset-0 z-50 bg-[#070B14] text-white flex flex-col items-center justify-center p-6 text-center select-none backdrop-blur-xl">
      <div className="relative mb-6">
        <div className="w-24 h-24 rounded-3xl bg-slate-900 border border-[#CCFF00]/40 flex items-center justify-center shadow-2xl shadow-[#CCFF00]/10">
          <Smartphone className="w-12 h-12 text-[#CCFF00] animate-spin-slow" />
        </div>
        <div className="absolute -bottom-2 -right-2 p-2 rounded-full bg-slate-950 border border-slate-700 text-white">
          <RotateCw className="w-5 h-5 text-amber-400 animate-spin" />
        </div>
      </div>

      <h2 className="text-xl sm:text-2xl font-black uppercase tracking-wider text-white mb-2">
        RUOTA IL DISPOSITIVO IN ORIZZONTALE
      </h2>

      <p className="text-xs sm:text-sm text-slate-300 max-w-sm leading-relaxed mb-6">
        Per garantire la leggibilità a 15 metri di distanza da fondo campo, l'app su smartphone e tablet è progettata esclusivamente in <strong>modalità Orizzontale (Landscape)</strong>.
      </p>

      <button
        onClick={handleRequestLandscape}
        className="px-6 py-3 rounded-2xl bg-[#CCFF00] hover:bg-[#b8e600] text-slate-950 font-black text-xs sm:text-sm uppercase tracking-wider shadow-lg shadow-[#CCFF00]/30 transition-all cursor-pointer active:scale-95"
      >
        Blocca in Orizzontale / Schermo Intero
      </button>
    </div>
  );
};
