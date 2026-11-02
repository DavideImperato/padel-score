import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';

import 'volume_service.dart';

/// Listener volume preesistente riservato ad Android.
/// iOS non utilizza piu' bridge KVO personalizzati.
VolumeService createVolumeService() => VolumeServiceNative();

class VolumeServiceNative implements VolumeService {
  double? _lastAndroidVolume;
  bool _isListening = false;

  @override
  void init({
    required void Function() onVolumeUp,
    required void Function() onVolumeDown,
  }) {
    if (kIsWeb) return;
    dispose();
    _isListening = true;

    // iOS: il vecchio bridge KVO non viene piu' avviato.
    // Il volume e' opzionalmente osservato dal plugin in VolumeRemoteInput.
    if (Platform.isIOS) return;

    // Percorso Android preesistente: non modificato in questa fase Apple.
    try {
      VolumeController().showSystemUI = false;
      VolumeController().getVolume().then((v) {
        if (_isListening) _lastAndroidVolume = v;
      }).catchError((_) {});
      VolumeController().listener((volume) {
        if (!_isListening) return;
        if (_lastAndroidVolume != null) {
          if (volume > _lastAndroidVolume!) {
            debugPrint('[VolumeServiceNative] Hardware Volume UP rilevato ($volume)');
            onVolumeUp();
          } else if (volume < _lastAndroidVolume!) {
            debugPrint('[VolumeServiceNative] Hardware Volume DOWN rilevato ($volume)');
            onVolumeDown();
          }
        }
        _lastAndroidVolume = volume;
      });
    } catch (error) {
      debugPrint('[VolumeServiceNative] Avviso inizializzazione VolumeController: $error');
    }
  }

  @override
  void dispose() {
    _isListening = false;
    if (!Platform.isIOS) {
      try {
        VolumeController().removeListener();
      } catch (_) {}
    }
  }
}
