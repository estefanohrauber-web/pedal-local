import 'dart:convert';

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
