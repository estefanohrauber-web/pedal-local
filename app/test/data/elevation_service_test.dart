import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/geo.dart';

final semEspera = RequestPacer(gap: Duration.zero);

int quantos(http.Request req) => ((jsonDecode(req.body) as Map<String, dynamic>)['shape'] as List).length;

http.Response alturas(List<Object?> h) => http.Response(jsonEncode({'height': h}), 200);

ElevationService servico(http.Response resposta) => ElevationService(MockClient((r) async => resposta), semEspera);

void main() {
  test('pede as alturas ao Valhalla e mantém a ordem', () async {
    late http.Request pedido;
    final client = MockClient((req) async {
      pedido = req;
      return alturas([528, 530.5]);
    });
    final alts = await ElevationService(client, semEspera)
        .elevations(const [GeoPoint(-27.19, -51.49), GeoPoint(-27.2, -51.48)]);
    expect(alts, [528.0, 530.5]);
    expect(pedido.method, 'POST');
    expect(pedido.url.toString(), '$valhallaBase/height');
    expect(pedido.headers['User-Agent'], contains('PedalLocal'));
    final corpo = jsonDecode(pedido.body) as Map<String, dynamic>;
    expect(corpo['range'], false);
    expect(corpo['shape'], [
      {'lat': -27.19, 'lon': -51.49},
      {'lat': -27.2, 'lon': -51.48},
    ]);
  });

  test('rota enorme vai em lotes, cada um esperando a vez', () async {
    final tamanhos = <int>[];
    var vezes = 0;
    var n = 0;
    final client = MockClient((req) async {
      final k = quantos(req);
      tamanhos.add(k);
      final base = n;
      n += k;
      return alturas([for (var i = 0; i < k; i++) base + i]);
    });
    final pts = [for (var i = 0; i < heightBatch + 10; i++) GeoPoint(-27 - i * 1e-5, -51.5)];
    final alts = await ElevationService(client, _Contador(() => vezes++)).elevations(pts);
    expect(tamanhos, [heightBatch, 10]);
    expect(vezes, 2);
    expect(alts.length, heightBatch + 10);
    expect(alts.last, (heightBatch + 9).toDouble());
  });

  test('ponto sem dado pega a altura do vizinho', () async {
    final alts = await servico(alturas([null, 10, null, 12, null]))
        .elevations([for (var i = 0; i < 5; i++) GeoPoint(-27.0 - i * 1e-4, -51.5)]);
    expect(alts, [10.0, 10.0, 10.0, 12.0, 12.0]);
  });

  test('nenhum dado de altura falha', () {
    expect(servico(alturas([null, null])).elevations(const [GeoPoint(0, 0), GeoPoint(0, 1)]), throwsException);
  });

  test('resposta com tamanho errado falha', () {
    expect(servico(alturas([1])).elevations(const [GeoPoint(0, 0), GeoPoint(0, 1)]), throwsException);
  });

  test('HTTP de erro falha', () {
    expect(servico(http.Response('limite', 429)).elevations(const [GeoPoint(0, 0)]), throwsException);
  });

  test('lista vazia não faz pedido', () async {
    final client = MockClient((r) async => fail('não deveria pedir'));
    expect(await ElevationService(client, semEspera).elevations(const []), isEmpty);
  });
}

/// Conta quantas vezes o serviço pediu a vez.
class _Contador extends RequestPacer {
  _Contador(this._aviso) : super(gap: Duration.zero);

  final void Function() _aviso;

  @override
  Future<void> wait() {
    _aviso();
    return super.wait();
  }
}
