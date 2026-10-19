import 'volume_service.dart';

/// Implementazione stub no-op per Web e piattaforme non-IO.
/// Non esegue alcun codice nativo, garantendo compatibilità 100% sul Web.
VolumeService createVolumeService() => VolumeServiceStub();

class VolumeServiceStub implements VolumeService {
  @override
  void init({
    required void Function() onVolumeUp,
    required void Function() onVolumeDown,
  }) {
    // No-op su Web: la gestione sul Web avviene tramite KeyboardListener / HardwareKeyboard
  }

  @override
  void dispose() {}
}
