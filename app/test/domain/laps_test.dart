import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/laps.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

/// Uma amostra por segundo a [v] m/s e [watts] constantes.
List<RideSample> amostras(int segundos, {double v = 10, double watts = 200}) => [
      for (var i = 1; i <= segundos; i++)
        RideSample(t: i.toDouble(), distance: i * v, speedKmh: v * 3.6, power: watts, cadence: 80),
    ];

void main() {
  group('terreno da volta', () {
    final volta = RouteProfile(squareLoop(200, alts: (i) => 700.0 + (i <= 20 ? i : 40 - i)));

    test('não tem fim e repete a inclinação a cada volta', () {
      final t = LoopTerrain(volta);
      expect(t.distance, double.infinity);
      expect(t.lapLength, closeTo(800, 1));
      expect(t.gradeAt(100), t.gradeAt(100 + t.lapLength));
      expect(t.gradeAt(100), greaterThan(0));
    });

    test('voltas completas', () {
      final t = LoopTerrain(volta);
      expect(t.lapsAt(0), 0);
      expect(t.lapsAt(t.lapLength - 1), 0);
      expect(t.lapsAt(t.lapLength), 1);
      expect(t.lapsAt(2.5 * t.lapLength), 2);
    });

    test('subida acumulada soma as voltas', () {
      final t = LoopTerrain(volta);
      expectNear(t.climbedUpTo(t.lapLength), volta.climbedUpTo(volta.distance), 0.01);
      expectNear(t.climbedUpTo(2 * t.lapLength), 2 * volta.climbedUpTo(volta.distance), 0.01);
    });
  });

  group('tempo na distância', () {
    test('interpola entre as amostras', () {
      expect(timeAtDistance(amostras(10), 25), closeTo(2.5, 1e-9));
      expect(timeAtDistance(amostras(10), 0), 0);
      expect(timeAtDistance(amostras(10), 1000), 10);
    });

    test('tempos de cada volta, com a última incompleta', () {
      expect(lapTimes(amostras(25), 100), [10, 10, 5]);
      expect(lapTimes(amostras(20), 100), [10, 10]);
    });
  });

  group('corte na margem', () {
    test('passou até a margem: corta na volta fechada', () {
      final c = closeLap(samples: amostras(21), lapLength: 100, margin: 0.1, climbedUpTo: (d) => d / 10)!;
      expect(c.laps, 2);
      expect(c.distance, 200);
      expect(c.trimmed, closeTo(10, 1e-9));
      expect(c.movingTime, closeTo(20, 1e-9));
      expect(c.samples.last.distance, 200);
      expect(c.samples.length, 20);
      expect(c.avgPower, closeTo(200, 1e-9));
      expect(c.kcal, closeTo(200 * 20 / 1000, 1e-9));
      expect(c.avgSpeedKmh, closeTo(36, 1e-9));
      expect(c.climbed, closeTo(20, 1e-9));
    });

    test('passou mais que a margem: não corta', () {
      expect(closeLap(samples: amostras(25), lapLength: 100, margin: 0.03, climbedUpTo: (d) => 0), isNull);
    });

    test('sem volta completa não corta', () {
      expect(closeLap(samples: amostras(5), lapLength: 100, margin: 0.5, climbedUpTo: (d) => 0), isNull);
    });

    test('margem zero só fecha se parou exatamente na volta', () {
      expect(closeLap(samples: amostras(21), lapLength: 100, margin: 0, climbedUpTo: (d) => 0), isNull);
    });
  });

  group('trechos por volta', () {
    test('separa as amostras de cada volta, com a última parcial', () {
      final fatias = lapSlices(amostras(25), 100);
      expect(fatias.map((f) => f.start), [0, 100, 200]);
      expect(fatias.map((f) => f.samples.length), [10, 10, 5]);
      expect(fatias.first.samples.last.distance, 100);
      expect(fatias.last.complete, isFalse);
      expect(fatias.first.complete, isTrue);
    });

    test('ida ou pedal livre: um trecho só', () {
      final fatias = lapSlices(amostras(7), double.infinity);
      expect(fatias.length, 1);
      expect(fatias.single.length, 70);
    });
  });
}
