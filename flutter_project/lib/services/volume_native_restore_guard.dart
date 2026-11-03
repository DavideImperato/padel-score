/// Distingue, durante una singola scrittura del volume, le notifiche
/// compatibili con il ripristino richiesto dall'app.
///
/// Non puo' distinguere con certezza un vero tasto Volume - premuto
/// simultaneamente a un ripristino discendente (limite delle API iOS).
/// Si usa esclusivamente per un esperimento in Debug.
class VolumeNativeRestoreGuard {
  VolumeNativeRestoreGuard({
    required this.target,
    this.tolerance = 0.025,
    this.minimumStep = 0.004,
  });

  final double target;
  final double tolerance;
  final double minimumStep;

  double? _remainingDistance;
  double? _initialOffset;

  bool get pending => _remainingDistance != null;

  void begin(double from) {
    if (!from.isFinite || (from - target).abs() <= tolerance) {
      clear();
      return;
    }
    _initialOffset = from - target;
    _remainingDistance = (from - target).abs();
  }

  /// Restituisce true solo per valori che si avvicinano al target durante
  /// una scrittura, oppure quando il target e' stato raggiunto.
  bool consume(double value) {
    final distanceBefore = _remainingDistance;
    final initialOffset = _initialOffset;
    if (distanceBefore == null || initialOffset == null || !value.isFinite) {
      return false;
    }
    final distance = (value - target).abs();
    if (distance <= tolerance) {
      clear();
      return true;
    }
    final sameSide = (value - target) * initialOffset > 0;
    if (sameSide && distance + minimumStep < distanceBefore) {
      _remainingDistance = distance;
      return true;
    }
    return false;
  }

  void clear() {
    _remainingDistance = null;
    _initialOffset = null;
  }
}
