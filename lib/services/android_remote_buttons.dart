import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Intercetta i tasti volume nella Activity Android, non i cambi di volume.
/// Nessun listener KVO iOS e nessuna modifica alle API Apple.
class AndroidRemoteButtons {
  AndroidRemoteButtons({required this.onImpulse}) {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_handleMethod);
    }
  }

  final VoidCallback onImpulse;
  static const MethodChannel _channel =
      MethodChannel('padel_score_board/android_remote_buttons');

  bool _active = false;
  bool _disposed = false;

  bool get isActive => _active;

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method != 'pulse') throw MissingPluginException();
    if (!_disposed && _active) onImpulse();
    return null;
  }

  Future<bool> activate() async {
    if (!Platform.isAndroid || _disposed) return false;
    if (_active) return true;
    try {
      _active = await _channel.invokeMethod<bool>(
            'setEnabled', <String, Object>{'enabled': true},
          ) == true;
    } catch (error) {
      debugPrint('[AndroidRemoteButtons] Attivazione fallita: $error');
      _active = false;
    }
    return _active;
  }

  Future<void> deactivate() async {
    _active = false;
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'setEnabled', <String, Object>{'enabled': false},
      );
    } catch (error) {
      debugPrint('[AndroidRemoteButtons] Disattivazione fallita: $error');
    }
  }

  Future<bool> setMusicVolume(double fraction) async {
    if (!Platform.isAndroid || _disposed) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'setMusicVolume', <String, Object>{'fraction': fraction},
          ) == true;
    } catch (error) {
      debugPrint('[AndroidRemoteButtons] Volume non impostato: $error');
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _active = false;
    if (Platform.isAndroid) {
      unawaited(deactivate());
      _channel.setMethodCallHandler(null);
    }
  }
}
