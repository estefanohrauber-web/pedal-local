import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/routing_service.dart';

import '../support/geo_helpers.dart';

final _linha = northLine(2, 100);

http.Response _osrm() => http.Response(
      jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                for (final p in _linha) [p.lon, p.lat],
              ],
            },
          },
        ],
      }),
      200,
    );

RouteBuilder builder(MockClient client) => RouteBuilder(
      routing: RoutingService(client),
      elevation: ElevationService(client),
      now: () => DateTime(2026, 10, 8, 9),
      newId: () => 'r1',
    );

void main() {
  test('rota com pontos a cada 20 m e altimetria suavizada', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'routing.openstreetmap.de') return _osrm();
      final k = req.url.queryParameters['latitude']!.split(',').length;
      return http.Response(jsonEncode({'elevation': [for (var i = 0; i < k; i++) i * 2]}), 200);
    });
    final built = await builder(client).build(_linha);
    expect(built.flat, isFalse);
    final r = built.route;
    expect(r.id, 'r1');
    expect(r.name, '');
    expect(r.createdAt, DateTime(2026, 10, 8, 9));
    expect(r.points.length, 6);
    expectNear(r.distanceM, 100, 0.5);
    expectNear(r.gainM, 6, 1e-9); // 0,2,4,6,8,10 suavizado → 2,3,4,6,7,8
    expect(r.lossM, 0);
    expect(r.waypoints, _linha);
  });

  test('altimetria fora do ar: rota plana com aviso', () async {
    final client = MockClient((req) async =>
        req.url.host == 'routing.openstreetmap.de' ? _osrm() : http.Response('erro', 500));
    final built = await builder(client).build(_linha);
    expect(built.flat, isTrue);
    expect(built.route.points.every((p) => p.alt == 0), isTrue);
  });

  test('erro de rota sobe para quem chamou', () {
    final client = MockClient((req) async => _osrm());
    expect(builder(client).build([_linha.first]), throwsA(isA<RouteException>()));
  });
}
