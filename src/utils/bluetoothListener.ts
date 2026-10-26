// Listener centralizzato per tastiere fisiche, presenter e telecomandi Bluetooth HID
// Funziona su qualsiasi browser (desktop e mobile) senza alcuna traccia audio in background.

export interface BluetoothKeyCallbacks {
  onTeamA: () => void;
  onTeamB: () => void;
  onUndo: () => void;
  isBlocked?: () => boolean;
  onLog?: (message: string, type: 'up1' | 'up2' | 'down' | 'other') => void;
  onFeedback?: (action: 'teamA' | 'teamB' | 'undo', label: string) => void;
}

export function isTextInput(el: any): boolean {
  if (!el) return false;
  const tagName = typeof el.tagName === 'string' ? el.tagName.toUpperCase() : '';
  if (tagName === 'INPUT' || tagName === 'TEXTAREA') return true;
  if (el.isContentEditable) return true;
  return false;
}

/**
 * Riconosce i normali controlli interattivi (pulsanti, link, menu, input)
 * escludendo esplicitamente le superfici del tabellone di gioco (TeamColumn)
 * per permettere al telecomando Bluetooth di funzionare liberamente.
 */
export function isStandardControl(target: EventTarget | null): boolean {
  if (!target) return false;
  if (typeof Element !== 'undefined' && !(target instanceof Element)) return false;
  if (typeof document !== 'undefined' && (target === document.body || target === document.documentElement)) {
    return false;
  }

  const el = target as any;

  // Se l'elemento appartiene alla colonna squadra del tabellone, non è un controllo normale da escludere
  if (typeof el.hasAttribute === 'function' && el.hasAttribute('data-team-column')) {
    return false;
  }
  if (typeof el.closest === 'function' && el.closest('[data-team-column]')) {
    return false;
  }

  const tagName = typeof el.tagName === 'string' ? el.tagName.toUpperCase() : '';
  if (
    tagName === 'BUTTON' ||
    tagName === 'A' ||
    tagName === 'INPUT' ||
    tagName === 'TEXTAREA' ||
    tagName === 'SELECT'
  ) {
    return true;
  }
  if (el.isContentEditable) return true;

  const role = typeof el.getAttribute === 'function' ? el.getAttribute('role') : null;
  if (
    role === 'menuitem' ||
    role === 'tab' ||
    role === 'option' ||
    role === 'switch' ||
    role === 'combobox' ||
    role === 'listbox'
  ) {
    return true;
  }

  if (
    typeof el.closest === 'function' &&
    el.closest(
      'button, a, input, textarea, select, [role="menuitem"], [role="tab"], [role="option"], [role="combobox"], [role="listbox"]'
    )
  ) {
    return true;
  }

  return false;
}

export function isInteractiveElement(target: EventTarget | null): boolean {
  if (!target) return false;
  if (typeof Element !== 'undefined' && !(target instanceof Element)) return false;
  if (typeof document !== 'undefined' && (target === document.body || target === document.documentElement)) {
    return false;
  }

  const el = target as any;
  const tagName = typeof el.tagName === 'string' ? el.tagName.toUpperCase() : '';
  if (
    tagName === 'INPUT' ||
    tagName === 'TEXTAREA' ||
    tagName === 'SELECT' ||
    tagName === 'BUTTON' ||
    tagName === 'A'
  ) {
    return true;
  }
  if (el.isContentEditable) return true;

  const role = typeof el.getAttribute === 'function' ? el.getAttribute('role') : null;
  if (
    role === 'button' ||
    role === 'link' ||
    role === 'menuitem' ||
    role === 'tab' ||
    role === 'option' ||
    role === 'switch' ||
    role === 'checkbox' ||
    role === 'combobox' ||
    role === 'listbox'
  ) {
    return true;
  }

  if (
    typeof el.closest === 'function' &&
    el.closest(
      'button, [role="button"], a, input, textarea, select, [role="combobox"], [role="listbox"], [role="menuitem"]'
    )
  ) {
    return true;
  }

  return false;
}

