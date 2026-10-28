import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/watch_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('padel_score_board/watch_link');
  const service = WatchLinkService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('stato connessione decodifica tutti i flag e il ping ricevuto', () {
    final state = WatchLinkStatus.fromMap({
      'supported': true,
      'activated': true,
      'paired': true,
      'installed': true,
      'reachable': true,
      'lastWatchPing': 1760000000000,
    });
    expect(state.reachable, isTrue);
    expect(state.label, 'Apple Watch raggiungibile');
    expect(state.lastWatchPing?.millisecondsSinceEpoch, 1760000000000);
  });

  test('i flag assenti non vengono interpretati come connessione valida', () {
    final state = WatchLinkStatus.fromMap({});
    expect(state.supported, isFalse);
    expect(state.reachable, isFalse);
    expect(state.label, 'Disponibile solo su iPhone');
  });

  test('il servizio invia activate/status sui metodi previsti', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'supported': true, 'activated': true, 'paired': false,
        'installed': false, 'reachable': false};
    });
    final active = await service.activate();
    final status = await service.status();
    expect(calls, ['activate', 'getStatus']);
    expect(active.activated, isTrue);
    expect(status.paired, isFalse);
  });

  test('ping restituisce la latenza e non genera comandi di punteggio', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'ping');
      return {'ok': true, 'roundTripMs': 18};
    });
    expect(await service.ping(), 18);
  });

  test('ping rifiuta risposte prive di conferma', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => {'ok': false});
    expect(service.ping(), throwsFormatException);
  });
}
