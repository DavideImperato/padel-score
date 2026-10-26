// Test di verifica per FASE 2A.2: Correzione delle regressioni Bluetooth e Undo
import { BluetoothKeyListener, isStandardControl, isInteractiveElement } from '../utils/bluetoothListener';

async function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Simulatore dell'ambiente window ed EventTarget per test realistici di addEventListener / removeEventListener
class MockDOMWindow {
  private listeners: Record<string, Set<(e: any) => void>> = {};

  public addEventListener(event: string, callback: (e: any) => void) {
    if (!this.listeners[event]) {
      this.listeners[event] = new Set();
    }
    this.listeners[event].add(callback);
  }

  public removeEventListener(event: string, callback: (e: any) => void) {
    if (this.listeners[event]) {
      this.listeners[event].delete(callback);
    }
  }

  public dispatch(event: string, e: any) {
    if (this.listeners[event]) {
      for (const cb of this.listeners[event]) {
        cb(e);
      }
    }
  }

  public getListenerCount(event: string): number {
    return this.listeners[event] ? this.listeners[event].size : 0;
  }
}

// Installiamo window mock nel contesto globale di Node se non presente
const mockWindow = new MockDOMWindow();
(global as any).window = mockWindow;

function createMockEvent(overrides: Partial<KeyboardEvent> = {}): KeyboardEvent {
  return {
    key: 'ArrowUp',
    code: 'ArrowUp',
    repeat: false,
    ctrlKey: false,
    preventDefault: () => {},
    target: null,
    ...overrides,
  } as unknown as KeyboardEvent;
}

function createMockElement(
  tagName: string,
  attributes: Record<string, string> = {},
  isScoreboardTeam: boolean = false
): Element {
  return {
    tagName: tagName.toUpperCase(),
    getAttribute: (attr: string) => attributes[attr] || (isScoreboardTeam && attr === 'data-team-column' ? 'true' : null),
    hasAttribute: (attr: string) => (isScoreboardTeam && attr === 'data-team-column') || Boolean(attributes[attr]),
    closest: (selector: string) => {
      const lowerTag = tagName.toLowerCase();
      if (selector.includes(lowerTag)) return true;
      if (isScoreboardTeam && selector.includes('[data-team-column]')) return true;
      if (attributes['role'] && selector.includes(`[role="${attributes['role']}"]`)) return true;
      return null;
    },
    isContentEditable: false,
  } as unknown as Element;
}

