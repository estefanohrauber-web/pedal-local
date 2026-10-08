import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import 'app_http.dart';

/// Photon (komoot): busca de endereços com dados do OpenStreetMap.
const photonBase = 'https://photon.komoot.io/api/';

class Place {
  const Place({required this.name, required this.detail, required this.point});

  final String name;
  final String detail;
  final GeoPoint point;
}

class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeocodingService {
  GeocodingService(this._client);

  final http.Client _client;

  /// Lugares que combinam com [texto], mais perto de [near] primeiro.
  Future<List<Place>> search(String texto, {GeoPoint? near}) async {
    final q = texto.trim();
    if (q.length < 3) return const [];
    final uri = Uri.parse(photonBase).replace(queryParameters: {
      'q': q,
      'limit': '6',
      if (near != null) 'lat': near.lat.toStringAsFixed(4),
      if (near != null) 'lon': near.lon.toStringAsFixed(4),
    });
    http.Response res;
    try {
      res = await _client.get(uri, headers: const {'User-Agent': appUserAgent}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const GeocodingException('Sem conexão — não deu para buscar.');
    }
    if (res.statusCode != 200) throw const GeocodingException('A busca não respondeu. Tente de novo.');
    final Map<String, dynamic> dados;
    try {
      dados = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const GeocodingException('A busca não respondeu. Tente de novo.');
    }
    return [
      for (final f in (dados['features'] as List? ?? const []))
        if (_lugar(f as Map<String, dynamic>) case final Place p) p,
    ];
  }

  Place? _lugar(Map<String, dynamic> f) {
    final coords = (f['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?;
    if (coords == null || coords.length < 2) return null;
    final p = (f['properties'] as Map<String, dynamic>?) ?? const {};
    String? s(String k) {
      final v = p[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final rua = s('street');
    final numero = s('housenumber');
    final ruaComNumero = rua == null ? null : (numero == null ? rua : '$rua, $numero');
    final nome = s('name') ?? ruaComNumero;
    if (nome == null) return null;
    final detalhe = [
      if (ruaComNumero != null && ruaComNumero != nome) ruaComNumero,
      s('district'),
      s('city'),
      s('state'),
    ].whereType<String>().join(', ');
    return Place(
      name: nome,
      detail: detalhe,
      point: GeoPoint((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
    );
  }
}
