import 'dart:math' as math;

import 'geo.dart';

const _raioTerraM = 6371000.0;

/// As ruas fazem o caminho mais comprido que o círculo: começa com um círculo menor.
const loopRadiusFactor = 0.75;

/// Aceita a volta se ficar a até 10 % da distância pedida.
const loopTolerance = 0.10;

/// Ponto a [distanceM] metros de [from] no rumo [bearingRad] (0 = norte, crescendo no sentido horário).
GeoPoint destinationPoint(GeoPoint from, double bearingRad, double distanceM) {
  final lat1 = from.lat * math.pi / 180;
  final lon1 = from.lon * math.pi / 180;
  final a = distanceM / _raioTerraM;
  final lat2 = math.asin(math.sin(lat1) * math.cos(a) + math.cos(lat1) * math.sin(a) * math.cos(bearingRad));
  final lon2 = lon1 +
      math.atan2(
        math.sin(bearingRad) * math.sin(a) * math.cos(lat1),
        math.cos(a) - math.sin(lat1) * math.sin(lat2),
      );
  return GeoPoint(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
}

/// Raio do primeiro círculo para uma volta de [targetM] metros.
double initialLoopRadius(double targetM) => targetM / (2 * math.pi) * loopRadiusFactor;

/// Rumos de partida espalhados em volta: 3 (a cada 120°) ou 6 (a cada 60°).
List<double> loopBearings(int count) => [for (var i = 0; i < count; i++) 2 * math.pi * i / count];

/// Volta num círculo que passa por [start]: o centro fica a [radiusM] no rumo [bearingRad];
/// 3 pontos no círculo a 90°, 180° e 270° da partida, e fecha na partida.
List<GeoPoint> loopWaypoints(GeoPoint start, {required double bearingRad, required double radiusM}) {
  final centro = destinationPoint(start, bearingRad, radiusM);
  final daPartida = bearingRad + math.pi; // rumo do centro até a partida
  return [
    start,
    for (var k = 1; k <= 3; k++) destinationPoint(centro, daPartida + k * math.pi / 2, radiusM),
    start,
  ];
}

/// Novo raio para chegar a [targetM], já que o raio [radiusM] deu uma volta de [lengthM].
double adjustLoopRadius(double radiusM, {required double targetM, required double lengthM}) =>
    lengthM <= 0 ? radiusM : radiusM * targetM / lengthM;

bool loopCloseEnough(double lengthM, double targetM) => (lengthM - targetM).abs() <= loopTolerance * targetM;

/// Fração dos pontos de [a] que ficam a menos de [tolM] metros de algum ponto de [b]
/// (1 = [a] passa todo por cima de [b]).
double overlapFraction(List<GeoPoint> a, List<GeoPoint> b, {double tolM = 40}) {
  if (a.isEmpty || b.isEmpty) return 0;
  var perto = 0;
  for (final p in a) {
    if (b.any((q) => haversine(p, q) <= tolM)) perto++;
  }
  return perto / a.length;
}

/// Procura o raio que dá a volta do tamanho pedido. Começa com a regra de três; quando
/// já houve uma volta curta e uma longa, tenta o meio entre os dois raios (as ruas nem
/// sempre crescem junto com o círculo: um rio ou uma ponte mudam tudo).
class LoopRadiusSearch {
  LoopRadiusSearch(this.targetM) : radius = initialLoopRadius(targetM);

  final double targetM;

  /// Raio a tentar agora.
  double radius;
  double? _curto;
  double? _longo;

  /// O raio atual deu uma volta de [lengthM]: escolhe o próximo.
  void record(double lengthM) {
    if (lengthM < targetM) {
      _curto = math.max(_curto ?? 0, radius);
    } else {
      _longo = math.min(_longo ?? double.infinity, radius);
    }
    final curto = _curto;
    final longo = _longo;
    radius = curto != null && longo != null && curto < longo
        ? (curto + longo) / 2
        : adjustLoopRadius(radius, targetM: targetM, lengthM: lengthM);
  }
}
