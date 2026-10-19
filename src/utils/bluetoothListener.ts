// Listener centralizzato per telecomandi selfie Bluetooth, controller HID e MediaSession API
// Compatibile con browser mobile (iOS/Safari e Android/Chrome) e piattaforme desktop.

export interface BluetoothKeyCallbacks {
  onTeamA: () => void;
  onTeamB: () => void;
  onUndo: () => void;
  onLog?: (message: string, type: 'up1' | 'up2' | 'down' | 'other') => void;
  onFeedback?: (action: 'teamA' | 'teamB' | 'undo', label: string) => void;
}

export class BluetoothKeyListener {
  private clickCount = 0;
  private debounceTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly debounceWindow = 350; // 350ms come da specifica utente

  private holdTimer: ReturnType<typeof setTimeout> | null = null;
  private isHoldTriggered = false;
  private readonly holdDuration = 600; // 600ms per Hold / Pressione prolungata

  private callbacks: BluetoothKeyCallbacks;
  private isListening = false;
  private isAudioUnlocked = false;
  private silentAudio: HTMLAudioElement | null = null;

  constructor(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public updateCallbacks(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public start() {
    if (this.isListening || typeof window === 'undefined') return;
    this.isListening = true;

    // 1. Sblocco audio in background per attivazione MediaSession API su mobile (iOS/Android)
    this.setupSilentAudioAndMediaSession();

    // 2. Ascolto globale degli eventi tastiera (keydown e keyup per rilevazione Hold)
    window.addEventListener('keydown', this.handleKeyDown, { capture: true });
    window.addEventListener('keyup', this.handleKeyUp, { capture: true });

    // 3. Ascolto del custom event dal bridge JS se presente
    window.addEventListener('padel-remote-signal', this.handleCustomSignal as EventListener);
  }

  public stop() {
    if (!this.isListening || typeof window === 'undefined') return;
    this.isListening = false;

    window.removeEventListener('keydown', this.handleKeyDown, { capture: true });
    window.removeEventListener('keyup', this.handleKeyUp, { capture: true });
    window.removeEventListener('padel-remote-signal', this.handleCustomSignal as EventListener);

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }
    if (this.holdTimer) {
      clearTimeout(this.holdTimer);
      this.holdTimer = null;
    }
  }

  // =========================================================================
  // 1. SBLOCCO AUDIO BROWSER & MEDIASESSION API (Mobile Web iOS/Safari & Android)
  // =========================================================================
  private setupSilentAudioAndMediaSession() {
    if (typeof window === 'undefined') return;

    // Base64 silent audio WAV track (1 secondo in loop)
    const SILENT_WAV =
      'data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YRAAAAAAAAAAAAAAAAAAAAAA';

    const unlockOnGesture = () => {
      if (this.isAudioUnlocked) return;

      try {
        if (!this.silentAudio) {
          this.silentAudio = new Audio(SILENT_WAV);
          this.silentAudio.loop = true;
          this.silentAudio.volume = 0.01;
        }

        const promise = this.silentAudio.play();
        if (promise !== undefined) {
          promise
            .then(() => {
              this.isAudioUnlocked = true;
              this.initMediaSession();
              this.callbacks.onLog?.('MediaSession sbloccata con traccia audio background', 'other');
            })
            .catch(() => {});
        }
      } catch (e) {
        console.warn('Errore unlock MediaSession:', e);
      }
    };

    window.addEventListener('click', unlockOnGesture, { passive: true, once: true });
    window.addEventListener('touchstart', unlockOnGesture, { passive: true, once: true });
    window.addEventListener('pointerdown', unlockOnGesture, { passive: true, once: true });
    window.addEventListener('keydown', unlockOnGesture, { passive: true, once: true });
  }

  private initMediaSession() {
    if (typeof window === 'undefined' || !('mediaSession' in navigator)) return;

    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: 'Padel ScoreBot',
        artist: 'Telecomando Bluetooth Attivo',
        album: 'Segnapunti Padel',
      });

      const handleMediaAction = (actionName: string) => {
        this.callbacks.onLog?.(`MediaSession pulsante: ${actionName}`, 'up1');
        this.registerImpulse();
      };

      const actions: MediaSessionAction[] = [
        'play',
        'pause',
        'nexttrack',
        'previoustrack',
        'stop',
        'seekbackward',
        'seekforward',
      ];

