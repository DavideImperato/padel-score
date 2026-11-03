import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'padel_native_volume_probe.dart' as probe;

const audioCase = String.fromEnvironment(
  'AUDIO_CASE',
  defaultValue: 'basic',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[AudioIsolation] CASE=$audioCase');

  if (audioCase == 'baseline') {
    probe.main();
    return;
  }

  final tts = FlutterTts();

  await tts.setLanguage('it-IT');
  await tts.setSpeechRate(0.48);
  await tts.setVolume(0.6);
  await tts.setPitch(1.0);

  if (audioCase == 'ambient') {
    await tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.ambient,
      [],
      IosTextToSpeechAudioMode.defaultMode,
    );
  } else if (audioCase != 'basic') {
    final options = <IosTextToSpeechAudioCategoryOptions>[];

    if (['mix', 'duck', 'voiceprompt'].contains(audioCase)) {
      options.add(
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      );
    }

    if (['duck', 'voiceprompt'].contains(audioCase)) {
      options.add(
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      );
    }

    await tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      options,
      audioCase == 'voiceprompt'
          ? IosTextToSpeechAudioMode.voicePrompt
          : IosTextToSpeechAudioMode.defaultMode,
    );
  }

  await tts.awaitSpeakCompletion(true);

  debugPrint('[AudioIsolation] CONFIGURAZIONE COMPLETATA');
  probe.main();
}
