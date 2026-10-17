export interface BluetoothKeyCallbacks {
  onTeamA: () => void;
  onTeamB: () => void;
  onUndo: () => void;
  onLog?: (message: string, type: 'up1' | 'up2' | 'down' | 'other') => void;
}

export class BluetoothKeyListener {
  private volumeUpClickCount = 0;
  private volumeUpTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly doubleClickWindow = 400; // 400ms as requested
  private callbacks: BluetoothKeyCallbacks;
  private isListening = false;

  constructor(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public updateCallbacks(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public start() {
    if (this.isListening || typeof window === 'undefined') return;
    this.isListening = true;
    window.addEventListener('keydown', this.handleKeyDown, { capture: true });
  }

  public stop() {
    if (!this.isListening || typeof window === 'undefined') return;
    this.isListening = false;
    window.removeEventListener('keydown', this.handleKeyDown, { capture: true });
    if (this.volumeUpTimer) {
      clearTimeout(this.volumeUpTimer);
      this.volumeUpTimer = null;
    }
  }

  private handleKeyDown = (e: KeyboardEvent) => {
    // Ignore key events if the user is typing in a text field
    const activeEl = document.activeElement;
    if (
      activeEl &&
      (activeEl.tagName === 'INPUT' ||
        activeEl.tagName === 'TEXTAREA' ||
        (activeEl as HTMLElement).isContentEditable)
    ) {
      return;
    }

    const code = e.code;
    const key = e.key;

    // 1. VOLUME UP and standard camera shutter / bluetooth selfie clicker triggers
    // Common keys sent by selfie remotes:
    // - AudioVolumeUp / VolumeUp
    // - ArrowUp
    // - MediaTrackNext
    // - KeyX or Enter / Space on some iOS shutters
    const isVolumeUp =
      key === 'AudioVolumeUp' ||
      code === 'AudioVolumeUp' ||
      key === 'VolumeUp' ||
      key === 'ArrowUp' ||
      code === 'ArrowUp' ||
      key === 'MediaTrackNext';

    // 2. VOLUME DOWN (Undo)
    const isVolumeDown =
      key === 'AudioVolumeDown' ||
      code === 'AudioVolumeDown' ||
      key === 'VolumeDown' ||
      key === 'ArrowDown' ||
      code === 'ArrowDown' ||
      key === 'Backspace' ||
      code === 'Backspace' ||
      key === 'MediaTrackPrevious';

    if (isVolumeUp) {
      e.preventDefault();
      this.processVolumeUp();
      return;
    }

    if (isVolumeDown) {
      e.preventDefault();
      this.processVolumeDown();
      return;
    }

    // Direct handy keyboard shortcuts for testing:
    // 'a' or '1' -> Team A
    // 'b' or '2' -> Team B
    // 'u' or 'z' -> Undo
    if (key === 'a' || key === 'A' || key === '1') {
      this.callbacks.onLog?.('Tasto A / 1 -> Punto Squadra A', 'up1');
      this.callbacks.onTeamA();
      return;
    }
    if (key === 'b' || key === 'B' || key === '2') {
      this.callbacks.onLog?.('Tasto B / 2 -> Punto Squadra B', 'up2');
      this.callbacks.onTeamB();
      return;
    }
    if (key === 'u' || key === 'U' || (e.ctrlKey && key === 'z')) {
      this.callbacks.onLog?.('Tasto Undo -> Annulla Punto', 'down');
      this.callbacks.onUndo();
      return;
    }
  };

  private processVolumeUp() {
    this.volumeUpClickCount++;

    if (this.volumeUpClickCount === 1) {
      this.callbacks.onLog?.('Volume Up: 1° click rilevato (attesa 400ms)...', 'up1');

      if (this.volumeUpTimer) clearTimeout(this.volumeUpTimer);
      this.volumeUpTimer = setTimeout(() => {
        if (this.volumeUpClickCount === 1) {
          this.callbacks.onLog?.('Volume Up Singolo confermato -> +1 Squadra A', 'up1');
          this.callbacks.onTeamA();
        }
        this.volumeUpClickCount = 0;
        this.volumeUpTimer = null;
      }, this.doubleClickWindow);
    } else if (this.volumeUpClickCount >= 2) {
      if (this.volumeUpTimer) {
        clearTimeout(this.volumeUpTimer);
        this.volumeUpTimer = null;
      }
      this.volumeUpClickCount = 0;
      this.callbacks.onLog?.('Volume Up DOPPIO CLICK (<400ms) -> +1 Squadra B', 'up2');
      this.callbacks.onTeamB();
    }
  }

  private processVolumeDown() {
    if (this.volumeUpTimer) {
      clearTimeout(this.volumeUpTimer);
      this.volumeUpTimer = null;
    }
    this.volumeUpClickCount = 0;
    this.callbacks.onLog?.('Volume Down -> UNDO (Annulla)', 'down');
    this.callbacks.onUndo();
  }
}
