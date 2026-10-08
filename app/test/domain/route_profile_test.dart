import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

// 5 % nos primeiros 100 m, depois plano.
RouteProfile perfil() => RouteProfile(northProfile([0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5]));

void main() {
  test('smoothElevations: média móvel centrada', () {
    final out = smoothElevations([0, 0, 10, 0, 0], 3);
    for (final (i, v) in [0.0, 10 / 3, 10 / 3, 10 / 3, 0.0].indexed) {
      expectNear(out[i], v, 1e-9);
    }
  });

  test('smoothElevations: altitude constante não muda', () {
    expect(smoothElevations([5, 5, 5, 5, 5, 5]), [5, 5, 5, 5, 5, 5]);
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
