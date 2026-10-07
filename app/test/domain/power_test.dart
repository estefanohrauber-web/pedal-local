import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/power.dart';

final t0 = DateTime(2026, 10, 7, 20);
DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

void main() {
  test('estimatePower: nível 4 a 80 rpm ≈ 128 W', () {
    expect(estimatePower(80, 4), 128);
  });

  test('estimatePower: sem cadência = 0', () {
    expect(estimatePower(0, 4), 0);
    expect(estimatePower(null, 4), 0);
  });

  test('estimatePower: calibração personalizada', () {
    expect(estimatePower(80, 4, const PowerCalibration(base: 1, factor: 0)), 80);
  });

  test('modo bike: usa a potência recebida, 0 se não vier', () {
    final r = PowerResolver(mode: PowerMode.bike);
    expect(r.resolve(cadence: 80, power: 150, timestamp: at(0), level: 4), 150);
    expect(r.resolve(cadence: 80, power: null, timestamp: at(1000), level: 4), 0);
  });

  test('modo estimada: ignora a potência da bike', () {
    final r = PowerResolver(mode: PowerMode.estimada);
    expect(r.resolve(cadence: 80, power: 300, timestamp: at(0), level: 4), 128);
    expect(r.effectiveMode, PowerMode.estimada);
  });

  test('auto com potência válida: usa a da bike', () {
    final r = PowerResolver();
    expect(r.resolve(cadence: 80, power: 150, timestamp: at(0), level: 4), 150);
    expect(r.effectiveMode, PowerMode.bike);
  });

  test('auto sem potência por 10 s: troca para estimada de vez', () {
    final r = PowerResolver();
    for (var t = 0; t <= 9000; t += 1000) {
      expect(r.resolve(cadence: 80, power: null, timestamp: at(t), level: 4), 128);
    }
    expect(r.switchedToEstimate, isFalse);
    r.resolve(cadence: 80, power: 0, timestamp: at(10000), level: 4);
    expect(r.switchedToEstimate, isTrue);
    expect(r.effectiveMode, PowerMode.estimada);
    expect(r.resolve(cadence: 80, power: 300, timestamp: at(11000), level: 4), 128);
  });

  test('auto: parar de pedalar zera a contagem dos 10 s', () {
    final r = PowerResolver();
    for (var t = 0; t <= 5000; t += 1000) {
      r.resolve(cadence: 80, power: null, timestamp: at(t), level: 4);
    }
    expect(r.resolve(cadence: 0, power: null, timestamp: at(6000), level: 4), 0);
    for (var t = 7000; t <= 15000; t += 1000) {
      r.resolve(cadence: 80, power: null, timestamp: at(t), level: 4);
    }
    expect(r.switchedToEstimate, isFalse);
    r.resolve(cadence: 80, power: null, timestamp: at(17000), level: 4);
    expect(r.switchedToEstimate, isTrue);
  });
}
