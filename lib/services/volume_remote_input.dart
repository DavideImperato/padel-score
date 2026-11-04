import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:padel_volume_diagnostic/padel_volume_diagnostic.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

import 'volume_impulse_detector.dart';
import 'volume_gesture_accumulator.dart';

/// Rilevazione volume iOS per telecomandi compatibili: percorso sperimentale.
/// Letture periodiche tramite sonda nativa che legge outputVolume senza
/// attivare AVAudioSession a ogni polling.
///
/// A differenza della versione precedente, NON riscrive il volume dopo ogni
/// pressione. Aspetta che il gesto sia terminato, poi ripristina il livello.
/// Questo limita notifiche di ripristino che potevano essere interpretate
/// come pressioni aggiuntive (ad esempio un punto A dopo Undo).
///
/// iOS espone variazioni del volume, non un evento hardware garantito per
/// ogni clic del telecomando: il comportamento va provato sull'iPhone reale.
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

  // La finestra di riconoscimento iOS e' 650 ms: il ripristino parte
  // dopo un silenzio maggiore, per evitare di spezzare clic multipli.
  static const Duration _restoreAfterSilence = Duration(milliseconds: 1100);
  static const Duration _ignoreRestoreEcho = Duration(milliseconds: 280);

  // Con un target al 90% bastano due pressioni Volume Su per saturare il
  // livello. Manteniamo quindi i preset entro un intervallo che consenta
  // quattro passi standard in entrambe le direzioni.
  static const double _minimumOperatingVolume = 0.35;
  static const double _maximumOperatingVolume = 0.65;

  final VolumeImpulseDetector _detector = VolumeImpulseDetector();

  // Per i telecomandi iOS, una variazione osservata non equivale sempre
  // al numero di passi del volume: +0.10 puo' arrivare con una sola notifica.
  // Attendiamo la fine del gesto e NON attribuiamo punti a sequenze anomale.
  late final VolumeGestureAccumulator _volumeGestures =
      VolumeGestureAccumulator(onGesture: (int count) {
        if (!_active || _disposed || !canAcceptInput()) return;
        debugPrint('[VolumeRemoteInput] GESTO CONFERMATO: $count evento/i');
        // Il servizio storico interpreta questi impulsi nella sequenza iOS.
        // Li consegniamo solo DOPO la pausa, tutti insieme; la quarta
        // pressione non puo' piu' aprire un secondo gesto durante la raffica.
        for (var i = 0; i < count; i++) {
          if (!_active || _disposed || !canAcceptInput()) return;
          onImpulse();
        }
      });
  StreamSubscription<double>? _stream;
  Timer? _debugPoll;
  Timer? _delayedRestore;

  bool _active = false;
  bool _disposed = false;
  bool _polling = false;
  bool _writing = false;
  int? _writingGeneration;
  int _generation = 0;
  double? _preferredVolume;
  double? _lastSample;
  DateTime? _ignoreSamplesUntil;

  bool get isActive => _active;

  Future<bool> activate({double? preferredVolume}) async {
    if (!Platform.isIOS || _disposed) return false;
    if (_active) return true;

    final generation = ++_generation;
    try {
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

      PerfectVolumeControl.hideUI = false;

      var initial = await PadelVolumeDiagnostic.read();
      if (_disposed || generation != _generation) return false;
      if (!initial.isFinite || initial < 0 || initial > 1) return false;

      final requested = preferredVolume ?? initial;
      if (!requested.isFinite || requested < 0.05 || requested > 0.90) {
        debugPrint('[VolumeRemoteInput] Preset non valido: $requested');
        return false;
      }
      final target = requested
          .clamp(_minimumOperatingVolume, _maximumOperatingVolume)
          .toDouble();

      // Durante l'attivazione il listener non attribuisce punti.
      if ((initial - target).abs() > _restoreTolerance) {
        final result = await _writeVerified(target);
        if (_disposed || generation != _generation) return false;
        if (result?.confirmed != true) {
          debugPrint('[VolumeRemoteInput] Volume iniziale non confermato: '
              'richiesto=$target reale=$initial');
          return false;
        }
        initial = result!.observed;
      }

      _preferredVolume = target;
      _lastSample = initial;
      _detector.reset(initial);
      _ignoreSamplesUntil = DateTime.now().add(_ignoreRestoreEcho);
      _active = true;
      _delayedRestore?.cancel();
      debugPrint('[VolumeRemoteInput] ATTIVO: richiesto=$requested; '
          'livello operativo=$target; volume reale=$initial');

      _debugPoll?.cancel();
      _debugPoll = Timer.periodic(
        const Duration(milliseconds: 150),
        (_) => unawaited(_pollOnce(generation)),
      );
      return true;
    } catch (error) {
      debugPrint('[VolumeRemoteInput] Attivazione fallita: $error');
      if (generation == _generation) deactivate();
      return false;
    }
  }

  Future<VolumeProbeResult?> _writeVerified(double value) async {
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
      final volume = await PadelVolumeDiagnostic.read();
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
    if (!_active || _disposed || !volume.isFinite || volume < 0 || volume > 1) {
      return;
    }

    // Tutte le notifiche mentre l'app stessa sta scrivendo vengono scartate.
    // Anche le notifiche asincrone in ritardo dopo la scrittura sono ignorate.
    if (_writing ||
        (_ignoreSamplesUntil != null &&
            DateTime.now().isBefore(_ignoreSamplesUntil!))) {
      return;
    }

    final previous = _lastSample;
    if (previous != null && (volume - previous).abs() <= _sameTolerance) {
      return;
    }
    _lastSample = volume;

    // La sonda valida la variazione, ma NON trasformiamo +0.10 in 2 clic:
    // sul telefono fisico quel salto e' stato osservato come UN evento.
    // IOS non fornisce press/release hardware affidabili via outputVolume.
    final volumeSteps = _detector.countSteps(volume);
    if (volumeSteps == 0) {
      debugPrint('[VolumeRemoteInput] $source variazione ignorata: $volume');
      return;
    }

    if (!canAcceptInput()) {
      _volumeGestures.reset();
      debugPrint('[VolumeRemoteInput] $source scartato: schermata non attiva');
      return;
    }

    debugPrint('[VolumeRemoteInput] ${DateTime.now().toIso8601String()} '
        '$source: 1 notifica (salto volume di $volumeSteps passi); '
        'volume=$volume');
    _volumeGestures.observe();
    _scheduleRestore(_generation);
  }

  void _scheduleRestore(int generation) {
    _delayedRestore?.cancel();
    _delayedRestore = Timer(_restoreAfterSilence, () {
      _delayedRestore = null;
      unawaited(_restore(generation));
    });
  }

  Future<void> _restore(int generation) async {
    if (_writing || !_active || _disposed || generation != _generation) return;
    final from = _lastSample;
    final target = _preferredVolume;
    if (from == null || target == null ||
        (from - target).abs() <= _restoreTolerance) {
      return;
    }

    _writing = true;
    _writingGeneration = generation;
    bool failed = false;
    try {
      debugPrint('[VolumeRemoteInput] Ripristino dopo il gesto: $from -> $target');
      final result = await _writeVerified(target);
      if (!_active || _disposed || generation != _generation) return;

      if (result?.confirmed == true) {
        _lastSample = result!.observed;
        _detector.reset(result.observed);
        debugPrint('[VolumeRemoteInput] Ripristino confermato: ${result.observed}');
      } else {
        failed = true;
        debugPrint('[VolumeRemoteInput] Ripristino NON confermato');
      }
    } finally {
      if (_writingGeneration == generation) {
        _writing = false;
        _writingGeneration = null;
        if (_active && generation == _generation) {
          _ignoreSamplesUntil = DateTime.now().add(_ignoreRestoreEcho);
        }
      }
    }
    // Se l'app non riesce a ripristinare il volume, non continua a contare
    // pressioni da uno stato incerto: si disattiva e notifica la schermata.
    if (failed && _active && generation == _generation) {
      deactivate();
      onUnavailable?.call();
    }
  }

  void deactivate() {
    final wasActive = _active;
    ++_generation;
    _active = false;
    _debugPoll?.cancel();
    _debugPoll = null;
    _delayedRestore?.cancel();
    _delayedRestore = null;
    _detector.reset();
    _volumeGestures.reset();
    _lastSample = null;
    _preferredVolume = null;
    _ignoreSamplesUntil = null;
    PerfectVolumeControl.hideUI = false;
    if (wasActive) {
      debugPrint('[VolumeRemoteInput] Disattivato');
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
