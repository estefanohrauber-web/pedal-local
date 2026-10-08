import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import 'app_http.dart';

const elevationBase = 'https://api.open-meteo.com/v1/elevation';
const elevationBatch = 100;

/// Altitude de cada ponto (Open-Meteo, até 100 coordenadas por chamada).
class ElevationService {
  ElevationService(this._client);

  final http.Client _client;

  Future<List<double>> elevations(List<GeoPoint> points) async {
    final out = <double>[];
    for (var i = 0; i < points.length; i += elevationBatch) {
      final lote = points.sublist(i, (i + elevationBatch).clamp(0, points.length));
      final lat = lote.map((p) => p.lat.toStringAsFixed(5)).join(',');
      final lon = lote.map((p) => p.lon.toStringAsFixed(5)).join(',');
      final res = await _client
          .get(Uri.parse('$elevationBase?latitude=$lat&longitude=$lon'), headers: appHeaders)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('Altimetria indisponível (HTTP ${res.statusCode})');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elevation = data['elevation'];
      if (elevation is! List || elevation.length != lote.length) {
        throw Exception('Altimetria: resposta inválida');
      }
      out.addAll(elevation.map((e) => (e as num).toDouble()));
    }
    return out;
  }
}