async function runTests() {
  console.log('=== INIZIO TEST FASE 2A.2: REGRESSIONI BLUETOOTH E UNDO ===\n');
  let passedCount = 0;
  let failedCount = 0;

  function assert(condition: boolean, msg: string) {
    if (condition) {
      console.log(`[PASS] ${msg}`);
      passedCount++;
    } else {
      console.error(`[FAIL] ${msg}`);
      failedCount++;
    }
  }

  // -------------------------------------------------------------------------
  // TEST 1 (BUG 1 FIX): Escape -> rilascio -> singolo clic -> punto Squadra A
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1. Premere Escape per Undo
    mockWindow.dispatch('keydown', createMockEvent({ code: 'Escape', key: 'Escape' }));
    assert(undoCount === 1, 'Test 1.1: Escape esegue 1 Undo');

    // 2. Rilasciare Escape
    mockWindow.dispatch('keyup', createMockEvent({ code: 'Escape', key: 'Escape' }));

    // 3. Attendere 75 ms
    await sleep(75);

    // 4. Clic breve con ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 5. Attendere 400 ms
    await sleep(400);
    assert(countA === 1, 'Test 1.2: Il primo clic dopo Escape assegna correttamente 1 punto alla Squadra A (NON perso)');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 2 (BUG 1 FIX): Hold 550ms -> rilascio -> singolo clic -> punto Squadra A
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1. Pressione prolungata ArrowUp (> 550ms)
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(600);
    assert(undoCount === 1, 'Test 2.1: Hold oltre 550ms esegue 1 Undo');

    // 2. Rilascio di ArrowUp
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(75);
    assert(countA === 0, 'Test 2.2: Nessun punto assegnato al rilascio del tasto hold');

    // 3. Nuovo clic breve ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 4. Attendere 400 ms
    await sleep(400);
    assert(countA === 1, 'Test 2.3: Il primo clic dopo Hold-Undo assegna correttamente 1 punto alla Squadra A (NON perso)');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 3 (BUG 1 FIX): Hold -> rilascio -> doppio clic -> punto Squadra B
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let countB = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => countB++,
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1. Hold oltre 550ms
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(600);
    assert(undoCount === 1, 'Test 3.1: Hold esegue 1 Undo');
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(75);

    // 2. Doppio clic entro 350ms
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(80);
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    assert(countB === 1, 'Test 3.2: Doppio clic dopo Hold assegna subito 1 punto alla Squadra B');
    await sleep(400);
    assert(countA === 0 && countB === 1, 'Test 3.3: Nessun punto fantasma alla Squadra A');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 4: Undo durante un hold pendente -> nuovo clic -> punto A
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
    });
    listener.start();

    // Pressione ArrowUp (100ms)
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(100);

    // Escape esegue Undo e cancella holdTimer
    mockWindow.dispatch('keydown', createMockEvent({ code: 'Escape', key: 'Escape' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'Escape', key: 'Escape' }));
    assert(undoCount === 1, 'Test 4.1: Escape esegue 1 Undo');

    // Rilascio di ArrowUp
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(75);

    // Nuovo clic ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(400);
    assert(countA === 1 && undoCount === 1, 'Test 4.2: Clic successivo a Undo durante hold assegna 1 punto a Squadra A senza secondi Undo');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 5: Due pressioni lunghe distinte -> due Undo
  // -------------------------------------------------------------------------
  {
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => {},
      onTeamB: () => {},
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1° Hold
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(600);
    assert(undoCount === 1, 'Test 5.1: 1° Hold oltre 550ms esegue il primo Undo');
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(100);

    // 2° Hold distinta
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(600);
    assert(undoCount === 2, 'Test 5.2: 2° Hold distinta oltre 550ms esegue il secondo Undo');
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 6 (BUG 2 FIX): Apertura e chiusura menu durante debounce -> nessun punto
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let isMenuOpen = false;

    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
      isBlocked: () => isMenuOpen,
    });
    listener.start();

    // 1. Clic breve (avvia debounce 350ms)
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 2. Dopo 100ms si apre il menu
    await sleep(100);
    isMenuOpen = true;
    listener.updateCallbacks({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
      isBlocked: () => isMenuOpen,
    });

    // 3. Dopo altri 100ms si chiude il menu
    await sleep(100);
    isMenuOpen = false;
    listener.updateCallbacks({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
      isBlocked: () => isMenuOpen,
    });

    // 4. Attendere fino a 500ms totali (ben oltre la scadenza dei 350ms originali)
    await sleep(300);
    assert(countA === 0, 'Test 6: L’apertura del menu durante debounce ha cancellato l’impulso: NESSUN punto assegnato!');

    // 5. Clic successivo dopo chiusura menu deve funzionare normalmente
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(400);
    assert(countA === 1, 'Test 6.2: Nuovo clic dopo chiusura menu assegna regolarmente 1 punto');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 7 (BUG 2 FIX): Apertura menu durante keydown -> nessun punto
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let isMenuOpen = false;

    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
      isBlocked: () => isMenuOpen,
    });
    listener.start();

    // Keydown ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(50);

    // Menu si apre durante la pressione
    isMenuOpen = true;
    listener.updateCallbacks({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
      isBlocked: () => isMenuOpen,
    });

    // Menu si chiude
    await sleep(50);
    isMenuOpen = false;
    listener.updateCallbacks({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
      isBlocked: () => isMenuOpen,
    });

    // Rilascio di ArrowUp
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(400);
    assert(countA === 0, 'Test 7: Rilascio di tasto premuto prima dell’apertura menu non genera punti');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 8 (BUG 3 FIX): Comandi su elementi interattivi (pulsanti normali) -> nessuna azione involontaria
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => {},
    });
    listener.start();

    // Creazione mock button normale (es. bottone Pausa o Annulla)
    const mockButton = createMockElement('button');

    // ArrowUp su button focalizzato
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp', target: mockButton }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp', target: mockButton }));
    await sleep(400);
    assert(countA === 0, 'Test 8.1: ArrowUp su <button> focalizzato NON assegna punti (nessuna interferenza)');

    // ArrowDown su button focalizzato
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown', target: mockButton }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown', target: mockButton }));
    await sleep(400);
    assert(countA === 0, 'Test 8.2: ArrowDown su <button> focalizzato NON assegna punti');

    // Tasto A su select focalizzata
    const mockSelect = createMockElement('select');
    mockWindow.dispatch('keydown', createMockEvent({ code: 'KeyA', key: 'a', target: mockSelect }));
    assert(countA === 0, 'Test 8.3: Tasto A su <select> focalizzata NON assegna punti');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 9 (BUG 3 VERIFICA): Telecomando sul tabellone (TeamColumn o Body) -> comandi funzionanti
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let countB = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => countB++,
      onUndo: () => {},
    });
    listener.start();

    // Simulazione telecomando con focus sulla colonna squadra del tabellone
    const mockTeamColumn = createMockElement('div', { role: 'button' }, true);

    // Singolo clic con ArrowUp su superficie tabellone
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp', target: mockTeamColumn }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp', target: mockTeamColumn }));
    await sleep(400);
    assert(countA === 1, 'Test 9.1: ArrowUp su tabellone attivo assegna punto a Squadra A (telecomando FUNZIONANTE)');

    // Telecomando con tasto AudioVolumeUp su body
    mockWindow.dispatch('keydown', createMockEvent({ code: 'AudioVolumeUp', key: 'AudioVolumeUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'AudioVolumeUp', key: 'AudioVolumeUp' }));
    await sleep(80);
    mockWindow.dispatch('keydown', createMockEvent({ code: 'AudioVolumeUp', key: 'AudioVolumeUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'AudioVolumeUp', key: 'AudioVolumeUp' }));
    assert(countB === 1, 'Test 9.2: Doppio impulso VolumeUp telecomando assegna punto a Squadra B');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 10: Verifica Stop & Start con registrazione/rimozione listener reali
  // -------------------------------------------------------------------------
  {
    const listener = new BluetoothKeyListener({
      onTeamA: () => {},
      onTeamB: () => {},
      onUndo: () => {},
    });

    assert(mockWindow.getListenerCount('keydown') === 0, 'Test 10.1: Nessun listener prima di start()');
    listener.start();
    assert(mockWindow.getListenerCount('keydown') === 1, 'Test 10.2: 1 listener registrato dopo start()');
    listener.stop();
    assert(mockWindow.getListenerCount('keydown') === 0, 'Test 10.3: Listener correttamente rimosso dopo stop()');
  }

  // -------------------------------------------------------------------------
  // TEST 11 (FASE 2A.3 - 1): ArrowUp mantenuto premuto con keyup estraneo di ArrowDown: un solo Undo
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let countB = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => countB++,
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1. Premere e mantenere ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 2. Dopo 70 ms ricevere il rilascio di ArrowDown (senza precedente keydown di ArrowDown)
    await sleep(70);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));

    // 3. Continuare a mantenere ArrowUp per oltre 550 ms totali
    await sleep(550);
    assert(undoCount === 1, 'Test 11.1: Hold oltre 550ms esegue 1 solo Undo nonostante keyup estraneo');

    // 4. Rilasciare ArrowUp
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(400);

    assert(countA === 0, 'Test 11.2: Nessun punto a Squadra A dopo il rilascio di ArrowUp');
    assert(countB === 0, 'Test 11.3: Nessun punto a Squadra B');
    assert(undoCount === 1, 'Test 11.4: Esattamente 1 solo Undo registrato');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 12 (FASE 2A.3 - 2): Due tasti premuti contemporaneamente, rilasciati in ordine diverso
  // -------------------------------------------------------------------------
  {
    // Scenario 2A: Due tasti premuti assieme (clic breve), rilasciati nell'ordine KeyA poi KeyB
    {
      let countA = 0;
      let countB = 0;
      const listener = new BluetoothKeyListener({
        onTeamA: () => countA++,
        onTeamB: () => countB++,
        onUndo: () => {},
      });
      listener.start();

      mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
      await sleep(20);
      mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));
      await sleep(60);
      mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
      await sleep(40);
      mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));
      await sleep(400);

      assert(countA === 1, 'Test 12.1: Due tasti premuti assieme (rilascio ordine 1->2) assegnano 1 solo punto a Squadra A');
      assert(countB === 0, 'Test 12.2: Nessuna duplicazione o doppio clic a Squadra B');

      listener.stop();
    }

    // Scenario 2B: Due tasti premuti assieme (clic breve), rilasciati nell'ordine inverso KeyB poi KeyA
    {
      let countA = 0;
      let countB = 0;
      const listener = new BluetoothKeyListener({
        onTeamA: () => countA++,
        onTeamB: () => countB++,
        onUndo: () => {},
      });
      listener.start();

      mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
      await sleep(20);
      mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));
      await sleep(60);
      mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));
      await sleep(40);
      mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
      await sleep(400);

      assert(countA === 1, 'Test 12.3: Due tasti premuti assieme (rilascio ordine inverso 2->1) assegnano 1 solo punto a Squadra A');
      assert(countB === 0, 'Test 12.4: Nessuna duplicazione a Squadra B');

      listener.stop();
    }

    // Scenario 2C: Due tasti premuti assieme e mantenuti oltre 550ms, rilasciati in ordine diverso
    {
      let countA = 0;
      let countB = 0;
      let undoCount = 0;
      const listener = new BluetoothKeyListener({
        onTeamA: () => countA++,
        onTeamB: () => countB++,
        onUndo: () => undoCount++,
      });
      listener.start();

      mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
      await sleep(20);
      mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));
      await sleep(600);
      assert(undoCount === 1, 'Test 12.5: Due tasti mantenuti >550ms generano un solo Undo');

      mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));
      await sleep(30);
      mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
      await sleep(400);

      assert(countA === 0, 'Test 12.6: Rilascio di tasti contemporanei dopo Hold non genera punti a Squadra A');
      assert(countB === 0, 'Test 12.7: Nessun punto a Squadra B');
      assert(undoCount === 1, 'Test 12.8: Un solo Undo totale');

      listener.stop();
    }
  }

  // -------------------------------------------------------------------------
  // TEST 13 (FASE 2A.3 - 3): Keyup senza keydown corrispondente durante una pressione lunga
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let countB = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => countB++,
      onUndo: () => undoCount++,
    });
    listener.start();

    // Pressione prolungata di ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // Sequenza di keyup spuri durante la pressione
    await sleep(80);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'PageDown', key: 'PageDown' }));
    await sleep(80);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'Space', key: ' ' }));
    await sleep(80);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowDown', key: 'ArrowDown' }));

    // Attesa scadenza 550ms complessivi (80*3 = 240ms già trascorsi, attendiamo altri 350ms)
    await sleep(350);
    assert(undoCount === 1, 'Test 13.1: Multipli keyup spuri non interrompono l\'Hold -> 1 Undo eseguito');

    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(400);
    assert(countA === 0, 'Test 13.2: Nessun punto dopo rilascio per ArrowUp');
    assert(countB === 0, 'Test 13.3: Nessun punto dopo rilascio per tasti spuri');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 14 (FASE 2A.3 - 4): Undo seguito da nuovo singolo clic valido
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1. Hold oltre 550ms per Undo
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(600);
    assert(undoCount === 1, 'Test 14.1: Hold genera 1 Undo');

    // 2. Rilascio del tasto hold
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(75);

    // 3. Nuovo singolo clic valido (down -> up)
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(30);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 4. Attesa finestra 350ms
    await sleep(400);
    assert(countA === 1, 'Test 14.2: Nuovo singolo clic valido dopo Undo assegna esattamente 1 punto a Squadra A');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 15 (FASE 2A.3 - 5): Undo seguito da nuovo doppio clic valido
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let countB = 0;
    let undoCount = 0;
    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => countB++,
      onUndo: () => undoCount++,
    });
    listener.start();

    // 1. Undo via Escape
    mockWindow.dispatch('keydown', createMockEvent({ code: 'Escape', key: 'Escape' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'Escape', key: 'Escape' }));
    assert(undoCount === 1, 'Test 15.1: Escape genera 1 Undo');

    await sleep(75);

    // 2. Nuovo doppio clic valido entro 350ms
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(30);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    await sleep(80);
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(30);
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    await sleep(400);
    assert(countB === 1, 'Test 15.2: Nuovo doppio clic valido dopo Undo assegna esattamente 1 punto a Squadra B');
    assert(countA === 0, 'Test 15.3: Squadra A non riceve punti');

    listener.stop();
  }

  // -------------------------------------------------------------------------
  // TEST 16 (FASE 2A.3 - 6): Apertura menu durante una pressione lunga
  // -------------------------------------------------------------------------
  {
    let countA = 0;
    let undoCount = 0;
    let menuOpen = false;

    const listener = new BluetoothKeyListener({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
      isBlocked: () => menuOpen,
    });
    listener.start();

    // 1. Inizio pressione lunga con ArrowUp
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 2. Dopo 200 ms (prima della soglia di 550 ms), apertura del menu
    await sleep(200);
    menuOpen = true;
    listener.updateCallbacks({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
      isBlocked: () => menuOpen,
    });

    // 3. Trascorsi altri 400 ms (totale 600 ms, oltre i 550 ms)
    await sleep(400);
    assert(undoCount === 0, 'Test 16.1: Nessun Undo eseguito perché il menu è stato aperto durante la pressione');

    // 4. Rilascio di ArrowUp mentre il menu è aperto o durante chiusura
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));

    // 5. Chiusura del menu
    await sleep(100);
    menuOpen = false;
    listener.updateCallbacks({
      onTeamA: () => countA++,
      onTeamB: () => {},
      onUndo: () => undoCount++,
      isBlocked: () => menuOpen,
    });

    // Attesa scadenza debounce
    await sleep(400);
    assert(countA === 0, 'Test 16.2: Nessun punto fantasma assegnato dopo chiusura menu');

    // 6. Un nuovo clic valido dopo la chiusura del menu funziona normalmente
    mockWindow.dispatch('keydown', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    mockWindow.dispatch('keyup', createMockEvent({ code: 'ArrowUp', key: 'ArrowUp' }));
    await sleep(400);
    assert(countA === 1, 'Test 16.3: Nuovo clic dopo chiusura menu assegna regolarmente 1 punto a Squadra A');

    listener.stop();
  }

  console.log(`\n=================================================`);
  console.log(`RIEPILOGO TEST: ${passedCount} PASSATI, ${failedCount} FALLITI`);
  console.log(`=================================================`);

  if (failedCount > 0) {
    process.exit(1);
  }
}

runTests();
