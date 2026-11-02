import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'padel_native_volume_probe.dart' as probe;
import 'services/app_orientation.dart';
import 'services/tts_service.dart';

const String _mode = String.fromEnvironment(
  'VOLUME_COMPARE',
  defaultValue: 'tts',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_mode.startsWith('tts')) {
    await TtsService().init();
  }

  if (_mode.contains('landscape')) {
    await AppOrientation.match();
  }

  if (_mode.contains('immersive')) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  probe.main();
}
