import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/domain/geo.dart';

int quantos(http.Request req) => req.url.queryParameters['latitude']!.split(',').length;

void main() {
  test('busca em lotes de 100 e mantém a ordem', () async {
    var n = 0;
    final pedidos = <http.Request>[];
    final client = MockClient((req) async {
      pedidos.add(req);
      final k = quantos(req);
      final base = n;
      n += k;
      return http.Response(jsonEncode({'elevation': [for (var i = 0; i < k; i++) base + i]}), 200);
    });
    final pts = [for (var i = 0; i < 150; i++) GeoPoint(-23.5 + i * 1e-4, -46.6)];
    final alts = await ElevationService(client).elevations(pts);
    expect(pedidos.length, 2);
    expect(quantos(pedidos.first), 100);
    expect(alts, [for (var i = 0; i < 150; i++) i.toDouble()]);
  });

  test('resposta com tamanho errado falha', () {
    final client = MockClient((r) async => http.Response(jsonEncode({'elevation': [1]}), 200));
    expect(ElevationService(client).elevations(const [GeoPoint(0, 0), GeoPoint(0, 1)]), throwsException);
  });

  test('HTTP de erro falha', () {
    final client = MockClient((r) async => http.Response('limite', 429));
    expect(ElevationService(client).elevations(const [GeoPoint(0, 0)]), throwsException);
  });
}
