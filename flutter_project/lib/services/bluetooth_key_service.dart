import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servizio per intercettare i comandi inviati da telecomandi Bluetooth economici
/// (telecomandi selfie / shutter Bluetooth che inviano eventi Volume Up / Down / Media).
class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;

  /// FocusNode da associare alla radice della schermata per catturare i tasti
  final FocusNode focusNode = FocusNode();

  Timer? _volumeUpDoubleTapTimer;
  int _volumeUpClickCount = 0;
  static const Duration doubleClickWindow = Duration(milliseconds: 400);

  BluetoothKeyService({
    required this.onTeamAPoint,
    required this.onTeamBPoint,
    required this.onUndo,
  });

  /// Inizializza e richiede il focus per la ricezione tasti
  void init() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    });
  }

  /// Gestisce l'evento tastiera (da passare a KeyboardListener o FocusableActionDetector)
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    // Intercettiamo solo l'evento iniziale di pressione (KeyDownEvent)
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // 1. Tasto VOLUME UP (o pulsanti shutter selfie associati a Volume Up / Media Next)
    if (key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.arrowUp) {
      _handleVolumeUpPress();
      return KeyEventResult.handled;
    }

    // 2. Tasto VOLUME DOWN (o tasto associato a Volume Down / Media Prev per Undo)
    if (key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.backspace) {
      _handleVolumeDownPress();
      return KeyEventResult.handled;
    }

    // 3. Tasto Space / Enter (spesso inviato dal secondo tasto iOS/Android di telecomandi cinesi)
    // Se premuto Space o Enter, assegniamo come scorciatoia diretta Team B per comodità
    if (key == LogicalKeyboardKey.space) {
      onTeamBPoint();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Logica Click singolo vs Doppio Click entro 400ms su Volume Up
  void _handleVolumeUpPress() {
    _volumeUpClickCount++;

    if (_volumeUpClickCount == 1) {
      // Primo click: avviamo il timer di 400ms
      _volumeUpDoubleTapTimer?.cancel();
      _volumeUpDoubleTapTimer = Timer(doubleClickWindow, () {
        // Se il timer scade senza un secondo click -> Click Singolo = Squadra A
        if (_volumeUpClickCount == 1) {
          debugPrint('[BluetoothKeyService] Volume Up Singolo -> Punto Squadra A');
          onTeamAPoint();
        }
        _volumeUpClickCount = 0;
      });
    } else if (_volumeUpClickCount >= 2) {
      // Secondo click arrivato prima della scadenza dei 400ms -> Doppio Click = Squadra B
      _volumeUpDoubleTapTimer?.cancel();
      _volumeUpClickCount = 0;
      debugPrint('[BluetoothKeyService] Volume Up Doppio Click (<400ms) -> Punto Squadra B');
      onTeamBPoint();
    }
  }

  /// Click su Volume Down -> Undo immediato
  void _handleVolumeDownPress() {
    _volumeUpDoubleTapTimer?.cancel();
    _volumeUpClickCount = 0;
    debugPrint('[BluetoothKeyService] Volume Down -> Undo');
    onUndo();
  }

  void dispose() {
    _volumeUpDoubleTapTimer?.cancel();
    focusNode.dispose();
  }
}
