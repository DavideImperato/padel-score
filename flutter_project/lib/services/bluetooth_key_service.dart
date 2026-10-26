import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'volume/volume_service.dart';

/// Servizio centralizzato per la gestione degli input da:
/// - Tasti volume hardware fisici del dispositivo nativo (iOS / Android)
/// - Telecomandi selfie Bluetooth (impulsi Volume Up / Volume Down)
/// - Tastiere fisiche, presenter e controller Bluetooth HID (Web e Nativo)
///
/// Implementa la logica centralizzata dei clic con timer debounce a 350ms:
/// - 1 Clic singolo -> SQUADRA A
/// - 2 Clic rapidi (Doppio Clic) -> SQUADRA B
/// - Pressione prolungata (Hold) o tasto Undo dedicato (Volume Down, Escape, Backspace) -> UNDO
class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;
  final void Function(String actionType, String label)? onFeedback;

  /// FocusNode associato al widget KeyboardListener
  final FocusNode focusNode = FocusNode();

  // Gestione Debounce per 1 Clic vs 2 Clic entro 350ms
  Timer? _debounceTimer;
  int _clickCount = 0;
  static const Duration debounceDuration = Duration(milliseconds: 350);

  // Gestione Pressione Prolungata (Hold) per Undo
  Timer? _holdTimer;
  bool _isHoldTriggered = false;
  static const Duration holdDuration = Duration(milliseconds: 550);

  // Deduplicazione tra VolumeService nativo e HardwareKeyboard (evita falsi doppi clic entro 50ms)
  int _lastImpulseTimestamp = 0;
  int _lastKeyEventTimestamp = 0;
  LogicalKeyboardKey? _lastHandledKey;

  BluetoothKeyService({
    required this.onTeamAPoint,
    required this.onTeamBPoint,
    required this.onUndo,
    this.onFeedback,
  });

  /// Inizializza l'ascolto su piattaforme native (iOS/Android) e su Web
  void init() {
    // 1. Inizializza il listener per i tasti del volume hardware nativi
    // Su iOS TestFlight e Android APK cattura gli eventi hardware reali
    VolumeService.instance.init(
      onVolumeUp: () {
        debugPrint('[BluetoothKeyService] Hardware Volume UP ricevuto da VolumeService');
        _registerClick();
      },
      onVolumeDown: () {
        debugPrint('[BluetoothKeyService] Hardware Volume DOWN ricevuto da VolumeService -> UNDO');
        _triggerUndo();
      },
    );

    // 2. Registra listener globale su HardwareKeyboard (cattura tasti fisici ovunque nell'app)
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareEvent);

    // 3. Richiede il focus al KeyboardListener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    });
  }

  /// Handler per HardwareKeyboard.instance.addHandler
  bool _handleGlobalHardwareEvent(KeyEvent event) {
    final result = _processKeyEvent(event);
    return result == KeyEventResult.handled;
  }

  /// Handler per il widget KeyboardListener dell'interfaccia
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    return _processKeyEvent(event);
  }

  /// Elaborazione unificata degli eventi tastiera con deduplicazione
  KeyEventResult _processKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Deduplica se lo stesso evento viene processato contemporaneamente da entrambi i listener
    if (_lastHandledKey == key && (now - _lastKeyEventTimestamp) < 15) {
      return KeyEventResult.handled;
    }
    _lastHandledKey = key;
    _lastKeyEventTimestamp = now;

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

    // 2. TASTI IMPULSO STANDARD (Telecomando selfie Bluetooth, Volume Up, Presenter, Frecce, Spazio, Invio)
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
        // Tasto rilasciato prima dell'Hold -> registra impulso clic (singolo o doppio)
        _holdTimer?.cancel();
        if (_isHoldTriggered) {
          _isHoldTriggered = false;
        } else {
          _registerClick();
        }
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        // Pressione continuata prolungata -> attiva subito UNDO
        if (!_isHoldTriggered) {
          _holdTimer?.cancel();
          _isHoldTriggered = true;
          _triggerUndo();
        }
        return KeyEventResult.handled;
      }
    }

    // 3. SCORCIATOIE RAPIDE DA TASTIERA PER TEST / ARBITRO
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.digit1) {
        onFeedback?.call('teamA', '+1 SQUADRA A');
        onTeamAPoint();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.digit2) {
        onFeedback?.call('teamB', '+1 SQUADRA B');
        onTeamBPoint();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyU || key == LogicalKeyboardKey.keyZ) {
        _triggerUndo();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// LOGICA CENTRALIZZATA DEI CLIC (TIMER DEBOUNCE ~350ms):
  /// - 1 Clic singolo: se entro 350ms non arriva un secondo impulso -> Aumenta il punteggio della SQUADRA A.
  /// - 2 Clic rapidi (Doppio Clic): se arriva un secondo impulso entro 350ms -> Annulla il singolo clic e aumenta il punteggio della SQUADRA B.
  void _registerClick() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Filtro antirimbalzo per evitare doppie registrazioni da listener simultanei (hardware volume + keyboard event)
    if ((now - _lastImpulseTimestamp) < 50) {
      return;
    }
    _lastImpulseTimestamp = now;

    _clickCount++;

    if (_clickCount == 1) {
      // 1° Clic: avvia timer di debounce di 350ms
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () {
        if (_clickCount == 1) {
          debugPrint('[BluetoothKeyService] Clic Singolo confermato (<350ms) -> +1 SQUADRA A');
          onFeedback?.call('teamA', '+1 SQUADRA A');
          onTeamAPoint();
        }
        _clickCount = 0;
        _debounceTimer = null;
      });
    } else if (_clickCount >= 2) {
      // 2° Clic arrivato entro 350ms: annulla singolo e assegna SQUADRA B
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _clickCount = 0;
      debugPrint('[BluetoothKeyService] Doppio Clic confermato (<350ms) -> +1 SQUADRA B');
      onFeedback?.call('teamB', '+1 SQUADRA B');
      onTeamBPoint();
    }
  }

  /// Pressione Prolungata (Hold) o tasto Undo dedicato (Volume Down, Escape, Backspace) -> UNDO
  void _triggerUndo() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _clickCount = 0;
    debugPrint('[BluetoothKeyService] Azione UNDO confermata');
    onFeedback?.call('undo', 'PUNTO ANNULLATO (UNDO)');
    onUndo();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _holdTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareEvent);
    VolumeService.instance.dispose();
    focusNode.dispose();
  }
}
