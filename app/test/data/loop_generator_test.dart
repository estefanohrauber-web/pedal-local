import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/loop_generator.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/fake_valhalla.dart';
import '../support/geo_helpers.dart';
import '../support/polyline_encode.dart';

const casa = GeoPoint(-27.19, -51.49);

/// Morro de 80 m a 1 km ao norte de casa.
final morro = GeoPoint(casa.lat + 1000 / mPerDegLat, casa.lon);

MockClient valhallaReto({List<String>? caminhos, bool semCaminho = false}) =>
    fakeValhallaStraight(caminhos: caminhos, semCaminho: semCaminho, morro: morro);

/// Valhalla falso em que o caminho é traçado por [caminho] a partir dos pontos pedidos.
MockClient valhallaCom(List<GeoPoint> Function(List<GeoPoint> pedidos) caminho) {
  final altura = valhallaReto();
  return MockClient((req) async {
    if (req.url.path != '/route') return altura.send(req).then(http.Response.fromStream);
    final corpo = jsonDecode(req.body) as Map<String, dynamic>;
    final pedidos = [
      for (final l in corpo['locations'] as List) GeoPoint((l['lat'] as num).toDouble(), (l['lon'] as num).toDouble()),
    ];
    return http.Response(
      jsonEncode({
        'trip': {
          'legs': [
            {'shape': encodePolyline(caminho(pedidos))},
          ],
        },
      }),
      200,
    );
  });
}

LoopGenerator gerador(http.Client client) {
  final pacer = RequestPacer(gap: Duration.zero);
  return LoopGenerator(
    RouteBuilder(routing: RoutingService(client, pacer), elevation: ElevationService(client, pacer)),
  );
}

void main() {
  test('gera 3 voltas fechadas perto do tamanho pedido, com relevo', () async {
    final caminhos = <String>[];
    final progresso = <double>[];
    final voltas = await gerador(valhallaReto(caminhos: caminhos))
        .generate(casa, targetM: 5000, onProgress: progresso.add);
    expect(voltas.length, 3);
    for (final v in voltas) {
      expect((v.route.distanceM - 5000).abs(), lessThanOrEqualTo(500));
      expect(v.route.waypoints.length, 5);
      expect(v.route.waypoints.first, casa);
      expect(v.route.waypoints.last, casa);
      expect(haversine(v.route.points.first.geo, v.route.points.last.geo), lessThan(1));
      expect(v.flat, isFalse);
    }
    // 3 direções × no máximo 3 tentativas de rota + 3 altitudes.
    expect(caminhos.where((c) => c == '/route').length, lessThanOrEqualTo(9));
    expect(caminhos.where((c) => c == '/height').length, 3);
    expect(progresso.last, 1);
    expect(progresso, orderedEquals([...progresso]..sort()));
  });

  test('mais subida: tenta 6 direções e põe primeiro a que mais sobe', () async {
    final voltas = await gerador(valhallaReto()).generate(casa, targetM: 5000, moreClimb: true);
    expect(voltas.length, 3);
    // A volta que vai para o norte passa pelo morro: é a que mais sobe.
    final primeira = voltas.first.route;
    expect(primeira.waypoints[2].lat, greaterThan(casa.lat));
    for (var i = 1; i < voltas.length; i++) {
      final antes = voltas[i - 1].route;
      final depois = voltas[i].route;
      expect(antes.gainM / antes.distanceM, greaterThanOrEqualTo(depois.gainM / depois.distanceM));
    }
  });

  test('sem caminho em nenhuma direção vira erro com mensagem', () {
    expect(
      gerador(valhallaReto(semCaminho: true)).generate(casa, targetM: 5000),
      throwsA(isA<RouteException>().having((e) => e.code, 'code', 'sem-caminho')),
    );
  });

  test('sem conexão para na hora', () {
    final semRede = MockClient((req) async => throw http.ClientException('sem rede'));
    expect(
      gerador(semRede).generate(casa, targetM: 5000),
      throwsA(isA<RouteException>().having((e) => e.code, 'code', 'sem-conexao')),
    );
  });

  test('os pontos da volta ficam em cima do caminho (a rua), não no mato', () async {
    // A "rua" passa 100 m a leste de cada ponto pedido, com pontos a cada 20 m.
    final ruas = valhallaCom((pedidos) {
      final leste = [for (final p in pedidos) GeoPoint(p.lat, p.lon + 100 / (mPerDegLat * 0.89))];
      return resample(leste, 20);
    });
    final voltas = await gerador(ruas).generate(casa, targetM: 5000);
    for (final v in voltas) {
      final w = v.route.waypoints;
      expect(w.first, w.last);
      expect(haversine(w.first, casa), closeTo(100, 2));
      for (final p in w) {
        final pertoDaLinha = v.route.points.map((q) => haversine(p, q.geo)).reduce((a, b) => a < b ? a : b);
        expect(pertoDaLinha, lessThan(15));
      }
    }
  });

  test('volta muito longe do tamanho pedido fica de fora quando há outras', () async {
    // Para o norte, o caminho faz um desvio de 8 km que não muda com o tamanho do círculo.
    final desvio = valhallaCom((pedidos) {
      if (pedidos[2].lat <= casa.lat) return pedidos;
      final longe = GeoPoint(casa.lat + 4000 / mPerDegLat, casa.lon);
      return [...pedidos.sublist(0, 2), longe, ...pedidos.sublist(2)];
    });
    final voltas = await gerador(desvio).generate(casa, targetM: 5000);
    expect(voltas.length, 2);
    for (final v in voltas) {
      expect((v.route.distanceM - 5000).abs(), lessThanOrEqualTo(1500));
    }
  });
}
