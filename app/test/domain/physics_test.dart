import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/physics.dart';

double kmh(double ms) => ms * 3.6;

double simulate(
  double v0, {
  required double powerW,
  required double grade,
  required double seconds,
  void Function(double v)? onStep,
}) {
  var v = v0;
  for (var t = 0.0; t < seconds; t += physicsDt) {
    v = stepSpeed(v, powerW: powerW, grade: grade, riderMassKg: 75);
    onStep?.call(v);
  }
  return v;
}

void main() {
  test('plano, 150 W: entre 28 e 32 km/h', () {
    expect(kmh(simulate(0, powerW: 150, grade: 0, seconds: 300)), inInclusiveRange(28, 32));
  });

  test('subida de 6 %, 150 W: entre 8 e 12 km/h', () {
    expect(kmh(simulate(0, powerW: 150, grade: 0.06, seconds: 300)), inInclusiveRange(8, 12));
  });

  test('descida de 5 % sem pedalar: passa de 30 km/h', () {
    expect(kmh(simulate(0, powerW: 0, grade: -0.05, seconds: 120)), greaterThan(30));
  });

  test('plano sem pedalar a partir de 30 km/h: abaixo de 12 km/h em 60 s', () {
    expect(kmh(simulate(30 / 3.6, powerW: 0, grade: 0, seconds: 60)), lessThan(12));
  });

  test('subida íngreme sem pedalar: para e nunca fica negativa', () {
    var menor = double.infinity;
    final v = simulate(5, powerW: 0, grade: 0.15, seconds: 10, onStep: (x) {
      if (x < menor) menor = x;
    });
    expect(v, 0);
    expect(menor, greaterThanOrEqualTo(0));
  });

  test('velocidade máxima limitada', () {
    expect(simulate(0, powerW: 0, grade: -0.2, seconds: 600), lessThanOrEqualTo(physics.maxSpeedMs));
  });
}
