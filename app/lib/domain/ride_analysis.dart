import 'dart:math' as math;

import 'ride_session.dart';

/// O que dá para pintar no mapa e no gráfico do pedal.
enum RideMetric {
  velocidade('Velocidade', 'km/h'),
  potencia('Potência', 'W'),
  cadencia('Cadência', 'rpm'),
  inclinacao('Inclinação', '%'),
  fc('Frequência cardíaca', 'bpm');

  const RideMetric(this.label, this.unit);

  final String label;
  final String unit;
}

/// Métricas que este pedal tem dados para mostrar.
List<RideMetric> availableMetrics(List<RideSample> samples, {bool hasTerrain = false}) => [
      RideMetric.velocidade,
      RideMetric.potencia,
      RideMetric.cadencia,
      if (hasTerrain) RideMetric.inclinacao,
      if (samples.any((s) => s.heartRate != null)) RideMetric.fc,
    ];

double? _bruto(RideSample s, RideMetric m, double Function(double d)? gradeAt) => switch (m) {
      RideMetric.velocidade => s.speedKmh,
      RideMetric.potencia => s.power,
      RideMetric.cadencia => s.cadence,
      RideMetric.inclinacao => gradeAt == null ? null : gradeAt(s.distance) * 100,
      RideMetric.fc => s.heartRate,
    };

/// Valor da métrica em cada amostra, com média móvel centrada de [window] amostras (1 s cada).
/// Amostras sem o dado repetem o vizinho; sem nenhum dado, tudo zero.
List<double> metricSeries(
  List<RideSample> samples,
  RideMetric metric, {
  double Function(double d)? gradeAt,
  int window = 5,
}) {
  final brutos = [for (final s in samples) _bruto(s, metric, gradeAt)];
  final primeiro = brutos.firstWhere((v) => v != null, orElse: () => 0) ?? 0;
  var anterior = primeiro;
  final cheios = [for (final v in brutos) anterior = v ?? anterior];
  final meio = window ~/ 2;
  return [
    for (var i = 0; i < cheios.length; i++)
      () {
        var soma = 0.0;
        var n = 0;
        for (var j = math.max(0, i - meio); j <= math.min(cheios.length - 1, i + meio); j++) {
          soma += cheios[j];
          n++;
        }
        return soma / n;
      }(),
  ];
}

double _percentil(List<double> ordenados, double p) {
  final pos = p * (ordenados.length - 1);
  final i = pos.floor();
  final j = math.min(ordenados.length - 1, i + 1);
  return ordenados[i] + (ordenados[j] - ordenados[i]) * (pos - i);
}

/// Faixa da escala de cores: percentis 5 e 95, para um pico isolado não apagar o resto.
(double, double) colorRange(List<double> values) {
  if (values.isEmpty) return (0, 1);
  final ordenados = List.of(values)..sort();
  var lo = _percentil(ordenados, 0.05);
  var hi = _percentil(ordenados, 0.95);
  if (hi - lo < 1e-6) {
    lo -= 0.5;
    hi += 0.5;
  }
  return (lo, hi);
}

/// Posição do valor na escala: 0 (azul, menor) a 1 (vermelho, maior).
double normalize(double v, double lo, double hi) => hi <= lo ? 0.5 : ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
