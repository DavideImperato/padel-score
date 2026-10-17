// Vedi visualizzatore completo per bluetooth_key_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BluetoothKeyService {
  final VoidCallback onTeamAPoint;
  final VoidCallback onTeamBPoint;
  final VoidCallback onUndo;
  final FocusNode focusNode = FocusNode();
  Timer? _timer;
  int _clicks = 0;

  BluetoothKeyService({required this.onTeamAPoint, required this.onTeamBPoint, required this.onUndo});

  void init() {
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp || event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _clicks++;
      if (_clicks == 1) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 400), () {
          if (_clicks == 1) onTeamAPoint();
          _clicks = 0;
        });
      } else if (_clicks >= 2) {
        _timer?.cancel();
        _clicks = 0;
        onTeamBPoint();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown || event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _timer?.cancel();
      _clicks = 0;
      onUndo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void dispose() {
    _timer?.cancel();
    focusNode.dispose();
  }
}
