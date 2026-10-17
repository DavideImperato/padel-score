import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('it-IT');
      await _flutterTts.setSpeechRate(0.48); // Cadenza arbitrale naturale
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (_isMuted || text.trim().isEmpty) return;
    try {
      if (!_isInitialized) await init();
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) _flutterTts.stop();
  }
}
