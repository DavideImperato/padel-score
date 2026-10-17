import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Servizio di sintesi vocale (TTS) 100% offline in lingua italiana
/// Ottimizzato con cadenza naturale da arbitro ufficiale di Padel
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  /// Inizializza il motore TTS con voce italiana, pitch naturale e velocità arbitrale
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('it-IT');
      // Velocità ridotta e naturale (0.48) per massima chiarezza e cadenza da arbitro
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);     // Volume pieno per udibilità a 15 metri
      await _flutterTts.setPitch(1.0);      // Tono naturale umano

      // Configurazione categoria audio iOS (Duck/Mix)
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      await _flutterTts.awaitSpeakCompletion(true);
      _isInitialized = true;
      debugPrint('[TtsService] Inizializzato con successo (it-IT, rate 0.48)');
    } catch (e) {
      debugPrint('[TtsService] Errore inizializzazione TTS: $e');
    }
  }

  /// Pronuncia una frase in modo fluido e naturale
  Future<void> speak(String text) async {
    if (_isMuted || text.trim().isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.stop();
      // Il punto fermo e le pause creano una cadenza naturale da arbitro
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Errore riproduzione vocale: $e');
    }
  }

  /// Attiva o disattiva l'audio
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      _flutterTts.stop();
    }
  }

  /// Ferma la voce corrente
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  void dispose() {
    _flutterTts.stop();
  }
}
