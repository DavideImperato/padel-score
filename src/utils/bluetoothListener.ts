// Listener centralizzato per tastiere fisiche, presenter e telecomandi Bluetooth HID
// Funziona su qualsiasi browser (desktop e mobile) senza alcuna traccia audio in background.

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
  private readonly holdDuration = 550; // 550ms per Hold / Pressione prolungata

  private callbacks: BluetoothKeyCallbacks;
  private isListening = false;
  private lastImpulseTime = 0;

  constructor(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public updateCallbacks(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public start() {
    if (this.isListening || typeof window === 'undefined') return;
    this.isListening = true;

    // Ascolto globale degli eventi tastiera (keydown e keyup per rilevazione Hold/Doppio clic)
    window.addEventListener('keydown', this.handleKeyDown, { capture: true });
    window.addEventListener('keyup', this.handleKeyUp, { capture: true });
  }

  public stop() {
    if (!this.isListening || typeof window === 'undefined') return;
    this.isListening = false;

    window.removeEventListener('keydown', this.handleKeyDown, { capture: true });
    window.removeEventListener('keyup', this.handleKeyUp, { capture: true });

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
  // GESTIONE KEYBOARD LISTENER GLOBALE (HID / Presenter / Telecomando Bluetooth)
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

    // 1. TASTI DI UNDO IMMEDIATO: Escape, Backspace, Volume Down
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

    // 2. TASTI IMPULSO STANDARD (Volume Up, Frecce, Spazio, Invio, Next/Prev)
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

      // Avvia timer di Hold per pressione prolungata (>550ms)
      if (!this.holdTimer && !this.isHoldTriggered) {
        this.holdTimer = setTimeout(() => {
          this.isHoldTriggered = true;
          this.triggerUndo();
        }, this.holdDuration);
      }
      return;
    }

    // 3. SCORCIATOIE DIRETTE DA TASTIERA PER TEST / ARBITRO
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
  // LOGICA CENTRALIZZATA DEI CLIC (TIMER DEBOUNCE ~350ms)
  // =========================================================================

  /**
   * 1 Clic Singolo: Se entro 350 ms non arriva un secondo clic -> Squadra A
   * 2 Clic Rapidi: Se arriva un secondo impulso entro 350 ms -> Squadra B
   */
  public registerImpulse() {
    const now = Date.now();
    if (now - this.lastImpulseTime < 50) return;
    this.lastImpulseTime = now;

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
