import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_service.dart';

/// Preferenze personali solo sul dispositivo, senza account o servizi remoti.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(this._tts, this._name, this._darkMode, this._voiceEnabled);

  static const nameKey = 'padel_owner_first_name_v1';
  static const darkModeKey = 'padel_interface_dark_v1';
  static const voiceKey = 'padel_voice_enabled_v1';

  final TtsService _tts;
  String _name;
  bool _darkMode;
  bool _voiceEnabled;
  String get name => _name;
  bool get hasName => _name.trim().isNotEmpty;
  bool get darkMode => _darkMode;
  bool get voiceEnabled => _voiceEnabled;

  static Future<AppPreferences> load(TtsService tts) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(nameKey)?.trim() ?? '';
    final voice = prefs.getBool(voiceKey) ?? true;
    tts.setMuted(!voice);
    return AppPreferences._(tts, name, prefs.getBool(darkModeKey) ?? true, voice);
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

  Future<void> setVoiceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (await prefs.setBool(voiceKey, enabled)) {
      _voiceEnabled = enabled;
      _tts.setMuted(!enabled);
      notifyListeners();
    }
  }
}
