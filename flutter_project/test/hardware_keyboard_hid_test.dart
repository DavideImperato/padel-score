import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/bluetooth_key_service.dart';

// Fase Apple 8B: il servizio iOS attende 650 ms dopo l'ultimo clic.
// Nei test aspettiamo 700 ms per far scadere il timer fake_async.
void main() {
  late BluetoothKeyService service;
  late List<String> actions;
  late bool inputEnabled;

  setUp(() {
    actions = <String>[];
    inputEnabled = true;
    service = BluetoothKeyService(
      keyboardOnlyOverride: true,
      isInputEnabled: () => inputEnabled,
      onTeamAPoint: () => actions.add('A'),
      onTeamBPoint: () => actions.add('B'),
      onUndo: () => actions.add('undo'),
      onAnnounceServer: () => actions.add('battitore'),
    );
    service.init();
  });

  tearDown(() {
    service.dispose();
  });

  Future<void> tap(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
  }

  testWidgets('HID: nessun punto prima della finestra iOS di 650 ms', (tester) async {
    await tap(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 600));
    expect(actions, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(actions, ['A']);
  });

  testWidgets('HID: un KeyDown/KeyUp produce un solo punto A', (tester) async {
    await tap(tester, LogicalKeyboardKey.space);
    expect(actions, isEmpty);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, ['A']);
  });

  testWidgets('HID: frecce, Enter e Space condividono la sequenza', (tester) async {
    await tap(tester, LogicalKeyboardKey.arrowUp);
    await tap(tester, LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, ['B']);
  });

  testWidgets('HID: tre pressioni danno Undo, senza punti intermedi', (tester) async {
    await tap(tester, LogicalKeyboardKey.space);
    await tap(tester, LogicalKeyboardKey.arrowDown);
    await tap(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, ['undo']);
  });

  testWidgets('HID: quattro pressioni annunciano il battitore subito', (tester) async {
    for (var i = 0; i < 4; i++) {
      await tap(tester, LogicalKeyboardKey.space);
    }
    expect(actions, ['battitore']);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, ['battitore']);
  });

  testWidgets('HID: KeyRepeat e KeyUp non aggiungono impulsi', (tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    HardwareKeyboard.instance.handleKeyEvent(KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: LogicalKeyboardKey.space,
      timeStamp: Duration.zero,
    ));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, ['A']);
  });

  testWidgets('HID: non utilizza audioVolumeUp/Down come input', (tester) async {
    await tap(tester, LogicalKeyboardKey.audioVolumeUp);
    await tap(tester, LogicalKeyboardKey.audioVolumeDown);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, isEmpty);
  });

  testWidgets('HID: conserva le scorciatoie dirette A, B e Undo', (tester) async {
    await tap(tester, LogicalKeyboardKey.keyA);
    await tap(tester, LogicalKeyboardKey.keyB);
    await tap(tester, LogicalKeyboardKey.escape);
    expect(actions, ['A', 'B', 'undo']);
  });

  testWidgets('HID: dialogo aperto disabilita le pressioni', (tester) async {
    inputEnabled = false;
    await tap(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, isEmpty);
    inputEnabled = true;
    await tap(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, ['A']);
  });

  testWidgets('HID: se il dialogo appare prima del timeout, non assegna punti', (tester) async {
    await tap(tester, LogicalKeyboardKey.space);
    inputEnabled = false;
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, isEmpty);
  });

  testWidgets('HID: dopo dispose non riceve altri eventi', (tester) async {
    service.dispose();
    await tap(tester, LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 700));
    expect(actions, isEmpty);
  });
}
