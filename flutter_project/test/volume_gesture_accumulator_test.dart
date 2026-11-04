import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/volume_gesture_accumulator.dart';

void main() {
  final base = DateTime.utc(2026, 11, 4, 12);

  testWidgets('un cambio volume produce un gesto singolo', (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    gestures.observe(timestamp: base);
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, [1]);
    gestures.reset();
  });

  testWidgets('due notifiche con salto +0.05 poi +0.10 contano due eventi',
      (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    gestures.observe(timestamp: base);
    await tester.pump(const Duration(milliseconds: 250));
    gestures.observe(timestamp: base.add(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, [2]);
    gestures.reset();
  });

  testWidgets('tre notifiche non vengono trasformate in quattro clic',
      (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    for (var n = 0; n < 3; n++) {
      gestures.observe(
          timestamp: base.add(Duration(milliseconds: 250 * n)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, [3]);
    gestures.reset();
  });

  testWidgets('quattro notifiche generano un solo gesto, solo dopo la pausa',
      (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    for (var n = 0; n < 4; n++) {
      gestures.observe(
          timestamp: base.add(Duration(milliseconds: 200 * n)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(output, isEmpty);
    }
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, [4]);
    gestures.reset();
  });

  testWidgets('autorepeat di hold ogni 43ms scartato: nessun punto fantasma',
      (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    gestures.observe(timestamp: base);
    await tester.pump(const Duration(milliseconds: 250));
    gestures.observe(timestamp: base.add(const Duration(milliseconds: 250)));
    for (var n = 1; n <= 9; n++) {
      await tester.pump(const Duration(milliseconds: 43));
      gestures.observe(timestamp: base.add(Duration(milliseconds: 250 + n * 43)));
    }
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, isEmpty);
    gestures.reset();
  });

  testWidgets('cinque notifiche contigue scartate anche se non rapidissime',
      (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    for (var n = 0; n < 5; n++) {
      gestures.observe(
          timestamp: base.add(Duration(milliseconds: n * 200)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, isEmpty);
    gestures.reset();
  });

  testWidgets('disattivazione prima del timeout non produce alcun comando',
      (tester) async {
    final output = <int>[];
    final gestures = VolumeGestureAccumulator(onGesture: output.add);
    gestures.observe(timestamp: base);
    gestures.reset();
    await tester.pump(const Duration(milliseconds: 651));
    expect(output, isEmpty);
  });
}
