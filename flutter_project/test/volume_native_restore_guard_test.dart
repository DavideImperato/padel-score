import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/volume_native_restore_guard.dart';

void main() {
  test('ripristino 0.65 -> 0.50 non produce impulsi', () {
    final guard = VolumeNativeRestoreGuard(target: 0.50);
    guard.begin(0.65);
    expect(guard.consume(0.60), isTrue);
    expect(guard.consume(0.55), isTrue);
    expect(guard.consume(0.50), isTrue);
    expect(guard.pending, isFalse);
  });

  test('pressione crescente durante ripristino non viene soppressa', () {
    final guard = VolumeNativeRestoreGuard(target: 0.50);
    guard.begin(0.55);
    expect(guard.consume(0.65), isFalse);
    expect(guard.consume(0.50), isTrue);
  });

  test('ripristino dal basso sopprime solo la direzione di ritorno', () {
    final guard = VolumeNativeRestoreGuard(target: 0.50);
    guard.begin(0.35);
    expect(guard.consume(0.30), isFalse);
    expect(guard.consume(0.40), isTrue);
    expect(guard.consume(0.50), isTrue);
  });

  test('una volta concluso il ripristino la successiva pressione e libera', () {
    final guard = VolumeNativeRestoreGuard(target: 0.50);
    guard.begin(0.60);
    expect(guard.consume(0.50), isTrue);
    expect(guard.consume(0.55), isFalse);
  });

  test('clear permette la disattivazione e la riattivazione', () {
    final guard = VolumeNativeRestoreGuard(target: 0.50);
    guard.begin(0.70);
    guard.clear();
    expect(guard.pending, isFalse);
    expect(guard.consume(0.50), isFalse);
  });
}