export class BluetoothKeyListener {
  private clickCount = 0;
  private debounceTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly debounceWindow = 350; // 350ms come da specifica utente

  private holdTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly holdDuration = 550; // 550ms per Hold / Pressione prolungata

  private isUndoKeyPressed = false;
  private lastImpulseTime = 0;
  private lastUndoTime = 0;

  // Tracciamento dei tasti con keydown attivo accettato dal listener
  private activeImpulseKeys = new Set<string>();

  // Tasto che ha avviato la pressione lunga (Hold) corrente
  private heldKeyId: string | null = null;

  // Tasti la cui release deve essere ignorata (es. dopo che hanno generato Undo o durante blocco)
  private suppressedKeysOnRelease = new Set<string>();

  private callbacks: BluetoothKeyCallbacks;
  private isListening = false;

  constructor(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
  }

  public updateCallbacks(callbacks: BluetoothKeyCallbacks) {
    this.callbacks = callbacks;
    if (this.isBlocked()) {
      this.cancelPendingImpulses();
    }
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

    this.cancelPendingImpulses();
    this.suppressedKeysOnRelease.clear();
    this.isUndoKeyPressed = false;
  }

  public isBlocked(): boolean {
    if (this.callbacks.isBlocked?.()) {
      return true;
    }
    if (typeof document !== 'undefined') {
      const openDialog = document.querySelector(
        '[role="dialog"], [aria-modal="true"], dialog[open]'
      );
      if (openDialog) return true;
    }
    return false;
  }

