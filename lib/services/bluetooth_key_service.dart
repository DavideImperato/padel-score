import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'volume/volume_service.dart';
import 'remote_click_sequence.dart';

/// Riceve eventi standard HID di tastiera quando il tabellone e` attivo.
/// Su iOS usa esclusivamente HardwareKeyboard: nessun listener del volume,
/// nessuna richiesta a canali nativi e nessuna modifica al volume di sistema.
/// Gli eventi Volume Up/Down di sistema NON sono tasti HID garantiti da iOS.
/// Mappatura HID iOS: 1 impulso A, 2 B, 3 Undo, 4 annuncio battitore.
/// Su Android conserva il comportamento preesistente (Volume Down = Undo).
class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;
  final VoidCallback? onAnnounceServer;
  final void Function(String actionType, String label)? onFeedback;
  final bool Function()? isInputEnabled;
  final bool _keyboardOnly;
  bool _initialized = false;

  /// Android mantiene KeyboardListener e il focus gia` utilizzati.
  final FocusNode focusNode = FocusNode();

  /// KeyDown validi sul protocollo HID; volutamente esclusi i tasti volume.
  // Scorciatoie dirette del tabellone gia` disponibili prima del cambio HID.
  static final Set<LogicalKeyboardKey> _directShortcutKeys = {
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.keyU,
    LogicalKeyboardKey.keyZ,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.backspace,
  };
  static final Set<LogicalKeyboardKey> _hidKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
  };
  final Set<PhysicalKeyboardKey> _keysHeld = {};

  // Gestione Debounce per 1 Clic vs 2 Clic entro 350ms (Android)
  late final RemoteClickSequence _iosClicks = RemoteClickSequence(
    onSequence: _dispatchIosSequence,
  );

  Timer? _debounceTimer;
  int _clickCount = 0;
  static const Duration debounceDuration = Duration(milliseconds: 350);

  // Gestione Pressione Prolungata (Hold) per Undo
  Timer? _holdTimer;
  bool _isHoldTriggered = false;
  static const Duration holdDuration = Duration(milliseconds: 550);

  // Deduplicazione degli impulsi nella mappatura Android preesistente
  int _lastImpulseTimestamp = 0;
  int _lastKeyEventTimestamp = 0;
  LogicalKeyboardKey? _lastHandledKey;

  BluetoothKeyService({
    required this.onTeamAPoint,
    required this.onTeamBPoint,
    required this.onUndo,
    this.onAnnounceServer,
    this.onFeedback,
    this.isInputEnabled,
    // Utilizzato esclusivamente dai test per simulare il percorso iOS su VM.
    bool? keyboardOnlyOverride,
  }) : _keyboardOnly = keyboardOnlyOverride ?? (Platform.isIOS || Platform.isAndroid);

  /// Registra un unico handler Flutter, solo mentre il servizio esiste.
  void init() {
    if (_initialized) return;
    _initialized = true;

    if (!_keyboardOnly) {
      // Percorso Android precedente: nessuna modifica a VolumeService.
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_initialized && !focusNode.hasFocus) focusNode.requestFocus();
      });
    } else {
      debugPrint('[BluetoothKeyService] HID: gestione tasti senza listener volume legacy');
    }

    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareEvent);
  }

  bool _handleGlobalHardwareEvent(KeyEvent event) {
    if (_keyboardOnly) return _handleIosHid(event);
    return _processKeyEvent(event) == KeyEventResult.handled;
  }

  /// Il KeyboardListener del tabellone resta valido solo per Android.
  /// Su iOS il doppio listener non puo` generare punti duplicati.
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_keyboardOnly) return KeyEventResult.ignored;
    return _processKeyEvent(event);
  }

  /// Un impulso HID per ogni KeyDown reale; mai su KeyUp, Repeat o sintetici.
  /// I tasti volume NON sono accettati: iOS puo` riservarli al sistema.
  bool _handleIosHid(KeyEvent event) {
    final isImpulse = _hidKeys.contains(event.logicalKey);
    final isShortcut = _directShortcutKeys.contains(event.logicalKey);
    if (!isImpulse && !isShortcut) return false;

    if (event is KeyUpEvent) {
      _keysHeld.remove(event.physicalKey);
      return _canAcceptIosInput();
    }
    if (!_canAcceptIosInput()) {
      _iosClicks.cancel();
      _keysHeld.clear();
      return false;
    }
    if (event.synthesized) return false;
    if (event is KeyRepeatEvent) return true;
    if (event is! KeyDownEvent) return false;
    if (!_keysHeld.add(event.physicalKey)) return true;

    if (isShortcut) {
      _iosClicks.cancel();
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.digit1) {
        onFeedback?.call('teamA', '+1 SQUADRA A');
        onTeamAPoint();
      } else if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.digit2) {
        onFeedback?.call('teamB', '+1 SQUADRA B');
        onTeamBPoint();
      } else {
        _triggerUndo();
      }
      return true;
    }

    debugPrint('[BluetoothKeyService] iOS HID KeyDown: ${event.logicalKey.keyLabel}');
    _iosClicks.impulse();
    return true;
  }

  /// Impulso da stream del volume quando l'utente ha attivato la modalita'.
  /// Riutilizza la stessa sequenza di clic degli eventi HID.
  void registerExternalVolumeImpulse() {
    final enabled = _canAcceptIosInput();
    if (!_keyboardOnly || !enabled) {
      debugPrint('[BluetoothKeyService] Volume ricevuto ma scartato: '
          'iOS=$_keyboardOnly, inputAbilitato=$enabled');
      _iosClicks.cancel();
      return;
    }
    debugPrint('[BluetoothKeyService] Volume -> sequenza clic iOS');
    _iosClicks.impulse();
  }

  /// Elimina un comando parziale quando il tabellone non e' piu' disponibile.
  void cancelPendingSequence() => _iosClicks.cancel();

  bool _canAcceptIosInput() => _initialized && (isInputEnabled?.call() ?? true);

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

    // Percorso Android storico: Volume Down e tasti dedicati = Undo.
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

  /// Sequenze iOS: un'azione sola dopo la finestra temporale; mai un punto
  /// provvisorio prima di sapere se il gesto è singolo, doppio o triplo.
  void _dispatchIosSequence(int count) {
    // Se il dialogo si apre tra la pressione e il timeout, non dare punti.
    if (!_canAcceptIosInput()) return;
    switch (count) {
      case 1:
        debugPrint('[BluetoothKeyService] iOS 1 click -> Squadra A');
        onFeedback?.call('teamA', '+1 SQUADRA A');
        onTeamAPoint();
        break;
      case 2:
        debugPrint('[BluetoothKeyService] iOS 2 click -> Squadra B');
        onFeedback?.call('teamB', '+1 SQUADRA B');
        onTeamBPoint();
        break;
      case 3:
        debugPrint('[BluetoothKeyService] iOS 3 click -> Undo');
        _triggerUndo();
        break;
      case 4:
        debugPrint('[BluetoothKeyService] iOS 4 click -> Annuncio battitore');
        onFeedback?.call('server', 'ANNUNCIO BATTITORE');
        onAnnounceServer?.call();
        break;
    }
  }

  /// Tasti dedicati (Esc, Backspace) e vecchia mappatura Android.
  void _triggerUndo() {
    _iosClicks.cancel();
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _clickCount = 0;
    debugPrint('[BluetoothKeyService] Azione UNDO confermata');
    onFeedback?.call('undo', 'PUNTO ANNULLATO (UNDO)');
    onUndo();
  }

  void dispose() {
    if (!_initialized) return;
    _initialized = false;
    _iosClicks.cancel();
    _keysHeld.clear();
    _debounceTimer?.cancel();
    _holdTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareEvent);
    if (!_keyboardOnly) VolumeService.instance.dispose();
    focusNode.dispose();
  }
}
