import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import 'app_http.dart';

const osrmBase = 'https://routing.openstreetmap.de/routed-bike/route/v1/driving/';

class RouteException implements Exception {
  const RouteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Traça o caminho pelas ruas entre os pontos (OSRM, perfil bicicleta).
class RoutingService {
  RoutingService(this._client);

  final http.Client _client;

  Future<List<GeoPoint>> route(List<GeoPoint> waypoints) async {
    if (waypoints.length < 2) {
      throw const RouteException('poucos-pontos', 'Toque pelo menos dois pontos no mapa.');
    }
    final coords = waypoints.map((p) => '${p.lon.toStringAsFixed(6)},${p.lat.toStringAsFixed(6)}').join(';');
    final uri = Uri.parse('$osrmBase$coords?overview=full&geometries=geojson');

    http.Response res;
    try {
      res = await _client.get(uri, headers: appHeaders).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const RouteException('sem-conexao', 'Sem conexão — não deu para traçar a rota.');
    }

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    final code = data?['code'];
    final routes = data?['routes'] as List?;
    if (code == 'NoRoute' || code == 'NoSegment' || (code == 'Ok' && (routes == null || routes.isEmpty))) {
      throw const RouteException('sem-caminho', 'Não encontrei caminho entre esses pontos.');
    }
    if (res.statusCode != 200 || code != 'Ok') {
      throw const RouteException('servico', 'O serviço de rotas não respondeu. Tente de novo em instantes.');
    }
    final geometry = (routes!.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    return [
      for (final c in coordinates) GeoPoint(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
  }
}
