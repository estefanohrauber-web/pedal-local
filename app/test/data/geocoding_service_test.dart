import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/geocoding_service.dart';
import 'package:pedal_local/domain/geo.dart';

http.Response resposta(List<Map<String, Object?>> features, [int status = 200]) =>
    http.Response(jsonEncode({'type': 'FeatureCollection', 'features': features}), status, headers: {
      'content-type': 'application/json; charset=utf-8',
    });

Map<String, Object?> lugar(double lat, double lon, Map<String, Object?> props) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat],
      },
      'properties': props,
    };

void main() {
  test('busca perto do mapa e devolve nome, detalhe e posição', () async {
    late http.Request pedido;
    final client = MockClient((req) async {
      pedido = req;
      return resposta([
        lugar(-27.1906, -51.4917, {
          'name': 'Praça Ivo Silveira',
          'street': 'Rua Nereu Ramos',
          'city': 'Herval d\'Oeste',
          'state': 'Santa Catarina',
        }),
        lugar(-27.17, -51.50, {'street': 'Rua XV de Novembro', 'housenumber': '120', 'city': 'Joaçaba'}),
      ]);
    });
    final lugares = await GeocodingService(client).search('praça', near: const GeoPoint(-27.19, -51.49));
    expect(pedido.url.host, 'photon.komoot.io');
    expect(pedido.url.queryParameters['q'], 'praça');
    expect(pedido.url.queryParameters['lat'], '-27.1900');
    expect(pedido.url.queryParameters['lon'], '-51.4900');
    expect(pedido.headers['User-Agent'], contains('PedalLocal'));
    expect(lugares.length, 2);
    expect(lugares.first.name, 'Praça Ivo Silveira');
    expect(lugares.first.detail, 'Rua Nereu Ramos, Herval d\'Oeste, Santa Catarina');
    expect(lugares.first.point, const GeoPoint(-27.1906, -51.4917));
    expect(lugares[1].name, 'Rua XV de Novembro, 120');
    expect(lugares[1].detail, 'Joaçaba');
  });

  test('texto curto não busca', () async {
    final client = MockClient((req) async => fail('não deveria buscar'));
    expect(await GeocodingService(client).search(' a '), isEmpty);
  });

  test('sem conexão ou serviço fora do ar vira erro com mensagem', () {
    final sem = MockClient((req) async => throw http.ClientException('falhou'));
    expect(GeocodingService(sem).search('praça'), throwsA(isA<GeocodingException>()));
    final fora = MockClient((req) async => http.Response('erro', 503));
    expect(GeocodingService(fora).search('praça'), throwsA(isA<GeocodingException>()));
  });
}
