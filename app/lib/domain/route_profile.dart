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

List<double> smoothElevations(List<double> alts, [int window = 5]) {
  final half = window ~/ 2;
  return [
    for (var i = 0; i < alts.length; i++)
      () {
        var soma = 0.0;
        var n = 0;
        for (var j = math.max(0, i - half); j <= math.min(alts.length - 1, i + half); j++) {
          soma += alts[j];
          n++;
        }
        return soma / n;
      }(),
  ];
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
