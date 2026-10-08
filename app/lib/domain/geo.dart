import 'dart:math' as math;

/// Um ponto no mapa (graus decimais).
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}

const _earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;

double haversine(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

List<double> cumulativeDistances(List<GeoPoint> points) {
  final out = <double>[0];
  for (var i = 1; i < points.length; i++) {
    out.add(out[i - 1] + haversine(points[i - 1], points[i]));
  }
  return out;
}

/// Índice i do trecho [i, i+1] que contém a distância [d] (`cum` crescente).
int segmentIndex(List<double> cum, double d) {
  var lo = 0;
  var hi = cum.length - 2;
  if (hi < 0) return 0;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (cum[mid] <= d) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

GeoPoint pointAt(List<GeoPoint> points, List<double> cum, double d) {
  if (points.length == 1) return points.first;
  final total = cum.last;
  final dist = math.min(math.max(d, 0.0), total);
  final i = segmentIndex(cum, dist);
  final seg = cum[i + 1] - cum[i];
  final t = seg > 0 ? (dist - cum[i]) / seg : 0.0;
  final a = points[i];
  final b = points[i + 1];
  if (t == 0) return a;
  return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);
}

/// Pontos a cada [step] metros; o último trecho fica entre step/2 e 1,5·step.
List<GeoPoint> resample(List<GeoPoint> points, [double step = 20]) {
  if (points.length < 2) return List.of(points);
  final cum = cumulativeDistances(points);
  final total = cum.last;
  final out = <GeoPoint>[];
  for (var d = 0.0; d < total - step / 2; d += step) {
    out.add(pointAt(points, cum, d));
  }
  out.add(points.last);
  return out;
}
