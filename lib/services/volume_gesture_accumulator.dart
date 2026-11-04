import 'dart:async';

/// Colleziona notifiche di variazione volume iOS in un singolo gesto.
///
/// Una singola notifica NON prova quanti press/release fisici siano avvenuti.
/// Il rilevamento e' quindi prudente: scarta raffiche molto rapide (hold)
/// o sequenze con piu' di quattro notifiche anziche' attribuire punti extra.
/// La sorgente HID con KeyDown/KeyUp resta separata e invariata.
class VolumeGestureAccumulator {
  VolumeGestureAccumulator({
    required this.onGesture,
    this.gap = const Duration(milliseconds: 650),
    this.repeatThreshold = const Duration(milliseconds: 85),
  });

  final void Function(int notifications) onGesture;
  final Duration gap;
  final Duration repeatThreshold;

  Timer? _silenceTimer;
  DateTime? _previous;
  int _notifications = 0;
  bool _invalid = false;

  /// Una chiamata per ciascun CAMBIAMENTO volume osservato (STREAM/GET
  /// deduplicati dalla sorgente), senza moltiplicare per ampiezza del salto.
  void observe({DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    final previous = _previous;
    if (previous != null) {
      final elapsed = now.difference(previous);
      // Autorepeat dei pulsanti volume osservato a circa 40-45ms.
      if (elapsed.isNegative || elapsed < repeatThreshold) _invalid = true;
    }
    _previous = now;
    ++_notifications;
    if (_notifications > 4) _invalid = true;
    _silenceTimer?.cancel();
    _silenceTimer = Timer(gap, _complete);
  }

  void _complete() {
    final count = _notifications;
    final invalid = _invalid;
    reset();
    if (!invalid && count >= 1 && count <= 4) {
      onGesture(count);
    }
  }

  void reset() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _previous = null;
    _notifications = 0;
    _invalid = false;
  }
}
