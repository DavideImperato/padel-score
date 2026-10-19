import 'remote_bridge_stub.dart'
    if (dart.library.html) 'remote_bridge_web.dart';

/// Interfaccia astratta per il bridge tra Flutter e la piattaforma host
/// (MediaSession API, background silent audio loop per iOS Safari e Android Chrome su Web).
abstract class RemoteBridge {
  static RemoteBridge? _instance;
  static RemoteBridge get instance => _instance ??= createRemoteBridge();

  /// Inizializza l'ascolto dei segnali dal telecomando Bluetooth e MediaSession
  void init({required void Function(String action) onSignal});

  /// Sblocca la traccia audio in background per abilitare la MediaSession API su Web
  void unlockAudio();

  /// Rilascia le risorse
  void dispose();
}
