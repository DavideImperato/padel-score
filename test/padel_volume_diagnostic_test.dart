import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_volume_diagnostic/padel_volume_diagnostic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('padel_volume_diagnostic');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'read') return 0.75;
      if (call.method == 'write') {
        return <String, Object>{
          'requested': 0.5,
          'before': 0.75,
          'observed': 0.5,
          'confirmed': true,
          'sliderValue': 0.5,
        };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('legge il livello volume dal canale nativo', () async {
    expect(await PadelVolumeDiagnostic.read(), 0.75);
    expect(calls.single.method, 'read');
  });

  test('conferma i valori riportati dal plugin nativo', () async {
    final write = await PadelVolumeDiagnostic.write(0.5);
    expect(write.confirmed, isTrue);
    expect(write.before, 0.75);
    expect(write.observed, 0.5);
    expect(calls.single.arguments, {'volume': 0.5});
  });

  test('rifiuta livelli fuori intervallo prima di chiamare iOS', () async {
    await expectLater(
      PadelVolumeDiagnostic.write(1.2),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
}
