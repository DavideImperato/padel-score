import 'package:flutter_test/flutter_test.dart';
import '../lib/services/volume_impulse_detector.dart';

void main() {
  groupedVolumeTests();
  test('baseline non genera clic', () {
    final detector = VolumeImpulseDetector();
    expect(detector.accept(.8), false);
    expect(detector.accept(.8), false);
  });

  test('variazioni piccole in entrambe le direzioni generano impulsi', () {
    final detector = VolumeImpulseDetector()..reset(.8);
    expect(detector.accept(.8625), true);
    expect(detector.accept(.8), true);
  });

  test('duplicati e rumore floating point sono ignorati', () {
    final detector = VolumeImpulseDetector()..reset(.8);
    expect(detector.accept(.800001), false);
    expect(detector.accept(.8), false);
  });

  test('salti ampi e valori invalidi sono ignorati', () {
    final detector = VolumeImpulseDetector()..reset(.8);
    expect(detector.accept(.2), false);
    expect(detector.accept(double.nan), false);
    expect(detector.accept(-1), false);
    expect(detector.accept(2), false);
    expect(detector.accept(.2625), true);
  });

  test('agli estremi non inventa pressioni quando il volume e invariato', () {
    final detector = VolumeImpulseDetector()..reset(1);
    expect(detector.accept(1), false);
    expect(detector.accept(.9375), true);
    expect(detector.accept(.9375), false);
  });

  test('reset cancella il riferimento precedente', () {
    final detector = VolumeImpulseDetector()..reset(.6);
    detector.reset();
    expect(detector.accept(.7), false);
    expect(detector.accept(.7625), true);
  });
  test('STREAM e GET con lo stesso volume valgono come un solo impulso', () {
    final detector = VolumeImpulseDetector()..reset(.5);
    expect(detector.accept(.5625), true); // STREAM
    expect(detector.accept(.5625), false); // GET duplicato
    expect(detector.accept(.625), true); // successiva pressione
    expect(detector.accept(.625), false); // STREAM/GET duplicato
  });

}

// Fase Apple 8B: i callback del volume possono accorpare piu' pressioni.
// Verifichiamo il conteggio dei passi separatamente dai canali iOS nativi.
void groupedVolumeTests() {
  test('2 pressioni accorpate in una notifica valgono due impulsi', () {
    final detector = VolumeImpulseDetector()..reset(.5);
    expect(detector.countSteps(.625), 2);
    expect(detector.countSteps(.625), 0);
  });

  test('4 pressioni accorpate in una notifica valgono quattro impulsi', () {
    final detector = VolumeImpulseDetector()..reset(.5);
    expect(detector.countSteps(.75), 4);
    expect(detector.countSteps(.75), 0);
  });

  test('STREAM e GET insieme non duplicano quattro pressioni', () {
    final detector = VolumeImpulseDetector()..reset(.5);
    expect(detector.countSteps(.5625), 1);
    expect(detector.countSteps(.625), 1);
    expect(detector.countSteps(.625), 0);
    expect(detector.countSteps(.75), 2);
    expect(detector.countSteps(.75), 0);
  });

  test('salti ampi non vengono interpretati come click', () {
    final detector = VolumeImpulseDetector()..reset(.5);
    expect(detector.countSteps(.9), 0);
    expect(detector.countSteps(.9), 0);
  });
  test('iOS reale: incrementi di 0.05 riconosciuti come singoli', () {
    final detector = VolumeImpulseDetector()..reset(.65);
    expect(detector.countSteps(.70), 1);
    expect(detector.countSteps(.75), 1);
    expect(detector.countSteps(.80), 1);
    expect(detector.countSteps(.85), 1);
  });

  test('iOS reale: due incrementi 0.05 accorpati non sono ignorati', () {
    final detector = VolumeImpulseDetector()..reset(.75);
    expect(detector.countSteps(.85), 2);
    expect(detector.countSteps(.85), 0);
  });

  test('iOS reale: tre e quattro incrementi 0.05 accorpati', () {
    final three = VolumeImpulseDetector()..reset(.65);
    final four = VolumeImpulseDetector()..reset(.65);
    expect(three.countSteps(.80), 3);
    expect(four.countSteps(.85), 4);
  });

  test('variazioni non compatibili e micro-rumore sono scartati', () {
    final detector = VolumeImpulseDetector()..reset(.65);
    expect(detector.countSteps(.652), 0);
    expect(detector.countSteps(.681), 0);
    expect(detector.countSteps(.95), 0);
  });

}
