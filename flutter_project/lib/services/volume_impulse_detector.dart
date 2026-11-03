/// Usa solo i cambiamenti reali del volume per generare impulsi opzionali.
/// Non identifica chi ha premuto (telecomando, iPhone o Centro di controllo).
/// Non simula pressioni quando il volume non cambia agli estremi.
class VolumeImpulseDetector {
  double? _previous;

  void reset([double? baseline]) => _previous = baseline;

  bool accept(double volume) {
    if (!volume.isFinite || volume < 0 || volume > 1) return false;
    final previous = _previous;
    _previous = volume;
    if (previous == null) return false;
    final delta = (volume - previous).abs();
    // Un passo iOS standard e' comunemente circa 1/16; scartiamo
    // fluttuazioni minuscole e grandi variazioni da slider/route audio.
    return delta >= 0.018 && delta <= 0.16;
  }
}
