import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/domain/geo.dart';

import 'polyline_encode.dart';

/// Valhalla falso: /route devolve [linha] numa perna só; /height devolve [altura] de cada ponto pedido.
/// [heightStatus] diferente de 200 simula a altitude fora do ar (é lido a cada pedido).
MockClient fakeValhalla({
  required List<GeoPoint> linha,
  double Function(int i)? altura,
  int Function()? heightStatus,
  List<http.Request>? pedidos,
}) =>
    MockClient((req) async {
      pedidos?.add(req);
      if (req.url.path == '/route') {
        return http.Response(
          jsonEncode({
            'trip': {
              'legs': [
                {'shape': encodePolyline(linha)},
              ],
              'status': 0,
            },
          }),
          200,
        );
      }
      final status = heightStatus?.call() ?? 200;
      if (status != 200) return http.Response('erro', status);
      final shape = (jsonDecode(req.body) as Map<String, dynamic>)['shape'] as List;
      final f = altura ?? (i) => 0;
      return http.Response(jsonEncode({'height': [for (var i = 0; i < shape.length; i++) f(i)]}), 200);
    });

/// Valhalla falso que traça linhas retas entre os pontos pedidos (cada pedido dá um caminho
/// diferente, como no gerador de voltas). A altitude é 700 m, com um morro de 80 m em [morro].
MockClient fakeValhallaStraight({List<String>? caminhos, bool semCaminho = false, GeoPoint? morro}) =>
    MockClient((req) async {
      caminhos?.add(req.url.path);
      final corpo = jsonDecode(req.body) as Map<String, dynamic>;
      if (req.url.path == '/route') {
        if (semCaminho) return http.Response(jsonEncode({'error_code': 442, 'error': 'No path'}), 400);
        final pontos = [
          for (final l in corpo['locations'] as List)
            GeoPoint((l['lat'] as num).toDouble(), (l['lon'] as num).toDouble()),
        ];
        return http.Response(
          jsonEncode({
            'trip': {
              'legs': [
                {'shape': encodePolyline(pontos)},
              ],
            },
          }),
          200,
        );
      }
      double altura(GeoPoint p) => morro == null ? 700 : 700 + 80 * math.exp(-math.pow(haversine(p, morro) / 600, 2));
      final shape = corpo['shape'] as List;
      return http.Response(
        jsonEncode({
          'height': [for (final p in shape) altura(GeoPoint((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble()))],
        }),
        200,
      );
    });
