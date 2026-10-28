import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/app_orientation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('Home e Configura partita richiedono soltanto portrait', () async {
    await AppOrientation.home();
    await AppOrientation.setup();
    final orientations = calls
        .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(orientations, hasLength(2));
    for (final call in orientations) {
      expect(call.arguments, ['DeviceOrientation.portraitUp']);
    }
  });

  test('Solo il tabellone richiede il landscape', () async {
    await AppOrientation.match();
    final orientation = calls.firstWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations');
    expect(orientation.arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });
}
