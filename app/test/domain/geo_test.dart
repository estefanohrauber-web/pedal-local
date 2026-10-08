import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/geo_helpers.dart';

void main() {
  test('haversine: 1 grau de latitude ≈ 111,2 km', () {
    expectNear(haversine(const GeoPoint(0, 0), const GeoPoint(1, 0)), 111195, 1);
  });

  test('haversine: mesmo ponto = 0', () {
    expect(haversine(const GeoPoint(-23.5, -46.6), const GeoPoint(-23.5, -46.6)), 0);
  });

  test('cumulativeDistances acumula os trechos', () {
    final cum = cumulativeDistances(northLine(3, 20));
    expect(cum.length, 3);
    expect(cum[0], 0);
    expectNear(cum[1], 20, 0.01);
    expectNear(cum[2], 40, 0.01);
  });

  test('pointAt interpola no meio e limita nas pontas', () {
    final pts = northLine(2, 100);
    final cum = cumulativeDistances(pts);
    expectNear(pointAt(pts, cum, 50).lat, pts[0].lat + 50 / mPerDegLat, 1e-9);
    expectNear(pointAt(pts, cum, 500).lat, pts[1].lat, 1e-9);
    expect(pointAt(pts, cum, -5), pts[0]);
  });

  test('resample: linha de 100 m vira 6 pontos a cada 20 m', () {
    final out = resample(northLine(2, 100));
    expect(out.length, 6);
    final cum = cumulativeDistances(out);
    for (var i = 1; i < out.length; i++) {
      expectNear(cum[i] - cum[i - 1], 20, 0.01);
    }
  });

  test('resample: linha curta mantém início e fim', () {
    final pts = northLine(2, 15);
    expect(resample(pts), [pts[0], pts[1]]);
  });

  test('resample: último trecho nunca fica minúsculo', () {
    final cum = cumulativeDistances(resample(northLine(2, 101)));
    expect(cum.last - cum[cum.length - 2], greaterThanOrEqualTo(10));
  });
}
