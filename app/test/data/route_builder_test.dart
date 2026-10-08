import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';

import '../support/fake_valhalla.dart';
import '../support/geo_helpers.dart';

final _linha = northLine(2, 100);

final _semEspera = RequestPacer(gap: Duration.zero);

RouteBuilder builder(http.Client client) => RouteBuilder(
      routing: RoutingService(client, _semEspera),
      elevation: ElevationService(client, _semEspera),
      now: () => DateTime(2026, 10, 8, 9),
      newId: () => 'r1',
    );

void main() {
  test('rota com pontos a cada 20 m e altimetria suavizada', () async {
    final client = fakeValhalla(linha: _linha, altura: (i) => i * 2.0);
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
    final client = fakeValhalla(linha: _linha, heightStatus: () => 500);
    final built = await builder(client).build(_linha);
    expect(built.flat, isTrue);
    expect(built.route.points.every((p) => p.alt == 0), isTrue);
  });

  test('erro de rota sobe para quem chamou', () {
    final client = fakeValhalla(linha: _linha);
    expect(builder(client).build([_linha.first]), throwsA(isA<RouteException>()));
  });
}
