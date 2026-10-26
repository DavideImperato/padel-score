import 'package:padel_scorebot/services/tts_service.dart';

/// Sostituto del motore vocale per test: non tocca i plugin di piattaforma.
class FakeTtsService implements TtsService {
  final List<String> spoken = [];
  bool _muted = false;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text) async {
    if (!_muted && text.trim().isNotEmpty) spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  void setMuted(bool muted) => _muted = muted;

  @override
  void dispose() {}
}