      actions.forEach((act) => {
        try {
          navigator.mediaSession.setActionHandler(act, () => {
            handleMediaAction(act);
          });
        } catch (_) {}
      });
    } catch (e) {
      console.warn('MediaSession initialization error:', e);
    }
  }

  private handleCustomSignal = (e: CustomEvent) => {
    const action = e.detail?.action;
    if (action === 'undo' || action === 'hold') {
      this.triggerUndo();
    } else {
      this.registerImpulse();
    }
  };

  // =========================================================================
  // 2. KEYBOARD LISTENER GLOBALE (HID / Presenter / Controller)
  // =========================================================================
  private handleKeyDown = (e: KeyboardEvent) => {
    // Ignora gli input se l'utente sta digitando in un campo testo
    const activeEl = document.activeElement;
    if (
      activeEl &&
      (activeEl.tagName === 'INPUT' ||
        activeEl.tagName === 'TEXTAREA' ||
        (activeEl as HTMLElement).isContentEditable)
    ) {
      return;
    }

    const key = e.key;
    const code = e.code;

    // 1. Tasti di UNDO immediato: Escape, Backspace, Volume Down
    if (
      key === 'Escape' ||
      code === 'Escape' ||
      key === 'Backspace' ||
      code === 'Backspace' ||
      key === 'AudioVolumeDown' ||
      code === 'AudioVolumeDown' ||
      key === 'VolumeDown'
    ) {
      e.preventDefault();
      this.triggerUndo();
      return;
    }

    // 2. Tasti impulso standard (Volume Up, Frecce, Spazio, Invio, Next/Prev)
    const isImpulse =
      key === 'AudioVolumeUp' ||
      code === 'AudioVolumeUp' ||
      key === 'VolumeUp' ||
      key === 'ArrowUp' ||
      code === 'ArrowUp' ||
      key === 'ArrowDown' ||
      code === 'ArrowDown' ||
      key === ' ' ||
      code === 'Space' ||
      key === 'Enter' ||
      code === 'Enter' ||
      key === 'PageUp' ||
      key === 'PageDown' ||
      key === 'MediaTrackNext' ||
      key === 'MediaTrackPrevious';

    if (isImpulse) {
      e.preventDefault();

      if (e.repeat) {
        // Se il tasto viene mantenuto premuto ripetutamente -> Hold = Undo
        if (!this.isHoldTriggered) {
          if (this.holdTimer) clearTimeout(this.holdTimer);
          this.isHoldTriggered = true;
          this.triggerUndo();
        }
        return;
      }

      // Avvia timer di Hold per pressione prolungata (>600ms)
      if (!this.holdTimer && !this.isHoldTriggered) {
        this.holdTimer = setTimeout(() => {
          this.isHoldTriggered = true;
          this.triggerUndo();
        }, this.holdDuration);
      }
      return;
    }

    // 3. Scorciatoie dirette per arbitro/test da tastiera
    if (key === 'a' || key === 'A' || key === '1') {
      this.callbacks.onLog?.('Tasto A / 1 -> +1 Squadra A', 'up1');
      this.callbacks.onFeedback?.('teamA', '+1 SQUADRA A');
      this.callbacks.onTeamA();
      return;
    }
    if (key === 'b' || key === 'B' || key === '2') {
      this.callbacks.onLog?.('Tasto B / 2 -> +1 Squadra B', 'up2');
      this.callbacks.onFeedback?.('teamB', '+1 SQUADRA B');
      this.callbacks.onTeamB();
      return;
    }
    if (key === 'u' || key === 'U' || (e.ctrlKey && key === 'z')) {
      this.triggerUndo();
      return;
    }
  };

  private handleKeyUp = (e: KeyboardEvent) => {
    // Cancella timer hold se rilasciato prima
    if (this.holdTimer) {
      clearTimeout(this.holdTimer);
      this.holdTimer = null;
    }

    if (this.isHoldTriggered) {
      this.isHoldTriggered = false;
      return;
    }

    const key = e.key;
    const code = e.code;
    const isImpulse =
      key === 'AudioVolumeUp' ||
      code === 'AudioVolumeUp' ||
      key === 'VolumeUp' ||
      key === 'ArrowUp' ||
      code === 'ArrowUp' ||
      key === 'ArrowDown' ||
      code === 'ArrowDown' ||
      key === ' ' ||
      code === 'Space' ||
      key === 'Enter' ||
      code === 'Enter' ||
      key === 'PageUp' ||
      key === 'PageDown' ||
      key === 'MediaTrackNext' ||
      key === 'MediaTrackPrevious';

    if (isImpulse) {
      e.preventDefault();
      this.registerImpulse();
    }
  };

  // =========================================================================
  // 3. LOGICA ESATTA DEI CLIC (TIMER DEBOUNCE 350ms)
  // =========================================================================

  /**
   * 1 Clic Singolo: Se entro 350 ms non arriva un secondo clic -> Squadra A
   * 2 Clic Rapidi: Se arriva un secondo impulso entro 350 ms -> Squadra B
   */
  public registerImpulse() {
    this.clickCount++;

    if (this.clickCount === 1) {
      // 1° clic: avvia timer di debounce di 350ms
      this.callbacks.onLog?.('1° Clic rilevato (attesa 350ms)...', 'up1');

      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => {
        if (this.clickCount === 1) {
          this.callbacks.onLog?.('1 Clic Singolo confermato (<350ms) -> +1 SQUADRA A', 'up1');
          this.callbacks.onFeedback?.('teamA', '+1 SQUADRA A');
          this.callbacks.onTeamA();
        }
        this.clickCount = 0;
        this.debounceTimer = null;
      }, this.debounceWindow);
    } else if (this.clickCount >= 2) {
      // 2° clic arrivato prima della scadenza dei 350ms: annulla singolo e assegna Squadra B
      if (this.debounceTimer) {
        clearTimeout(this.debounceTimer);
        this.debounceTimer = null;
      }
      this.clickCount = 0;
      this.callbacks.onLog?.('2 Clic Rapidi DOPPIO CLIC (<350ms) -> +1 SQUADRA B', 'up2');
      this.callbacks.onFeedback?.('teamB', '+1 SQUADRA B');
      this.callbacks.onTeamB();
    }
  }

  /**
   * Pressione Prolungata / Hold (oppure Escape, Backspace, Volume Down) -> UNDO
   */
  public triggerUndo() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }
    this.clickCount = 0;
    this.callbacks.onLog?.('Pressione Prolungata / Hold / Escape -> UNDO', 'down');
    this.callbacks.onFeedback?.('undo', 'PUNTO ANNULLATO (UNDO)');
    this.callbacks.onUndo();
  }
}
