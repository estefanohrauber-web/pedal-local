import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';

const mPerDegLat = 6371000 * math.pi / 180;

/// Linha reta para o norte com [count] pontos espaçados [spacingM] metros.
List<GeoPoint> northLine(int count, double spacingM, {GeoPoint start = const GeoPoint(-23.5, -46.6)}) => [
      for (var i = 0; i < count; i++) GeoPoint(start.lat + i * spacingM / mPerDegLat, start.lon),
    ];

/// Perfil reto para o norte, um ponto a cada [spacingM] metros, com as altitudes dadas.
List<ProfilePoint> northProfile(List<double> alts, {double spacingM = 20}) {
  final linha = northLine(alts.length, spacingM);
  return [for (var i = 0; i < alts.length; i++) ProfilePoint(linha[i].lat, linha[i].lon, alts[i])];
}

void expectNear(double actual, double expected, double tol) =>
    expect((actual - expected).abs(), lessThanOrEqualTo(tol), reason: 'esperado $expected ± $tol, veio $actual');

/// Volta quadrada de [sideM] metros, pontos a cada [stepM]: norte, leste, sul e oeste (sentido horário).
/// O último ponto repete o primeiro.
List<ProfilePoint> squareLoop(double sideM, {double stepM = 20, double Function(int i)? alts, GeoPoint start = const GeoPoint(-23.5, -46.6)}) {
  final n = (sideM / stepM).round();
  final mPerDegLon = mPerDegLat * math.cos(start.lat * math.pi / 180);
  final dLat = stepM / mPerDegLat;
  final dLon = stepM / mPerDegLon;
  final pts = <GeoPoint>[];
  var lat = start.lat;
  var lon = start.lon;
  for (final (passoLat, passoLon) in [(dLat, 0.0), (0.0, dLon), (-dLat, 0.0), (0.0, -dLon)]) {
    for (var i = 0; i < n; i++) {
      pts.add(GeoPoint(lat, lon));
      lat += passoLat;
      lon += passoLon;
    }
  }
  pts.add(pts.first);
  final alt = alts ?? (i) => 700.0;
  return [for (var i = 0; i < pts.length; i++) ProfilePoint(pts[i].lat, pts[i].lon, alt(i))];
}
