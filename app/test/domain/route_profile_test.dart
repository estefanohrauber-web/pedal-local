import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

// 5 % nos primeiros 100 m, depois plano.
RouteProfile perfil() => RouteProfile(northProfile([0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5]));

void main() {
  group('smoothElevations', () {
    List<double> cada20(int n) => [for (var i = 0; i < n; i++) i * 20.0];

    test('altitude constante não muda', () {
      for (final v in smoothElevations(cada20(6), [5, 5, 5, 5, 5, 5])) {
        expectNear(v, 5, 1e-9);
      }
    });

    test('ladeira reta continua reta, até nas pontas', () {
      final dists = cada20(30);
      final alts = [for (final d in dists) 600 + d * 0.08];
      final out = smoothElevations(dists, alts);
      for (var i = 0; i < out.length; i++) {
        expectNear(out[i], alts[i], 1e-6);
      }
    });

    test('ondinha de 5 m no plano quase some', () {
      final dists = cada20(41);
      final alts = [for (var i = 0; i < 41; i++) i == 20 ? 105.0 : 100.0];
      final out = smoothElevations(dists, alts);
      expect(out.reduce(math.max) - 100, lessThan(1));
    });

    test('ladeira de verdade (300 m a 10 %) fica perto de 10 % no meio', () {
      // 300 m plano, 300 m a 10 %, 300 m plano.
      final dists = cada20(46);
      final alts = [for (final d in dists) 100 + (d.clamp(300, 600) - 300) * 0.10];
      final p = RouteProfile(northProfile(smoothElevations(dists, alts)));
      expect(p.lookahead(350, 200), greaterThan(0.09));
      expectNear(p.gain, 30, 0.5);
    });
  });

  test('totais', () {
    final p = perfil();
    expectNear(p.distance, 200, 0.05);
    expectNear(p.gain, 5, 1e-9);
    expect(p.loss, 0);
  });

  test('inclinação por trecho', () {
    final p = perfil();
    expectNear(p.gradeAt(10), 0.05, 1e-4);
    expectNear(p.gradeAt(150), 0, 1e-9);
    expectNear(p.gradeAt(999), 0, 1e-9);
  });

  test('lookahead é a inclinação média à frente', () {
    final p = perfil();
    expectNear(p.lookahead(0, 100), 0.05, 1e-4);
    expectNear(p.lookahead(50, 100), 0.025, 1e-4);
    expectNear(p.lookahead(100, 100), 0, 1e-4);
    expect(p.lookahead(200, 200), 0);
  });

  test('altitude, posição e trecho percorrido', () {
    final p = perfil();
    expectNear(p.elevationAt(30), 1.5, 1e-4);
    expectNear(p.positionAt(40).lat, p.points[2].lat, 1e-9);
    final feito = p.traveled(50);
    expect(feito.length, 4); // 3 pontos inteiros + a posição atual
    expectNear(feito.last.lat, p.positionAt(50).lat, 1e-12);
  });

  test('inclinação limitada a ±20 %', () {
    expect(RouteProfile(northProfile([0, 10])).gradeAt(5), maxGrade);
    expect(RouteProfile(northProfile([10, 0])).gradeAt(5), -maxGrade);
  });

  test('rota de um ponto só não quebra', () {
    final p = RouteProfile(northProfile([7]));
    expect(p.distance, 0);
    expect(p.gradeAt(0), 0);
    expect(p.lookahead(0, 200), 0);
    expect(p.elevationAt(0), 7);
  });
}
