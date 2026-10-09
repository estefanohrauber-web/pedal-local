import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/structures.dart';

import '../support/geo_helpers.dart';

void main() {
  // 1 km para o norte, um ponto a cada 20 m (como as rotas salvas): o ponto i fica a 20·i m.
  final linha = northLine(51, 20);
  final cum = cumulativeDistances(linha);

  test('ponte no caminho casado vira metros ao longo da rota', () {
    // O caminho casado tem outros vértices: 0, 100, 300, 600 e 1000 m.
    final casado = northLine(11, 100);
    final shape = [casado[0], casado[1], casado[3], casado[6], casado[10]];
    final spans = structureSpans(linha, shape, [(begin: 2, end: 3)]);
    expect(spans.length, 1);
    expectNear(spans.first.start, 300, 1);
    expectNear(spans.first.end, 600, 1);
  });

  test('ida e volta pela mesma ponte: cada passagem fica no seu lugar', () {
    final rota = [
      ...linha,
      ...linha.reversed.skip(1),
    ]; // 2 km, volta pelo mesmo caminho
    final casado = northLine(11, 100);
    final shape = [
      casado[0],
      casado[3],
      casado[6],
      casado[10],
      casado[6],
      casado[3],
      casado[0],
    ];
    final spans = structureSpans(rota, shape, [
      (begin: 1, end: 2),
      (begin: 4, end: 5),
    ]);
    expect(spans.length, 2);
    expectNear(spans[0].start, 300, 1);
    expectNear(spans[0].end, 600, 1);
    expectNear(spans[1].start, 1400, 1);
    expectNear(spans[1].end, 1700, 1);
  });

  test('ponte vira reta entre as cabeceiras; o resto fica igual', () {
    // Terreno descendo devagar de 540 m, com o vale do rio (até 500 m) embaixo da ponte (300 a 600 m).
    final alts = [
      for (var i = 0; i < cum.length; i++)
        i >= 15 && i <= 30 ? 500 + (i - 22.5).abs() * 4 : 540.0 - i / 5,
    ];
    final novas = flattenStructures(cum, alts, [const StructureSpan(300, 600)]);
    // Cabeceiras a 10 m para fora da ponte: o último ponto antes de 290 m (280 m, i = 14) e o
    // primeiro depois de 610 m (620 m, i = 31).
    const a = 14;
    const b = 31;
    for (var i = 0; i < cum.length; i++) {
      if (i <= a || i >= b) {
        expect(novas[i], alts[i]);
      } else {
        final t = (cum[i] - cum[a]) / (cum[b] - cum[a]);
        expectNear(novas[i], alts[a] + (alts[b] - alts[a]) * t, 1e-9);
      }
    }
    expect(novas.sublist(a, b + 1).reduce(math.min), greaterThan(533));
  });

  test(
    'pontes coladas viram uma reta só (a cabeceira não cai no vale do meio)',
    () {
      final alts = [
        for (var i = 0; i < cum.length; i++) i >= 15 && i <= 35 ? 500.0 : 540.0,
      ];
      final novas = flattenStructures(cum, alts, [
        const StructureSpan(300, 500),
        const StructureSpan(512, 700),
      ]);
      for (var i = 0; i < cum.length; i++) {
        expectNear(novas[i], 540, 1e-9);
      }
    },
  );

  test('ponte logo no começo ou no fim da rota usa a primeira ou a última altitude', () {
    final alts = [
      for (var i = 0; i < cum.length; i++) i < 5 || i > 45 ? 500.0 : 540.0,
    ];
    final novas = flattenStructures(cum, alts, [
      const StructureSpan(0, 85),
      const StructureSpan(915, 1000),
    ]);
    expect(novas.first, 500);
    expect(novas.last, 500);
    expect(novas[5], 540);
    expect(novas[45], 540);
    expectNear(novas[2], 500 + 40 * cum[2] / cum[5], 1e-9);
  });

  test('sem pontes, nada muda', () {
    final alts = [for (var i = 0; i < cum.length; i++) 500.0 + i];
    expect(flattenStructures(cum, alts, const []), alts);
  });
}
