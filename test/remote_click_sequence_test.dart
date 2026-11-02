import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_scorebot/services/remote_click_sequence.dart';

void main() {
  test('1 impulso produce una sola azione dopo il timeout', () async {
    final actions = <int>[];
    final seq = RemoteClickSequence(
      gap: const Duration(milliseconds: 35), onSequence: actions.add);
    seq.impulse();
    expect(actions, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(actions, [1]);
    seq.cancel();
  });

  test('2 impulsi diventano una sola azione B, mai A+B', () async {
    final actions = <int>[];
    final seq = RemoteClickSequence(
      gap: const Duration(milliseconds: 60), onSequence: actions.add);
    seq.impulse();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    seq.impulse();
    expect(actions, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(actions, [2]);
    seq.cancel();
  });

  test('3 impulsi diventano Undo, senza punti intermedi', () async {
    final actions = <int>[];
    final seq = RemoteClickSequence(
      gap: const Duration(milliseconds: 55), onSequence: actions.add);
    for (var i = 0; i < 3; i++) {
      seq.impulse();
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(actions, [3]);
    seq.cancel();
  });

  test('4 impulsi completano subito l’annuncio battitore', () async {
    final actions = <int>[];
    final seq = RemoteClickSequence(
      gap: const Duration(milliseconds: 70), onSequence: actions.add);
    for (var i = 0; i < 4; i++) {
      seq.impulse();
    }
    expect(actions, [4]);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(actions, [4]);
    seq.cancel();
  });

  test('due sequenze separate restano due azioni', () async {
    final actions = <int>[];
    final seq = RemoteClickSequence(
      gap: const Duration(milliseconds: 30), onSequence: actions.add);
    seq.impulse();
    await Future<void>.delayed(const Duration(milliseconds: 75));
    seq.impulse();
    seq.impulse();
    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(actions, [1, 2]);
    seq.cancel();
  });

  test('cancel elimina ogni gesto pendente', () async {
    final actions = <int>[];
    final seq = RemoteClickSequence(
      gap: const Duration(milliseconds: 30), onSequence: actions.add);
    seq.impulse();
    seq.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(actions, isEmpty);
  });
}
