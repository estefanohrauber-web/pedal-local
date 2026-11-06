import 'dart:math' as math;

import 'geo.dart';
import 'ride_session.dart';

const maxGrade = 0.2;

double _clamp(double x, double lo, double hi) => math.min(hi, math.max(lo, x));

/// Ponto da rota já reamostrado, com a altitude suavizada (m).
class ProfilePoint {
  const ProfilePoint(this.lat, this.lon, this.alt);

  final double lat;
  final double lon;
  final double alt;

  GeoPoint get geo => GeoPoint(lat, lon);
}

/// Quanto alisar o relevo do terreno (m). O modelo do terreno erra uns ±5 m de um ponto para
/// outro (árvores, prédios, a encosta ao lado da rua): sem alisar, a beira-rio plana vira um
/// sobe e desce de 5 %. Com 60 m, as ladeiras de verdade (de 200 m ou mais) quase não mudam.
const smoothSigmaM = 60.0;

/// Relevo alisado: em cada ponto, a reta que melhor passa pelos vizinhos até 3·[sigmaM]
/// metros (antes e depois), com mais peso nos mais perto (curva em sino). No meio da rota é a
/// média dos vizinhos; perto das pontas, a reta não deixa achatar uma rota que começa ou
/// termina numa ladeira. [dists]: metros desde o começo.
List<double> smoothElevations(List<double> dists, List<double> alts, {double sigmaM = smoothSigmaM}) {
  assert(dists.length == alts.length);
  final alcance = 3 * sigmaM;
  final out = List<double>.filled(alts.length, 0);
  for (var i = 0; i < alts.length; i++) {
    // Somas com peso de 1, x, x², y e x·y (x = metros até o ponto i).
    var s0 = 0.0, s1 = 0.0, s2 = 0.0, t0 = 0.0, t1 = 0.0;
    void somar(int j) {
      final x = dists[j] - dists[i];
      final p = math.exp(-x * x / (2 * sigmaM * sigmaM));
      s0 += p;
      s1 += p * x;
      s2 += p * x * x;
      t0 += p * alts[j];
      t1 += p * x * alts[j];
    }

    for (var j = i; j >= 0 && dists[i] - dists[j] <= alcance; j--) {
      somar(j);
    }
    for (var j = i + 1; j < alts.length && dists[j] - dists[i] <= alcance; j++) {
      somar(j);
    }
    final det = s0 * s2 - s1 * s1;
    out[i] = det > 1e-9 * s0 * s2 ? (s2 * t0 - s1 * t1) / det : t0 / s0;
  }
  return out;
}

/// Relevo da rota: inclinação por trecho, totais e consultas pela distância percorrida.
class RouteProfile implements Terrain {
  factory RouteProfile(List<ProfilePoint> pontos) {
    final points = [for (final p in pontos) p.geo];
    final alts = [for (final p in pontos) p.alt];
    final cum = cumulativeDistances(points);
    final grades = <double>[];
    var gain = 0.0;
    var loss = 0.0;
    for (var i = 0; i < pontos.length - 1; i++) {
      final run = cum[i + 1] - cum[i];
      final rise = alts[i + 1] - alts[i];
      grades.add(run > 0 ? _clamp(rise / run, -maxGrade, maxGrade) : 0);
      if (rise > 0) {
        gain += rise;
      } else {
        loss -= rise;
      }
    }
    return RouteProfile._(points, alts, cum, grades, gain, loss);
  }

  RouteProfile._(this.points, this.alts, this.cum, this._grades, this.gain, this.loss);

  final List<GeoPoint> points;
  final List<double> alts;
  final List<double> cum;
  final List<double> _grades;
  final double gain;
  final double loss;

  @override
  double get distance => cum.last;

  @override
  double gradeAt(double d) => _grades.isEmpty ? 0 : _grades[segmentIndex(cum, _clamp(d, 0, distance))];

  @override
  double lookahead(double d, double span) {
    final start = _clamp(d, 0, distance);
    final end = math.min(distance, start + span);
    return end - start > 1 ? (elevationAt(end) - elevationAt(start)) / (end - start) : 0;
  }

  double elevationAt(double d) {
    if (alts.length < 2) return alts.isEmpty ? 0 : alts.first;
    final x = _clamp(d, 0, distance);
    final i = segmentIndex(cum, x);
    final seg = cum[i + 1] - cum[i];
    final t = seg > 0 ? (x - cum[i]) / seg : 0.0;
    return alts[i] + (alts[i + 1] - alts[i]) * t;
  }

  GeoPoint positionAt(double d) => points.isEmpty ? const GeoPoint(0, 0) : pointAt(points, cum, d);

  /// Metros subidos do começo até [d], somando as inclinações positivas como o pedal soma.
  double climbedUpTo(double d) {
    final x = _clamp(d, 0, distance);
    var total = 0.0;
    for (var i = 0; i < _grades.length && cum[i] < x; i++) {
      final g = _grades[i];
      if (g > 0) total += g * (math.min(cum[i + 1], x) - cum[i]);
    }
    return total;
  }

  /// Pontos já percorridos até [d], terminando na posição atual (para pintar a linha feita).
  List<GeoPoint> traveled(double d) {
    if (points.length < 2) return List.of(points);
    final x = _clamp(d, 0, distance);
    return [...points.take(segmentIndex(cum, x) + 1), positionAt(x)];
  }
}
