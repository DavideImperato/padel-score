/// Trasforma gli incrementi osservati del volume iOS in impulsi del telecomando.
///
/// iOS non fornisce a questa classe un evento hardware per ciascun clic:
/// STREAM e polling possono accorpare piu' cambiamenti in una sola lettura.
/// Sul telefono di prova si osservano incrementi da 0.05; su altri dispositivi
/// possono arrivare incrementi da 1/16. Riconosciamo entrambe le scale.
/// Non si possono recuperare clic che iOS non rappresenta nel volume.
class VolumeImpulseDetector {
  static const List<double> _possibleSteps = <double>[0.05, 1.0 / 16.0];
  static const double _tolerance = 0.009;
  static const int _maxGroupedClicks = 4;
  double? _previous;

  void reset([double? baseline]) => _previous = baseline;

  int countSteps(double volume) {
    if (!volume.isFinite || volume < 0 || volume > 1) return 0;
    final previous = _previous;
    _previous = volume;
    if (previous == null) return 0;

    final delta = (volume - previous).abs();
    var bestCount = 0;
    var bestError = double.infinity;
    for (final step in _possibleSteps) {
      for (var count = 1; count <= _maxGroupedClicks; count++) {
        final error = (delta - count * step).abs();
        if (error < bestError) {
          bestError = error;
          bestCount = count;
        }
      }
    }
    if (bestError > _tolerance) return 0;
    return bestCount;
  }

  bool accept(double volume) => countSteps(volume) > 0;
}
