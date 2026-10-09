import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/geo_helpers.dart';

import '../support/polyline_encode.dart';

const dois = [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)];

final semEspera = RequestPacer(gap: Duration.zero);

http.Response json(Object data, [int status = 200]) => http.Response(jsonEncode(data), status);

http.Response viagem(List<List<GeoPoint>> pernas) => json({
      'trip': {
        'legs': [
          for (final p in pernas) {'shape': encodePolyline(p)},
        ],
      },
    });

http.Response falha(int codigo, [int status = 400]) =>
    json({'error_code': codigo, 'error': 'erro $codigo', 'status_code': status}, status);

Matcher erro(String code) => throwsA(isA<RouteException>().having((e) => e.code, 'code', code));

RoutingService servico(http.Response resposta) => RoutingService(MockClient((r) async => resposta), semEspera);

void main() {
  test('pede ao Valhalla de bicicleta liberando BR, ladeira e contramão', () async {
    late http.Request pedido;
    final client = MockClient((req) async {
      pedido = req;
      return viagem([dois]);
    });
    final linha = await RoutingService(client, semEspera).route(dois);
    expect(linha, dois);
    expect(pedido.method, 'POST');
    expect(pedido.url.toString(), '$valhallaBase/route');
    expect(pedido.headers['User-Agent'], contains('PedalLocal'));
    expect(pedido.headers['Content-Type'], contains('application/json'));
    final corpo = jsonDecode(pedido.body) as Map<String, dynamic>;
    expect(corpo['locations'], [
      {'lat': -23.5, 'lon': -46.6},
      {'lat': -23.51, 'lon': -46.61},
    ]);
    expect(corpo['costing'], 'bicycle');
    expect(corpo['costing_options'], {
      'bicycle': {'use_roads': 1.0, 'use_hills': 1.0, 'ignore_oneways': true},
    });
    expect(corpo['directions_type'], 'none');
  });

  test('junta as pernas sem repetir o ponto de emenda', () async {
    const a = GeoPoint(-23.5, -46.6);
    const b = GeoPoint(-23.51, -46.61);
    const c = GeoPoint(-23.52, -46.6);
    final linha = await servico(viagem([
      [a, b],
      [b, c],
    ])).route(const [a, b, c]);
    expect(linha, const [a, b, c]);
  });

  test('espera a vez antes de pedir (no máximo 1 pedido por segundo)', () async {
    final ordem = <String>[];
    final client = MockClient((req) async {
      ordem.add('pedido');
      return viagem([dois]);
    });
    await RoutingService(client, _PacerRastreado(() => ordem.add('vez'))).route(dois);
    expect(ordem, ['vez', 'pedido']);
  });

  test('menos de dois pontos', () {
    expect(servico(json({})).route(const [GeoPoint(0, 0)]), erro('poucos-pontos'));
  });

  test('sem conexão', () {
    final client = MockClient((r) async => throw http.ClientException('Failed host lookup'));
    expect(RoutingService(client, semEspera).route(dois), erro('sem-conexao'));
  });

  test('sem caminho', () {
    expect(servico(falha(442)).route(dois), erro('sem-caminho'));
    expect(servico(falha(171)).route(dois), erro('sem-caminho'));
    expect(servico(falha(170)).route(dois), erro('sem-caminho'));
  });

  test('rota longa demais (limite de 150 km do serviço)', () {
    expect(servico(falha(154)).route(dois), erro('longe-demais'));
  });

  test('serviço fora do ar ou ocupado', () {
    expect(servico(http.Response('<html>', 502)).route(dois), erro('servico'));
    expect(servico(http.Response('devagar', 429)).route(dois), erro('servico'));
    expect(servico(json({'trip': {'legs': []}})).route(dois), erro('servico'));
  });

  group('pontes e túneis', () {
    // 1 km para o norte, pontos a cada 20 m; o caminho casado tem vértices a cada 100 m.
    final pontos = northLine(51, 20);
    final casado = northLine(11, 100);

    test('pergunta ao Valhalla quais trechos são ponte ou túnel e devolve os metros na rota', () async {
      late http.Request pedido;
      final client = MockClient((req) async {
        pedido = req;
        return json({
          'shape': encodePolyline(casado),
          'edges': [
            {'begin_shape_index': 0, 'end_shape_index': 2},
            {'bridge': true, 'begin_shape_index': 2, 'end_shape_index': 4},
            {'bridge': false, 'tunnel': false, 'begin_shape_index': 4, 'end_shape_index': 7},
            {'tunnel': true, 'begin_shape_index': 7, 'end_shape_index': 8},
            {'begin_shape_index': 8, 'end_shape_index': 10},
          ],
        });
      });
      final spans = await RoutingService(client, semEspera).structures(pontos);
      expect(pedido.url.toString(), '$valhallaBase/trace_attributes');
      final corpo = jsonDecode(pedido.body) as Map<String, dynamic>;
      expect((corpo['shape'] as List).length, 51);
      expect(corpo['shape'][1], {'lat': pontos[1].lat, 'lon': pontos[1].lon});
      expect(corpo['costing'], 'bicycle');
      expect(corpo['shape_match'], 'map_snap');
      expect(
        (corpo['filters'] as Map)['attributes'],
        containsAll(['edge.bridge', 'edge.tunnel', 'edge.begin_shape_index', 'edge.end_shape_index', 'shape']),
      );
      expect(spans.length, 2);
      expectNear(spans[0].start, 200, 1);
      expectNear(spans[0].end, 400, 1);
      expectNear(spans[1].start, 700, 1);
      expectNear(spans[1].end, 800, 1);
    });

    test('sem pontes: lista vazia', () async {
      final spans = await servico(json({
        'shape': encodePolyline(casado),
        'edges': [
          {'begin_shape_index': 0, 'end_shape_index': 10},
        ],
      })).structures(pontos);
      expect(spans, isEmpty);
    });

    test('espera a vez e avisa quando o serviço falha', () async {
      final ordem = <String>[];
      final client = MockClient((req) async {
        ordem.add('pedido');
        return http.Response('devagar', 429);
      });
      await expectLater(
        RoutingService(client, _PacerRastreado(() => ordem.add('vez'))).structures(pontos),
        throwsA(isA<RouteException>()),
      );
      expect(ordem, ['vez', 'pedido']);
      expect(servico(json({'height': []})).structures(pontos), throwsA(isA<RouteException>()));
    });
  });
}

/// Anota quando o serviço pede a vez.
class _PacerRastreado extends RequestPacer {
  _PacerRastreado(this._aviso) : super(gap: Duration.zero);

  final void Function() _aviso;

  @override
  Future<void> wait() {
    _aviso();
    return super.wait();
  }
}
