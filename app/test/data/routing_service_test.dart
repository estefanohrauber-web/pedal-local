import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/geo.dart';

const dois = [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)];

http.Response json(Object data, [int status = 200]) => http.Response(jsonEncode(data), status);

Matcher erro(String code) => throwsA(isA<RouteException>().having((e) => e.code, 'code', code));

void main() {
  test('monta a URL como lon,lat, manda o User-Agent e devolve os pontos', () async {
    late http.Request pedido;
    final client = MockClient((req) async {
      pedido = req;
      return json({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [-46.6, -23.5],
                [-46.61, -23.51],
              ],
            },
          },
        ],
      });
    });
    final linha = await RoutingService(client).route(dois);
    expect(linha, dois);
    expect(
      pedido.url.toString(),
      '$osrmBase-46.600000,-23.500000;-46.610000,-23.510000?overview=full&geometries=geojson',
    );
    expect(pedido.headers['User-Agent'], contains('PedalLocal'));
  });

  test('menos de dois pontos', () {
    expect(RoutingService(MockClient((r) async => json({}))).route(const [GeoPoint(0, 0)]), erro('poucos-pontos'));
  });

  test('sem conexão', () {
    final client = MockClient((r) async => throw http.ClientException('Failed host lookup'));
    expect(RoutingService(client).route(dois), erro('sem-conexao'));
  });

  test('sem caminho', () {
    expect(RoutingService(MockClient((r) async => json({'code': 'NoRoute'}, 400))).route(dois), erro('sem-caminho'));
    expect(RoutingService(MockClient((r) async => json({'code': 'NoSegment'}, 400))).route(dois), erro('sem-caminho'));
  });

  test('serviço fora do ar', () {
    expect(RoutingService(MockClient((r) async => http.Response('<html>', 502))).route(dois), erro('servico'));
  });
}
