import 'dart:math' as math;

import 'geo.dart';
import 'route_profile.dart';

/// A rota é uma volta fechada quando o fim fica a até esta distância do começo.
const loopCloseM = 50.0;

/// Ponto final que só repete o começo (tirado antes de girar a volta).
const _repeatedEndM = 25.0;

bool isLoop(List<ProfilePoint> pts) => pts.length > 3 && haversine(pts.first.geo, pts.last.geo) <= loopCloseM;

/// Sentido da volta no mapa (norte para cima): área com sinal do contorno.
bool isClockwise(List<ProfilePoint> pts) {
  if (pts.length < 3) return false;
  final lat0 = pts.first.lat;
  final lon0 = pts.first.lon;
  final escala = math.cos(lat0 * math.pi / 180);
  double x(ProfilePoint p) => (p.lon - lon0) * escala;
  double y(ProfilePoint p) => p.lat - lat0;
  var area = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    area += x(a) * y(b) - x(b) * y(a);
  }
  return area < 0;
}

/// Pontos da rota no sentido e começo escolhidos.
/// [startIndex] é um índice dos pontos originais e só vale para volta fechada.
List<ProfilePoint> routeVariant(List<ProfilePoint> pts, {bool reversed = false, int startIndex = 0}) {
  var out = List.of(pts);
  if (startIndex > 0 && isLoop(pts)) {
    final anel = List.of(pts);
    if (haversine(anel.first.geo, anel.last.geo) <= _repeatedEndM) anel.removeLast();
    final k = startIndex % anel.length;
    out = [...anel.sublist(k), ...anel.sublist(0, k), anel[k]];
  }
  return reversed ? out.reversed.toList() : out;
}

/// Índice do ponto da rota mais perto de [p] (para escolher o começo tocando no mapa).
int nearestIndex(List<ProfilePoint> pts, GeoPoint p) {
  var melhor = 0;
  var menor = double.infinity;
  for (var i = 0; i < pts.length; i++) {
    final d = haversine(pts[i].geo, p);
    if (d < menor) {
      menor = d;
      melhor = i;
    }
  }
  return melhor;
}
