import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:padel_volume_diagnostic/padel_volume_diagnostic.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

import 'volume_impulse_detector.dart';
import 'volume_native_restore_guard.dart';

/// Input telecomando volume iOS: listener persistente.
///
/// Non intercetta i tasti prima del sistema: osserva il cambiamento di volume
/// e tenta di riportarlo al livello scelto dall'utente. L'operazione non e'
/// garantita su tutti i dispositivi. Il conteggio 1/2/3/4 rimane nel servizio
/// BluetoothKeyService tramite RemoteClickSequence.
class VolumeRemoteInput {
  VolumeRemoteInput({
    required this.onImpulse,
    required this.canAcceptInput,
    this.onUnavailable,
  });

  final VoidCallback onImpulse;
  final bool Function() canAcceptInput;
  final VoidCallback? onUnavailable;

  static const double _sameTolerance = 0.0005;
  static const double _restoreTolerance = 0.025;

  final VolumeImpulseDetector _detector = VolumeImpulseDetector();
  StreamSubscription<double>? _stream;
  Timer? _debugPoll;
  VolumeNativeRestoreGuard? _guard;

  bool _active = false;
  bool _disposed = false;
  bool _polling = false;
  bool _writing = false;
  bool _restoreQueued = false;
  int _generation = 0;
  double? _preferredVolume;
  double? _lastSample;

  bool get isActive => _active;

  Future<bool> activate({double? preferredVolume}) async {
    if (!Platform.isIOS || _disposed) return false;
    if (_active) return true;

    final generation = ++_generation;
    try {
      // Una sola sottoscrizione per tutta la durata del tabellone.
      _stream ??= PerfectVolumeControl.stream.listen(
        (volume) => _receive(volume, 'STREAM'),
        onError: (Object error, StackTrace trace) {
          debugPrint('[VolumeRemoteInput] STREAM errore: $error');
        },
        onDone: () {
          _stream = null;
          deactivate();
          onUnavailable?.call();
        },
      );

      // Test Debug: manteniamo la UI di sistema normale, come nella sonda
      // PadelVolumeDiagnostic che aveva confermato le scritture native.
      // Non usiamo hideUI insieme al controllo MPVolumeView della sonda.
      PerfectVolumeControl.hideUI = false;

      var initial = await PerfectVolumeControl.getVolume();
      if (_disposed || generation != _generation) return false;
      if (!initial.isFinite || initial < 0 || initial > 1) return false;

      // Il preset arriva dal menu, non dal livello corrente dell'iPhone.
      // Durante la scrittura iniziale il listener e' ancora inattivo,
      // percio' il ricentramento NON genera un punto fantasma.
      final target = preferredVolume ?? initial;
      if (!target.isFinite || target < 0.05 || target > 0.90) {
        debugPrint('[VolumeRemoteInput] Preset non valido: $target');
        return false;
      }
      if ((initial - target).abs() > _restoreTolerance) {
        final result = await _writeVerified(target);
        if (_disposed || generation != _generation) return false;
        if (result?.confirmed != true) {
          debugPrint('[VolumeRemoteInput] Preset iniziale non confermato: '
              'richiesto=$target reale=$initial');
          return false;
        }
        initial = result!.observed;
      }
      _preferredVolume = target;
      _lastSample = initial;
      _guard = VolumeNativeRestoreGuard(target: target);
      _detector.reset(initial);
      _restoreQueued = false;
      _active = true;

      debugPrint('[VolumeRemoteInput] ATTIVO: volume reale=$initial; '
          'target restore=$target; restorePerClick=true');

      // Solo diagnostica: GET e STREAM sono deduplicati da _lastSample.
      if (Platform.isIOS) {
        _debugPoll?.cancel();
        _debugPoll = Timer.periodic(
          const Duration(milliseconds: 150),
          (_) => unawaited(_pollOnce(generation)),
        );
      }
      return true;
    } catch (error) {
      debugPrint('[VolumeRemoteInput] Attivazione fallita: $error');
      if (generation == _generation) deactivate();
      return false;
    }
  }

