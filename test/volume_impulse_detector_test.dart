import 'package:flutter_test/flutter_test.dart';
import '../lib/services/volume_impulse_detector.dart';

void main() {
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
