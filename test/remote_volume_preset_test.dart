import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel_scorebot/services/app_preferences.dart';
import 'support/fake_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preset telecomando: default Alto e valori corretti', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await AppPreferences.load(FakeTtsService());
    expect(preferences.remoteVolumePreset, RemoteVolumePreset.alto);
    expect(RemoteVolumePreset.basso.systemVolume, 0.2);
    expect(RemoteVolumePreset.medio.systemVolume, 0.5);
    expect(RemoteVolumePreset.alto.systemVolume, 0.9);
    preferences.dispose();
  });

  test('preset telecomando salvato tra avvii', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppPreferences.load(FakeTtsService());
    await first.setRemoteVolumePreset(RemoteVolumePreset.basso);
    expect(first.remoteVolumePreset, RemoteVolumePreset.basso);
    first.dispose();

    final second = await AppPreferences.load(FakeTtsService());
    expect(second.remoteVolumePreset, RemoteVolumePreset.basso);
    await second.setRemoteVolumePreset(RemoteVolumePreset.medio);
    second.dispose();

    final third = await AppPreferences.load(FakeTtsService());
    expect(third.remoteVolumePreset, RemoteVolumePreset.medio);
    third.dispose();
  });
}
