import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_service.dart';

/// Livelli del volume di sistema per il telecomando iOS sperimentale.
/// Non modificano il guadagno della voce arbitrale TTS.
enum RemoteVolumePreset { basso, medio, alto }

extension RemoteVolumePresetValue on RemoteVolumePreset {
  double get systemVolume => switch (this) {
    RemoteVolumePreset.basso => 0.2,
    RemoteVolumePreset.medio => 0.5,
    RemoteVolumePreset.alto => 0.9,
  };

  String get label => switch (this) {
    RemoteVolumePreset.basso => 'Basso',
    RemoteVolumePreset.medio => 'Medio',
    RemoteVolumePreset.alto => 'Alto',
  };
}

/// Preferenze personali solo sul dispositivo, senza account o servizi remoti.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(
    this._tts, this._name, this._darkMode, this._voiceEnabled,
    this._remoteVolumePreset,
  );

  static const nameKey = 'padel_owner_first_name_v1';
  static const darkModeKey = 'padel_interface_dark_v1';
  static const voiceKey = 'padel_voice_enabled_v1';
  static const remoteVolumePresetKey = 'padel_remote_volume_preset_v1';

  final TtsService _tts;
  String _name;
  bool _darkMode;
  bool _voiceEnabled;
  RemoteVolumePreset _remoteVolumePreset;
  String get name => _name;
  bool get hasName => _name.trim().isNotEmpty;
  bool get darkMode => _darkMode;
  bool get voiceEnabled => _voiceEnabled;
  RemoteVolumePreset get remoteVolumePreset => _remoteVolumePreset;

  static Future<AppPreferences> load(TtsService tts) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(nameKey)?.trim() ?? '';
    final voice = prefs.getBool(voiceKey) ?? true;
    final storedPreset = prefs.getString(remoteVolumePresetKey);
    final remotePreset = RemoteVolumePreset.values.firstWhere(
      (candidate) => candidate.name == storedPreset,
      orElse: () => RemoteVolumePreset.alto,
    );
    tts.setMuted(!voice);
    return AppPreferences._(
      tts, name, prefs.getBool(darkModeKey) ?? true, voice, remotePreset,
    );
  }

  Future<bool> changeName(String input) async {
    final value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || value.length > 40) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(nameKey, value)) return false;
    _name = value;
    notifyListeners();
    return true;
  }

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (await prefs.setBool(darkModeKey, enabled)) {
      _darkMode = enabled;
      notifyListeners();
    }
  }

  Future<void> setRemoteVolumePreset(RemoteVolumePreset level) async {
    final prefs = await SharedPreferences.getInstance();
    if (await prefs.setString(remoteVolumePresetKey, level.name)) {
      _remoteVolumePreset = level;
      notifyListeners();
    }
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (await prefs.setBool(voiceKey, enabled)) {
      _voiceEnabled = enabled;
      _tts.setMuted(!enabled);
      notifyListeners();
    }
  }
}
