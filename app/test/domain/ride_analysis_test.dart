import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ride_analysis.dart';
import 'package:pedal_local/domain/ride_session.dart';

RideSample s(int i, {double v = 30, double p = 200, double c = 80, double? fc}) =>
    RideSample(t: i.toDouble(), distance: i * 8.0, speedKmh: v, power: p, cadence: c, heartRate: fc);

void main() {
  test('valores de cada métrica, suavizados em 5 s', () {
    final amostras = [for (var i = 1; i <= 9; i++) s(i, p: i == 5 ? 700 : 200)];
    final pot = metricSeries(amostras, RideMetric.potencia);
    expect(pot.length, 9);
    expect(pot[4], closeTo((200 * 4 + 700) / 5, 1e-9)); // o pico é diluído pela média de 5 s
    expect(pot.first, closeTo(200, 1e-9));
  });

  test('inclinação vem do relevo pela distância', () {
    final amostras = [for (var i = 1; i <= 3; i++) s(i)];
    final g = metricSeries(amostras, RideMetric.inclinacao, gradeAt: (d) => d < 12 ? 0.05 : -0.02, window: 1);
    expect(g, [5.0, -2.0, -2.0]);
  });

  test('FC só existe quando a bike ou a cinta mandou', () {
    expect(availableMetrics([s(1), s(2)]), [RideMetric.velocidade, RideMetric.potencia, RideMetric.cadencia]);
    expect(availableMetrics([s(1), s(2)], hasTerrain: true), contains(RideMetric.inclinacao));
    expect(availableMetrics([s(1, fc: 120), s(2, fc: 125)]), contains(RideMetric.fc));
  });

  test('faixa da escala ignora picos isolados (percentis 5 e 95)', () {
    final valores = [for (var i = 0; i < 100; i++) i.toDouble(), 10000.0];
    final (lo, hi) = colorRange(valores);
    expect(lo, closeTo(5, 1.5));
    expect(hi, closeTo(95, 1.5));
  });

  test('faixa constante não divide por zero', () {
    final (lo, hi) = colorRange([7, 7, 7]);
    expect(hi, greaterThan(lo));
    expect(normalize(7, lo, hi), inInclusiveRange(0, 1));
  });

  test('normaliza entre 0 e 1 com limite nas pontas', () {
    expect(normalize(50, 0, 100), 0.5);
    expect(normalize(-5, 0, 100), 0);
    expect(normalize(500, 0, 100), 1);
  });

  test('nomes e unidades das métricas', () {
    expect(RideMetric.velocidade.label, 'Velocidade');
    expect(RideMetric.velocidade.unit, 'km/h');
    expect(RideMetric.potencia.unit, 'W');
    expect(RideMetric.inclinacao.unit, '%');
  });
}
