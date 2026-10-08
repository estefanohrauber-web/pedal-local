import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/loop_geometry.dart';

import '../support/geo_helpers.dart';

void main() {
  const casa = GeoPoint(-27.19, -51.49);

  test('ponto a uma distância e rumo', () {
    final norte = destinationPoint(casa, 0, 1000);
    expectNear(haversine(casa, norte), 1000, 0.5);
    expect(norte.lat, greaterThan(casa.lat));
    expectNear(norte.lon, casa.lon, 1e-9);
    final leste = destinationPoint(casa, math.pi / 2, 500);
    expectNear(haversine(casa, leste), 500, 0.5);
    expect(leste.lon, greaterThan(casa.lon));
  });

  test('volta em círculo: começa e termina na partida, com 3 pontos no círculo', () {
    final pontos = loopWaypoints(casa, bearingRad: 0, radiusM: 800);
    expect(pontos.length, 5);
    expect(pontos.first, casa);
    expect(pontos.last, casa);
    final centro = destinationPoint(casa, 0, 800);
    for (final p in pontos.sublist(1, 4)) {
      expectNear(haversine(centro, p), 800, 1);
    }
    // O ponto do meio fica do outro lado do círculo: a 2 raios da partida, para o norte.
    expectNear(haversine(casa, pontos[2]), 1600, 2);
    expect(pontos[2].lat, greaterThan(casa.lat));
  });

  test('raio inicial e ajuste pela distância que deu', () {
    expectNear(initialLoopRadius(10000), 10000 / (2 * math.pi) * 0.75, 1e-9);
    expectNear(adjustLoopRadius(1000, targetM: 10000, lengthM: 12500), 800, 1e-9);
    expect(loopCloseEnough(10900, 10000), isTrue);
    expect(loopCloseEnough(11200, 10000), isFalse);
  });

  test('rumos espalhados em volta', () {
    expect(loopBearings(3).length, 3);
    expectNear(loopBearings(3)[1], 2 * math.pi / 3, 1e-12);
    expect(loopBearings(6).length, 6);
  });

  test('sobreposição de dois caminhos', () {
    final a = northLine(11, 100); // 1 km para o norte
    final b = northLine(6, 100); // a primeira metade
    expectNear(overlapFraction(b, a), 1, 1e-9);
    expectNear(overlapFraction(a, b), 6 / 11, 1e-9);
    final longe = northLine(5, 100, start: const GeoPoint(-23.6, -46.6));
    expect(overlapFraction(a, longe), 0);
  });

  test('procura do raio: regra de três e, com volta curta e longa, o meio', () {
    final busca = LoopRadiusSearch(5000);
    final r0 = busca.radius;
    busca.record(4000); // curta: aumenta
    expectNear(busca.radius, r0 * 5000 / 4000, 1e-9);
    final r1 = busca.radius;
    busca.record(7000); // longa: agora tem as duas, tenta o meio
    expectNear(busca.radius, (r0 + r1) / 2, 1e-9);
    busca.record(6000); // ainda longa: o meio entre a curta e esta
    expectNear(busca.radius, (r0 + (r0 + r1) / 2) / 2, 1e-9);
  });
}
