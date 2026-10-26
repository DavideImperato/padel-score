import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';
import 'volume_service.dart';

/// Implementazione nativa per Android e iOS (APK / TestFlight).
/// Ascolta i cambiamenti di volume hardware generati sia dai pulsanti fisici
/// del dispositivo sia dai telecomandi selfie Bluetooth che inviano impulsi Volume Up / Down.
VolumeService createVolumeService() => VolumeServiceNative();

class VolumeServiceNative implements VolumeService {
  double? _lastVolume;
  bool _isListening = false;

  @override
  void init({
    required void Function() onVolumeUp,
    required void Function() onVolumeDown,
  }) {
    if (kIsWeb) return;

    try {
      _isListening = true;

      // Nasconde la barra di volume di sistema per non oscurare il tabellone
      VolumeController().showSystemUI = false;

      // Legge il volume iniziale di riferimento
      VolumeController().getVolume().then((v) {
        _lastVolume = v;
      }).catchError((_) {});

      // Ascolta le variazioni del volume hardware del dispositivo
      VolumeController().listener((volume) {
        if (!_isListening) return;

        if (_lastVolume != null) {
          if (volume > _lastVolume!) {
            debugPrint('[VolumeServiceNative] Hardware Volume UP rilevato ($volume)');
            onVolumeUp();
          } else if (volume < _lastVolume!) {
            debugPrint('[VolumeServiceNative] Hardware Volume DOWN rilevato ($volume)');
            onVolumeDown();
          }
        }
        _lastVolume = volume;
      });
    } catch (e) {
      debugPrint('[VolumeServiceNative] Avviso inizializzazione VolumeController: $e');
    }
  }

  @override
  void dispose() {
    _isListening = false;
    try {
      VolumeController().removeListener();
    } catch (_) {}
  }
}