  /**
   * Annulla qualsiasi impulso pendente, timer di hold o conteggio doppio clic.
   * Chiamato ogni volta che l'app entra in uno stato bloccato (es. apertura menu).
   */
  public cancelPendingImpulses() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }
    if (this.holdTimer) {
      clearTimeout(this.holdTimer);
      this.holdTimer = null;
    }
    this.heldKeyId = null;
    this.clickCount = 0;

    // Se c'erano tasti premuti durante il blocco, sopprimi il loro rilascio successivo
    for (const key of this.activeImpulseKeys) {
      this.suppressedKeysOnRelease.add(key);
    }
    this.activeImpulseKeys.clear();
  }

  // =========================================================================
  // GESTIONE KEYBOARD LISTENER GLOBALE (HID / Presenter / Telecomando Bluetooth)
  // =========================================================================
  public handleKeyDown = (e: KeyboardEvent) => {
    const target = e.target as Element | null;
    const activeEl = typeof document !== 'undefined' ? (document.activeElement as Element | null) : null;

    // 1. Ignora input se l'utente sta digitando in un campo testo o select
    if (
      isTextInput(target) ||
      isTextInput(activeEl) ||
      target?.tagName === 'SELECT' ||
      activeEl?.tagName === 'SELECT'
    ) {
      return;
    }

    // 2. Se un menu o finestra modale è aperta, annulla impulsi pendenti e ignora
    if (this.isBlocked()) {
      this.cancelPendingImpulses();
      return;
    }

    const key = e.key;
    const code = e.code;
    const keyId = code || key;

    // 3. TASTI DI UNDO IMMEDIATO: Escape, Backspace, Volume Down
    const isDirectUndoKey =
      key === 'Escape' ||
      code === 'Escape' ||
      key === 'Backspace' ||
      code === 'Backspace' ||
      key === 'AudioVolumeDown' ||
      code === 'AudioVolumeDown' ||
      key === 'VolumeDown';

    if (isDirectUndoKey) {
      e.preventDefault();

      // Prevenzione Undo multiplo su tasto tenuto premuto (e.repeat)
      if (e.repeat || this.isUndoKeyPressed) {
        return;
      }

      this.isUndoKeyPressed = true;
      this.triggerUndo();
      return;
    }

    // 4. VERIFICA CONTROLLI STANDARD (pulsanti, link, menu, tab)
    const targetIsControl = isStandardControl(target) || isStandardControl(activeEl);

    // Se il focus è su un controllo standard (es. pulsante "Pausa", "Menu", bottoni modale),
    // non intercettare frecce, invio o spazio per evitare punti involontari
    if (targetIsControl) {
      return;
    }

    // 5. VERIFICA INVIO E SPAZIO SU ELEMENTI CON PROPRIO GESTORE (es. TeamColumn role="button")
    const isEnterOrSpace =
      key === ' ' || code === 'Space' || key === 'Enter' || code === 'Enter';

    if (isEnterOrSpace && (isInteractiveElement(target) || isInteractiveElement(activeEl))) {
      return;
    }

    // 6. TASTI IMPULSO STANDARD (Volume Up, Frecce, Spazio, Invio, Next/Prev)
    const isImpulse =
      isEnterOrSpace ||
      key === 'AudioVolumeUp' ||
      code === 'AudioVolumeUp' ||
      key === 'VolumeUp' ||
      key === 'ArrowUp' ||
      code === 'ArrowUp' ||
      key === 'ArrowDown' ||
      code === 'ArrowDown' ||
      key === 'PageUp' ||
      code === 'PageUp' ||
      key === 'PageDown' ||
      code === 'PageDown' ||
      key === 'MediaTrackNext' ||
      key === 'MediaTrackPrevious';

    if (isImpulse) {
      e.preventDefault();

      // Ignora eventi repeat generati dal sistema operativo mentre il tasto è tenuto premuto
      if (e.repeat) {
        return;
      }

      // Registra questo tasto come attivo
      this.activeImpulseKeys.add(keyId);

      // Nuova pressione fisica: avvia timer di Hold per pressione prolungata (>550ms)
      if (!this.holdTimer) {
        this.heldKeyId = keyId;
        this.holdTimer = setTimeout(() => {
          this.holdTimer = null;
          this.heldKeyId = null;
          // Segna tutti i tasti attivi come soppressi al rilascio per non registrare un clic al keyup
          for (const k of this.activeImpulseKeys) {
            this.suppressedKeysOnRelease.add(k);
          }
          this.activeImpulseKeys.clear();
          this.triggerUndo();
        }, this.holdDuration);
      }
      return;
    }

    // 7. SCORCIATOIE DIRETTE DA TASTIERA (A, B, 1, 2, U, Ctrl+Z)
    // Se il target è un qualsiasi elemento interattivo (incluso TeamColumn), ignora
    if (isInteractiveElement(target) || isInteractiveElement(activeEl)) {
      return;
    }

    if (e.repeat) return;

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
    if (key === 'u' || key === 'U' || (e.ctrlKey && (key === 'z' || key === 'Z'))) {
      if (this.isUndoKeyPressed) return;
      this.isUndoKeyPressed = true;
      this.triggerUndo();
      return;
    }
  };

  public handleKeyUp = (e: KeyboardEvent) => {
    const key = e.key;
    const code = e.code;
    const keyId = code || key;

    // Reset stato tasto Undo fisico
    const isDirectUndoKey =
      key === 'Escape' ||
      code === 'Escape' ||
      key === 'Backspace' ||
      code === 'Backspace' ||
      key === 'AudioVolumeDown' ||
      code === 'AudioVolumeDown' ||
      key === 'VolumeDown' ||
      key === 'u' ||
      key === 'U' ||
      key === 'z' ||
      key === 'Z';

    if (isDirectUndoKey) {
      this.isUndoKeyPressed = false;
      return;
    }

    // Se questo tasto era stato contrassegnato per la soppressione al rilascio (es. dopo un Hold o Undo),
    // ignoralo e ripulisci il flag senza intaccare i clic successivi
    if (this.suppressedKeysOnRelease.has(keyId)) {
      this.suppressedKeysOnRelease.delete(keyId);
      return;
    }

    // Se questo tasto non aveva un keydown attivo accettato dal listener, ignora!
    // FONDAMENTALE: un keyup estraneo (senza keydown) NON deve cancellare l'holdTimer di un altro tasto!
    if (!this.activeImpulseKeys.has(keyId)) {
      return;
    }
    this.activeImpulseKeys.delete(keyId);

    // Se l'app è in stato bloccato (es. modal aperta), ripulisci e non generare punti
    if (this.isBlocked()) {
      this.cancelPendingImpulses();
      return;
    }

    // Cancella timer hold SOLO se viene rilasciato il tasto specifico che ha avviato l'Hold prima dei 550ms
    if (this.heldKeyId === keyId) {
      if (this.holdTimer) {
        clearTimeout(this.holdTimer);
        this.holdTimer = null;
      }
      this.heldKeyId = null;

      // Se ci sono ancora altri tasti attivi, passa la pressione lunga al prossimo tasto
      if (this.activeImpulseKeys.size > 0) {
        const nextKey = this.activeImpulseKeys.values().next().value;
        if (nextKey) {
          this.heldKeyId = nextKey;
          this.holdTimer = setTimeout(() => {
            this.holdTimer = null;
            this.heldKeyId = null;
            for (const k of this.activeImpulseKeys) {
              this.suppressedKeysOnRelease.add(k);
            }
            this.activeImpulseKeys.clear();
            this.triggerUndo();
          }, this.holdDuration);
        }
      }
    }

    e.preventDefault();

    // Se ci sono ancora altri tasti fisicamente premuti della stessa pressione contemporanea,
    // attendi il rilascio completo prima di registrare l'impulso
    if (this.activeImpulseKeys.size === 0) {
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
    if (this.isBlocked()) {
      this.cancelPendingImpulses();
      return;
    }

    const now = Date.now();
    if (now - this.lastImpulseTime < 50) return;
    this.lastImpulseTime = now;

    this.clickCount++;

    if (this.clickCount === 1) {
      // 1° clic: avvia timer di debounce di 350ms
      this.callbacks.onLog?.('1° Clic rilevato (attesa 350ms)...', 'up1');

      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => {
        if (this.clickCount === 1 && !this.isBlocked()) {
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
      if (!this.isBlocked()) {
        this.callbacks.onLog?.('2 Clic Rapidi DOPPIO CLIC (<350ms) -> +1 SQUADRA B', 'up2');
        this.callbacks.onFeedback?.('teamB', '+1 SQUADRA B');
        this.callbacks.onTeamB();
      }
    }
  }

  /**
   * Pressione Prolungata / Hold (oppure Escape, Backspace, Volume Down) -> UNDO
   * Annulla timer hold, debounce timer e sopprime il rilascio dei tasti correnti
   * SENZA lasciare flag di blocco permanenti per i clic successivi.
   */
  public triggerUndo() {
    if (this.isBlocked()) {
      this.cancelPendingImpulses();
      return;
    }

    const now = Date.now();
    // Filtro antirimbalzo di 50 ms
    if (now - this.lastUndoTime < 50) return;
    this.lastUndoTime = now;

    // Cancella holdTimer pendente
    if (this.holdTimer) {
      clearTimeout(this.holdTimer);
      this.holdTimer = null;
    }
    this.heldKeyId = null;

    // Cancella debounce timer e azzera clickCount
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }
    this.clickCount = 0;

    // Sopprimi il futuro keyup dei tasti che erano premuti durante l'Undo
    for (const key of this.activeImpulseKeys) {
      this.suppressedKeysOnRelease.add(key);
    }
    this.activeImpulseKeys.clear();

    this.callbacks.onLog?.('Pressione Prolungata / Hold / Escape -> UNDO', 'down');
    this.callbacks.onFeedback?.('undo', 'PUNTO ANNULLATO (UNDO)');
    this.callbacks.onUndo();
  }
}