  Future<VolumeProbeResult?> _writeVerified(double value) async {

    // Il controllo MPVolumeView potrebbe non essere ancora pronto.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await PadelVolumeDiagnostic.write(value);
        if (result.confirmed) return result;
        debugPrint('[VolumeRemoteInput] Scrittura non confermata: '
            'richiesto=$value letto=${result.observed}');
      } on PlatformException catch (error) {
        debugPrint('[VolumeRemoteInput] Native write: ${error.code}');
        if (error.code != 'slider_unavailable') return null;
      } catch (error) {
        debugPrint('[VolumeRemoteInput] Native write fallita: $error');
        return null;
      }
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 100 + attempt * 100),
        );
      }
    }
    return null;
  }

  Future<void> _pollOnce(int generation) async {
    if (!_active || _disposed || _polling || generation != _generation) return;
    _polling = true;
    try {
      final volume = await PerfectVolumeControl.getVolume();
      if (_active && !_disposed && generation == _generation) {
        _receive(volume, 'GET');
      }
    } catch (error) {
      debugPrint('[VolumeRemoteInput] GET errore: $error');
    } finally {
      _polling = false;
    }
  }

  void _receive(double volume, String source) {
    if (!_active || _disposed || !volume.isFinite ||
        volume < 0 || volume > 1) {
      return;
    }

    // Un ritorno verso il target causato da una scrittura NON e' un clic.
    if (_writing && (_guard?.consume(volume) ?? false)) {
      _lastSample = volume;
      _detector.reset(volume);
      debugPrint('[VolumeRemoteInput] $source ritorno ignorato: $volume');
      return;
    }

    final previous = _lastSample;
    if (previous != null && (volume - previous).abs() <= _sameTolerance) {
      return;
    }
    _lastSample = volume;

    if (!_detector.accept(volume)) {
      debugPrint('[VolumeRemoteInput] $source filtrato: $volume');
      return;
    }
    if (!canAcceptInput()) return;

    debugPrint('[VolumeRemoteInput] $source CLICK: $volume');
    onImpulse(); // Il debounce 1-4 e' GIA' in BluetoothKeyService.
    _requestRestore(_generation);
  }

  void _requestRestore(int generation) {
    if (!_active || _disposed || generation != _generation ||
        _preferredVolume == null) {
      return;
    }
    if (_writing) {
      _restoreQueued = true;
      return;
    }
    unawaited(_restore(generation));
  }

  Future<void> _restore(int generation) async {
    if (_writing || !_active || _disposed || generation != _generation) return;
    _writing = true;
    try {
      for (var round = 0; round < 2; round++) {
        _restoreQueued = false;
        final from = _lastSample;
        final target = _preferredVolume;
        if (from == null || target == null ||
            (from - target).abs() <= _restoreTolerance) {
          break;
        }

        _guard?.begin(from);
        debugPrint('[VolumeRemoteInput] RESET richiesto: $from -> $target');
        final result = await _writeVerified(target);
        if (!_active || _disposed || generation != _generation) return;

        if (result?.confirmed != true) {
          debugPrint('[VolumeRemoteInput] RESET NON CONFERMATO');
          break; // Non fingere che il volume sia stato bloccato.
        }
        _lastSample = result!.observed;
        _detector.reset(result.observed);
        debugPrint('[VolumeRemoteInput] RESET confermato: ${result.observed}');

        if (!_restoreQueued) break;
      }
    } finally {
      _guard?.clear();
      _writing = false;
      _restoreQueued = false;
    }
  }

  void deactivate() {
    final wasActive = _active;
    ++_generation;
    _active = false;
    _debugPoll?.cancel();
    _debugPoll = null;
    _detector.reset();
    _guard?.clear();
    _guard = null;
    _lastSample = null;
    _preferredVolume = null;
    _restoreQueued = false;
    PerfectVolumeControl.hideUI = false;
    if (wasActive) {
      debugPrint('[VolumeRemoteInput] Disattivato (stream persistente)');
    }
  }

  void dispose() {
    if (_disposed) return;
    deactivate();
    _disposed = true;
    final subscription = _stream;
    _stream = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (Platform.isIOS) {
      unawaited(PadelVolumeDiagnostic.release().catchError((Object _) {}));
    }
  }
}
