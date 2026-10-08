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
