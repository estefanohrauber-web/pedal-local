import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/route_profile.dart';

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
    expect(r.relief, reliefVersion);
  });

  // 400 m para o norte: 21 pontos, a ponte vai do ponto 8 ao 12 (160 a 240 m). Embaixo dela,
  // o terreno desce até o rio (500 m); a rua fica a 540 m.
  final comPonte = northLine(2, 400);
  double vale(int i) => i >= 8 && i <= 12 ? 500 : 540;

  test('ponte: o relevo do rio embaixo dela vira uma reta entre as cabeceiras', () async {
    final pedidos = <http.Request>[];
    final client = fakeValhalla(linha: comPonte, altura: vale, pontes: const [(8, 12)], pedidos: pedidos);
    final r = (await builder(client).build(comPonte)).route;
    expect(r.points.length, 21);
    for (final p in r.points) {
      expectNear(p.alt, 540, 1e-6);
    }
    expect(r.gainM, 0);
    expect(r.lossM, 0);
    expect(r.relief, reliefVersion);
    expect(pedidos.map((p) => p.url.path), ['/route', '/height', '/trace_attributes']);
  });

  test('pontes fora do ar: relevo sem a correção, marcado para corrigir depois', () async {
    final client = fakeValhalla(linha: comPonte, altura: vale, pontes: const [(8, 12)], traceStatus: () => 500);
    final built = await builder(client).build(comPonte);
    expect(built.flat, isFalse);
    expect(built.route.lossM, greaterThan(10));
    expect(built.route.relief, lessThan(reliefVersion));
  });

  test('refazer o relevo de uma rota salva: mesmos pontos, pontes em reta', () async {
    final client = fakeValhalla(linha: comPonte, altura: vale, pontes: const [(8, 12)]);
    final b = builder(client);
    final antiga = (await builder(fakeValhalla(linha: comPonte, altura: vale, traceStatus: () => 500)).build(comPonte))
        .route
        .copyWith(name: 'Entre pontes', colorIndex: 1);
    final nova = await b.refreshRelief(antiga);
    expect(nova, isNotNull);
    expect(nova!.id, antiga.id);
    expect(nova.name, 'Entre pontes');
    expect(nova.colorIndex, 1);
    expect(nova.waypoints, antiga.waypoints);
    expect(nova.distanceM, antiga.distanceM);
    expect([for (final p in nova.points) p.geo], [for (final p in antiga.points) p.geo]);
    expect(nova.points.every((p) => (p.alt - 540).abs() < 1e-6), isTrue);
    expect(nova.lossM, 0);
    expect(nova.relief, reliefVersion);
  });

  test('refazer o relevo sem internet: fica para depois (null)', () async {
    final antiga = RouteRecord(
      id: 'r9',
      name: 'Velha',
      createdAt: DateTime(2026, 10, 1),
      waypoints: comPonte,
      points: [for (final p in northLine(21, 20)) ProfilePoint(p.lat, p.lon, 540)],
      distanceM: 400,
      gainM: 0,
      lossM: 0,
      relief: 1,
    );
    expect(await builder(fakeValhalla(linha: comPonte, heightStatus: () => 500)).refreshRelief(antiga), isNull);
    expect(await builder(fakeValhalla(linha: comPonte, traceStatus: () => 500)).refreshRelief(antiga), isNull);
  });

  test('altimetria fora do ar: rota plana com aviso', () async {
    final client = fakeValhalla(linha: _linha, heightStatus: () => 500);
    final built = await builder(client).build(_linha);
    expect(built.flat, isTrue);
    expect(built.route.points.every((p) => p.alt == 0), isTrue);
    expect(built.route.relief, 0);
  });

  test('erro de rota sobe para quem chamou', () {
    final client = fakeValhalla(linha: _linha);
    expect(builder(client).build([_linha.first]), throwsA(isA<RouteException>()));
  });
}
