import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ride_samples.dart';
import 'package:pedal_local/domain/ride_session.dart';

void main() {
  test('compacta e descompacta mantendo os valores', () {
    final original = [
      const RideSample(t: 1, distance: 6.5, speedKmh: 23.4, power: 150, cadence: 80, heartRate: 121),
      const RideSample(t: 2, distance: 13.1, speedKmh: 23.9, power: 155, cadence: 81),
    ];
    final back = unpackSamples(packSamples(original));
    expect(back.length, 2);
    expect(back[0].t, 1);
    expect(back[0].distance, closeTo(6.5, 1e-4));
    expect(back[0].speedKmh, closeTo(23.4, 1e-4));
    expect(back[0].heartRate, 121);
    expect(back[1].power, 155);
    expect(back[1].heartRate, isNull);
  });

  test('lista vazia', () {
    expect(unpackSamples(packSamples(const [])), isEmpty);
  });
}
