import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import '../../domain/structures.dart';
import 'app_http.dart';
import 'polyline.dart';
import 'request_pacer.dart';

/// Valhalla nos servidores da FOSSGIS: traçado pelas ruas e altitude.
const valhallaBase = 'https://valhalla1.openstreetmap.de';

/// Pedal virtual, sem trânsito de verdade: pode ir por BR e estrada principal (use_roads),
/// não foge de ladeira (use_hills) e ignora mão única.
const bikeCostingOptions = {
  'bicycle': {'use_roads': 1.0, 'use_hills': 1.0, 'ignore_oneways': true},
};

class RouteException implements Exception {
  const RouteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Traça o caminho pelas ruas entre os pontos (Valhalla, perfil bicicleta).
class RoutingService {
  RoutingService(this._client, this._pacer);

  final http.Client _client;
  final RequestPacer _pacer;

  Future<List<GeoPoint>> route(List<GeoPoint> waypoints) async {
    if (waypoints.length < 2) {
      throw const RouteException('poucos-pontos', 'Toque pelo menos dois pontos no mapa.');
    }
    final body = jsonEncode({
      'locations': [
        for (final p in waypoints) {'lat': p.lat, 'lon': p.lon},
      ],
      'costing': 'bicycle',
      'costing_options': bikeCostingOptions,
      'directions_type': 'none',
    });

    await _pacer.wait();
    http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$valhallaBase/route'), headers: appJsonHeaders, body: body)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const RouteException('sem-conexao', 'Sem conexão — não deu para traçar a rota.');
    }

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    final erro = data?['error_code'];
    if (erro == 154) {
      throw const RouteException('longe-demais', 'A rota passou de 150 km. Use pontos mais próximos.');
    }
    if (erro == 170 || erro == 171 || erro == 442 || erro == 443) {
      throw const RouteException('sem-caminho', 'Não encontrei caminho entre esses pontos.');
    }
    final legs = (data?['trip'] as Map<String, dynamic>?)?['legs'] as List?;
    if (res.statusCode != 200 || legs == null || legs.isEmpty) {
      throw const RouteException('servico', 'O serviço de rotas não respondeu. Tente de novo em instantes.');
    }

    final linha = <GeoPoint>[];
    for (final leg in legs) {
      final pontos = decodePolyline((leg as Map<String, dynamic>)['shape'] as String);
      final emenda = linha.isNotEmpty && pontos.isNotEmpty && pontos.first == linha.last;
      linha.addAll(emenda ? pontos.skip(1) : pontos);
    }
    return linha;
  }

  /// Pontes e túneis no caminho [points], em metros ao longo dele. O mapa (OpenStreetMap) diz
  /// quais ruas são ponte ou túnel; a altitude não sabe disso (veja [flattenStructures]).
  Future<List<StructureSpan>> structures(List<GeoPoint> points) async {
    final body = jsonEncode({
      'shape': [
        for (final p in points) {'lat': p.lat, 'lon': p.lon},
      ],
      'costing': 'bicycle',
      'costing_options': bikeCostingOptions,
      'shape_match': 'map_snap',
      'filters': {
        'attributes': ['edge.bridge', 'edge.tunnel', 'edge.begin_shape_index', 'edge.end_shape_index', 'shape'],
        'action': 'include',
      },
    });
    await _pacer.wait();
    final res = await _client
        .post(Uri.parse('$valhallaBase/trace_attributes'), headers: appJsonHeaders, body: body)
        .timeout(const Duration(seconds: 30));
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    final shape = data?['shape'];
    final edges = data?['edges'];
    if (res.statusCode != 200 || shape is! String || edges is! List) {
      throw const RouteException('servico', 'Não deu para achar as pontes da rota.');
    }
    final trechos = <ShapeRange>[
      for (final e in edges.cast<Map<String, dynamic>>())
        if (e['bridge'] == true || e['tunnel'] == true)
          (begin: (e['begin_shape_index'] as num).toInt(), end: (e['end_shape_index'] as num).toInt()),
    ];
    if (trechos.isEmpty) return const [];
    return structureSpans(points, decodePolyline(shape), trechos);
  }
}
