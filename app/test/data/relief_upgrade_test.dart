import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pedal_local/data/relief_upgrade.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/fake_valhalla.dart';
import '../support/geo_helpers.dart';

final _semEspera = RequestPacer(gap: Duration.zero);

RouteBuilder _builder(http.Client client) => RouteBuilder(
  routing: RoutingService(client, _semEspera),
  elevation: ElevationService(client, _semEspera),
);

/// 400 m para o norte com o vale do rio embaixo da ponte (pontos 8 a 12), como ficava antes.
RouteRecord _rota(String id, {int relief = 1, String nome = 'Entre pontes'}) {
  final linha = northLine(21, 20);
  return RouteRecord(
    id: id,
    name: nome,
    createdAt: DateTime(2026, 10, 8),
    waypoints: [linha.first, linha.last],
    points: [
      for (var i = 0; i < linha.length; i++)
        ProfilePoint(linha[i].lat, linha[i].lon, i >= 8 && i <= 12 ? 500 : 540),
    ],
    distanceM: 400,
    gainM: 40,
    lossM: 40,
    relief: relief,
    colorIndex: 1,
  );
}

double _vale(int i) => i >= 8 && i <= 12 ? 500 : 540;

void main() {
  test('refaz só as rotas com relevo antigo: a ponte vira reta', () async {
    final store = MemoryRoutesStore();
    await store.upsert(_rota('velha'));
    await store.upsert(_rota('nova', relief: reliefVersion));
    final pedidos = <http.Request>[];
    final client = fakeValhalla(
      linha: const [],
      altura: _vale,
      pontes: const [(8, 12)],
      pedidos: pedidos,
    );

    expect(await upgradeRelief(store, _builder(client)), 1);

    final velha = (await store.byId('velha'))!;
    expect(velha.relief, reliefVersion);
    expect(velha.points.every((p) => (p.alt - 540).abs() < 1e-6), isTrue);
    expect(velha.lossM, 0);
    expect(velha.name, 'Entre pontes');
    expect(velha.colorIndex, 1);
    final nova = (await store.byId('nova'))!;
    expect(nova.points[10].alt, 500); // já estava na versão atual: não mexe
    expect(pedidos.where((p) => p.url.path == '/height').length, 1);
  });

  test('sem internet: nada muda e fica para a próxima vez', () async {
    final store = MemoryRoutesStore();
    await store.upsert(_rota('velha'));
    final client = fakeValhalla(
      linha: const [],
      altura: _vale,
      traceStatus: () => 503,
    );
    expect(await upgradeRelief(store, _builder(client)), 0);
    final velha = (await store.byId('velha'))!;
    expect(velha.relief, 1);
    expect(velha.points[10].alt, 500);
  });

  test('rota renomeada ou apagada enquanto o relevo é refeito: vale o que a pessoa fez', () async {
    final store = MemoryRoutesStore();
    await store.upsert(_rota('renomeada'));
    await store.upsert(_rota('apagada', nome: 'Outra'));
    var mexeu = false;
    final client = fakeValhalla(
      linha: const [],
      altura: (i) {
        // A pessoa mexe nas rotas enquanto o app espera a primeira resposta do serviço.
        if (!mexeu) {
          mexeu = true;
          store.upsert(_rota('renomeada', nome: 'Pontes do rio'));
          store.delete('apagada');
        }
        return _vale(i);
      },
      pontes: const [(8, 12)],
    );
    await upgradeRelief(store, _builder(client));
    final renomeada = (await store.byId('renomeada'))!;
    expect(renomeada.name, 'Pontes do rio');
    expect(renomeada.relief, reliefVersion);
    expect(await store.byId('apagada'), isNull);
  });
}
