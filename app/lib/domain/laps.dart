import 'dart:math' as math;

import 'ride_session.dart';
import 'route_profile.dart';

/// Volta fechada: o relevo se repete a cada volta e o pedal não termina sozinho.
class LoopTerrain implements Terrain {
  LoopTerrain(this.lap);

  final RouteProfile lap;

  double get lapLength => lap.distance;

  @override
  double get distance => double.infinity;

  double _pos(double d) => lapLength <= 0 ? 0 : d - lapsAt(d) * lapLength;

  /// Voltas completas até a distância [d].
  int lapsAt(double d) => lapLength <= 0 ? 0 : (d / lapLength + 1e-9).floor();

  @override
  double gradeAt(double d) => lap.gradeAt(_pos(d));

  @override
  double lookahead(double d, double span) =>
      span > 1 ? (lap.elevationAt(_pos(d + span)) - lap.elevationAt(_pos(d))) / span : 0;

  double climbedUpTo(double d) => lapsAt(d) * lap.climbedUpTo(lapLength) + lap.climbedUpTo(_pos(d));
}

/// Tempo em movimento (s) quando o pedal passou pela distância [d], interpolando as amostras.
double timeAtDistance(List<RideSample> samples, double d) {
  var t0 = 0.0;
  var d0 = 0.0;
  for (final s in samples) {
    if (s.distance >= d) {
      final run = s.distance - d0;
      return run > 0 ? t0 + (s.t - t0) * (d - d0) / run : s.t;
    }
    t0 = s.t;
    d0 = s.distance;
  }
  return samples.isEmpty ? 0 : samples.last.t;
}

/// Tempo de cada volta; a última entra mesmo incompleta (se andou alguma coisa nela).
List<double> lapTimes(List<RideSample> samples, double lapLength) {
  if (samples.isEmpty || lapLength <= 0) return const [];
  final total = samples.last.distance;
  final tempos = <double>[];
  var antes = 0.0;
  for (var k = 1; k * lapLength <= total + 1e-9; k++) {
    final t = timeAtDistance(samples, k * lapLength);
    tempos.add(t - antes);
    antes = t;
  }
  if (total - tempos.length * lapLength > 1e-6) tempos.add(samples.last.t - antes);
  return tempos;
}

/// Pedal cortado no fechamento de uma volta.
class LapClose {
  const LapClose({
    required this.laps,
    required this.distance,
    required this.trimmed,
    required this.movingTime,
    required this.avgPower,
    required this.avgSpeedKmh,
    required this.kcal,
    required this.climbed,
    required this.samples,
  });

  final int laps;
  final double distance;
  final double trimmed;
  final double movingTime;
  final double avgPower;
  final double avgSpeedKmh;
  final double kcal;
  final double climbed;
  final List<RideSample> samples;
}

/// Se o pedal passou da última volta completa só até a [margin] (fração da volta),
/// devolve o pedal cortado no fechamento dela, com os totais refeitos. Senão, null.
LapClose? closeLap({
  required List<RideSample> samples,
  required double lapLength,
  required double margin,
  required double Function(double d) climbedUpTo,
}) {
  if (samples.isEmpty || lapLength <= 0) return null;
  final total = samples.last.distance;
  final laps = (total / lapLength + 1e-9).floor();
  final extra = total - laps * lapLength;
  if (laps < 1 || extra <= 1e-6 || extra > margin * lapLength + 1e-9) return null;

  final corte = laps * lapLength;
  final tempo = timeAtDistance(samples, corte);
  final mantidas = <RideSample>[];
  var energia = 0.0;
  var tAntes = 0.0;
  for (final s in samples) {
    if (s.distance > corte) {
      final fracao = (tempo - tAntes) / math.max(1e-9, s.t - tAntes);
      final ultima = RideSample(
        t: tempo,
        distance: corte,
        speedKmh: s.speedKmh,
        power: s.power,
        cadence: s.cadence,
        heartRate: s.heartRate,
      );
      if (fracao > 1e-9) {
        energia += s.power * (tempo - tAntes);
        mantidas.add(ultima);
      }
      break;
    }
    energia += s.power * (s.t - tAntes);
    tAntes = s.t;
    mantidas.add(s);
  }
  return LapClose(
    laps: laps,
    distance: corte,
    trimmed: extra,
    movingTime: tempo,
    avgPower: tempo > 0 ? energia / tempo : 0,
    avgSpeedKmh: tempo > 0 ? corte / tempo * 3.6 : 0,
    kcal: energia / 1000,
    climbed: climbedUpTo(corte),
    samples: mantidas,
  );
}

/// Amostras de uma volta, para ver no mapa e no gráfico.
class LapSlice {
  const LapSlice({required this.index, required this.start, required this.length, required this.samples, required this.complete});

  final int index;

  /// Distância do pedal onde a volta começa.
  final double start;

  /// Comprimento da volta (ou do pedal todo, quando não é volta).
  final double length;
  final List<RideSample> samples;
  final bool complete;
}

/// Separa o pedal em voltas. Com [lapLength] infinito (ida, pedal livre), um trecho só.
List<LapSlice> lapSlices(List<RideSample> samples, double lapLength) {
  if (samples.isEmpty) return const [];
  final total = samples.last.distance;
  if (!lapLength.isFinite || lapLength <= 0) {
    return [LapSlice(index: 0, start: 0, length: total, samples: samples, complete: true)];
  }
  final fatias = <LapSlice>[];
  for (var i = 0; i * lapLength < total - 1e-6; i++) {
    final ini = i * lapLength;
    final fim = ini + lapLength;
    fatias.add(LapSlice(
      index: i,
      start: ini,
      length: lapLength,
      samples: [for (final s in samples) if (s.distance > ini + 1e-9 && s.distance <= fim + 1e-9) s],
      complete: total >= fim - 1e-6,
    ));
  }
  return fatias;
}
