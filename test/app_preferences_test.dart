import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/services/app_preferences.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nome salvato offline, tema e annunci vocali persistenti', () async {
    SharedPreferences.setMockInitialValues({});
    final firstVoice = FakeTtsService();
    final first = await AppPreferences.load(firstVoice);
    expect(first.hasName, false);
    expect(await first.changeName('  Gaia  '), true);
    expect(first.name, 'Gaia');
    await first.setDarkMode(false);
    await first.setVoiceEnabled(false);
    expect(firstVoice.isMuted, true);

    final reopenedVoice = FakeTtsService();
    final reopened = await AppPreferences.load(reopenedVoice);
    expect(reopened.name, 'Gaia');
    expect(reopened.darkMode, false);
    expect(reopened.voiceEnabled, false);
    expect(reopenedVoice.isMuted, true);
    expect(await reopened.changeName(' '), false);
    expect(reopened.name, 'Gaia');
    first.dispose();
    reopened.dispose();
  });
}
