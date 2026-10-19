import 'volume_service_stub.dart'
    if (dart.library.io) 'volume_service_native.dart';

/// Interfaccia astratta per il monitoraggio dei tasti volume hardware su piattaforme native (iOS/Android).
/// Su Web l'implementazione è uno stub no-op sicuro (zero errori o crash a tempo di compilazione ed esecuzione).
abstract class VolumeService {
  static VolumeService? _instance;
  static VolumeService get instance => _instance ??= createVolumeService();

  /// Avvia l'ascolto degli eventi di volume hardware (Volume Up e Volume Down)
  void init({
    required void Function() onVolumeUp,
    required void Function() onVolumeDown,
  });

  /// Ferma l'ascolto e rilascia le risorse
  void dispose();
}
