import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'remote_bridge/remote_bridge.dart';

/// Servizio centralizzato per la gestione dei comandi del telecomando selfie Bluetooth,
/// controller HID, tastiere fisiche e MediaSession API (per Web mobile iOS/Safari e Android/Chrome).
class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;
  final void Function(String actionType, String label)? onFeedback;

  /// FocusNode associabile al widget KeyboardListener
  final FocusNode focusNode = FocusNode();

  // Gestione Debounce per 1 Clic vs 2 Clic entro 350ms
  Timer? _debounceTimer;
  int _clickCount = 0;
  static const Duration debounceDuration = Duration(milliseconds: 350);

  // Gestione Pressione Prolungata (Hold) per Undo immediato
  Timer? _holdTimer;
  bool _isHoldTriggered = false;
  static const Duration holdDuration = Duration(milliseconds: 550);

  // Cache per evitare doppio evento tra HardwareKeyboard.addHandler e KeyboardListener
  int _lastEventTimestamp = 0;
  LogicalKeyboardKey? _lastKeyHandled;

  BluetoothKeyService({
    required this.onTeamAPoint,
    required this.onTeamBPoint,
    required this.onUndo,
    this.onFeedback,
  });

  /// Inizializza il bridge Web (MediaSession e background audio) e l'ascolto tastiera globale
  void init() {
    // 1. Collega il bridge Web per MediaSession API e background audio
    RemoteBridge.instance.init(onSignal: _handleRemoteSignal);

    // 2. Registra listener globale su HardwareKeyboard (cattura tasti anche senza focus esplicito)
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareEvent);

    // 3. Richiede il focus al widget KeyboardListener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    });
  }

  /// Gestisce i segnali ricevuti dalla MediaSession API del browser o dall'evento JS
  void _handleRemoteSignal(String action) {
    debugPrint('[BluetoothKeyService] Segnale remoto ricevuto: $action');
    RemoteBridge.instance.unlockAudio();

    if (action == 'undo' || action == 'hold') {
      _triggerUndo();
    } else {
      // Qualsiasi impulso di clic (play, pause, nexttrack, previoustrack, stop, click)
      _registerClick();
    }
  }

  /// Handler globale registrato con HardwareKeyboard.instance.addHandler
  bool _handleGlobalHardwareEvent(KeyEvent event) {
    final result = _processKeyEvent(event);
    return result == KeyEventResult.handled;
  }

  /// Handler per il widget KeyboardListener
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    return _processKeyEvent(event);
  }

  /// Elaborazione unificata degli eventi tastiera con deduplicazione
  KeyEventResult _processKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Deduplica se lo stesso evento viene processato da entrambi i listener entro 15ms
    if (_lastKeyHandled == key && (now - _lastEventTimestamp) < 15) {
      return KeyEventResult.handled;
    }
    _lastKeyHandled = key;
    _lastEventTimestamp = now;

    // Sblocca eventuale audio su Web
    RemoteBridge.instance.unlockAudio();

    // 1. TASTI DI UNDO IMMEDIATO: Escape, Backspace, Volume Down
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      if (event is KeyDownEvent) {
        _triggerUndo();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // 2. TASTI IMPULSO STANDARD (Telecomando selfie, Volume Up, Presenter, Frecce, Spazio, Invio, Next/Prev)
    final bool isImpulseKey =
        key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaPlayPause;

    if (isImpulseKey) {
      if (event is KeyDownEvent) {
        // Avvia il timer di Hold (>550ms) per attivare l'UNDO
        _holdTimer?.cancel();
        _isHoldTriggered = false;
        _holdTimer = Timer(holdDuration, () {
          _isHoldTriggered = true;
          _triggerUndo();
        });
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        // Tasto rilasciato prima del completamento dell'Hold -> registra impulso clic singolo/doppio
        _holdTimer?.cancel();
        if (_isHoldTriggered) {
          _isHoldTriggered = false;
        } else {
          _registerClick();
        }
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        // Pressione continuata prolungata rilevata dall'OS -> attiva subito UNDO
        if (!_isHoldTriggered) {
          _holdTimer?.cancel();
          _isHoldTriggered = true;
          _triggerUndo();
        }
        return KeyEventResult.handled;
      }
    }

    // 3. SCORCIATOIE RAPIDE DIRETTE DA TASTIERA (Arbitro / Test da banco)
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.digit1) {
        onFeedback?.('teamA', '+1 SQUADRA A');
        onTeamAPoint();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.digit2) {
        onFeedback?.('teamB', '+1 SQUADRA B');
        onTeamBPoint();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyU ||
          key == LogicalKeyboardKey.keyZ) {
        _triggerUndo();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// LOGICA ESATTA DEI CLIC (TIMER DEBOUNCE 350ms):
  /// - 1 Clic Singolo: Se entro 350ms non arriva un secondo clic -> SQUADRA A.
  /// - 2 Clic Rapidi (Doppio Clic): Se arriva un secondo impulso entro 350ms -> Annulla il singolo e assegna SQUADRA B.
  void _registerClick() {
    _clickCount++;

    if (_clickCount == 1) {
      // 1° Clic: avvia timer debounce da 350ms
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () {
        if (_clickCount == 1) {
          debugPrint('[BluetoothKeyService] Clic Singolo (<350ms) confermato -> SQUADRA A');
          onFeedback?.('teamA', '+1 SQUADRA A');
          onTeamAPoint();
        }
        _clickCount = 0;
        _debounceTimer = null;
      });
    } else if (_clickCount >= 2) {
      // 2° Clic arrivato prima della scadenza dei 350ms: annulla singolo e assegna SQUADRA B
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _clickCount = 0;
      debugPrint('[BluetoothKeyService] Doppio Clic (<350ms) confermato -> SQUADRA B');
      onFeedback?.('teamB', '+1 SQUADRA B');
      onTeamBPoint();
    }
  }

  /// Pressione Prolungata (Hold) o tasto Escape/Backspace/Volume Down -> UNDO
  void _triggerUndo() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _clickCount = 0;
    debugPrint('[BluetoothKeyService] Hold / Escape / Undo rilevato -> UNDO');
    onFeedback?.('undo', 'PUNTO ANNULLATO (UNDO)');
    onUndo();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _holdTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareEvent);
    RemoteBridge.instance.dispose();
    focusNode.dispose();
  }
}
