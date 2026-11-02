import 'dart:async';

/// Riunisce impulsi rapidi di una sorgente compatibile in un unico gesto.
/// Non genera eventi hardware e non modifica il volume del sistema.
/// Ogni impulso rinnova il timeout; il quarto completa subito la sequenza.
class RemoteClickSequence {
  RemoteClickSequence({
    required this.onSequence,
    this.gap = const Duration(milliseconds: 420),
  });

  final void Function(int clicks) onSequence;
  final Duration gap;
  Timer? _timer;
  int _clicks = 0;

  void impulse() {
    _timer?.cancel();
    _clicks += 1;
    if (_clicks == 4) {
      _complete();
    } else {
      _timer = Timer(gap, _complete);
    }
  }

  void _complete() {
    _timer?.cancel();
    _timer = null;
    final completed = _clicks;
    _clicks = 0;
    if (completed >= 1 && completed <= 4) onSequence(completed);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _clicks = 0;
  }
}
