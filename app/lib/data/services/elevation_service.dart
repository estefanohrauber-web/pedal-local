import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import 'app_http.dart';
import 'request_pacer.dart';
import 'routing_service.dart';

/// Pontos por pedido (5000 pontos de 20 m = 100 km; o serviço aceitou 12 mil nos testes).
const heightBatch = 5000;

/// Altitude de cada ponto (Valhalla /height).
class ElevationService {
  ElevationService(this._client, this._pacer);

  final http.Client _client;
  final RequestPacer _pacer;

  Future<List<double>> elevations(List<GeoPoint> points) async {
    final brutas = <double?>[];
    for (var i = 0; i < points.length; i += heightBatch) {
      final lote = points.sublist(i, (i + heightBatch).clamp(0, points.length));
      await _pacer.wait();
      final res = await _client
          .post(
            Uri.parse('$valhallaBase/height'),
            headers: appJsonHeaders,
            body: jsonEncode({
              'range': false,
              'shape': [
                for (final p in lote) {'lat': p.lat, 'lon': p.lon},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('Altimetria indisponível (HTTP ${res.statusCode})');
      final height = (jsonDecode(res.body) as Map<String, dynamic>)['height'];
      if (height is! List || height.length != lote.length) {
        throw Exception('Altimetria: resposta inválida');
      }
      brutas.addAll(height.map((h) => (h as num?)?.toDouble()));
    }
    return _preencherFalhas(brutas);
  }
}

/// Ponto sem dado (null) pega a altura do vizinho anterior; os do começo, a do primeiro com dado.
List<double> _preencherFalhas(List<double?> brutas) {
  if (brutas.isEmpty) return const [];
  final primeira = brutas.firstWhere((h) => h != null, orElse: () => null);
  if (primeira == null) throw Exception('Altimetria: sem dados para esta região');
  var anterior = primeira;
  return [
    for (final h in brutas) anterior = h ?? anterior,
  ];
}
