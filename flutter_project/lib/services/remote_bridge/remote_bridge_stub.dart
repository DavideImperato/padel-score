import 'remote_bridge.dart';

/// Implementazione stub per piattaforme native (Android / iOS / Desktop).
/// Su nativo gli eventi arrivano direttamente dall'HardwareKeyboard e KeyboardListener di Flutter.
RemoteBridge createRemoteBridge() => RemoteBridgeStub();

class RemoteBridgeStub implements RemoteBridge {
  @override
  void init({required void Function(String action) onSignal}) {
    // No-op su piattaforme native
  }

  @override
  void unlockAudio() {
    // No-op su piattaforme native
  }

  @override
  void dispose() {}
}
