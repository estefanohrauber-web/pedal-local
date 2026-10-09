import '../domain/geo.dart';
import '../domain/route_profile.dart';
import '../domain/structures.dart';
import 'routes_store.dart';
import 'services/elevation_service.dart';
import 'services/routing_service.dart';

const sampleStepM = 20.0;

class BuiltRoute {
  const BuiltRoute(this.route, {required this.flat});

  final RouteRecord route;

  /// A altimetria falhou e a rota ficou plana.
  final bool flat;
}

double _round(double x, int casas) {
  var f = 1.0;
  for (var i = 0; i < casas; i++) {
    f *= 10;
  }
  return (x * f).roundToDouble() / f;
}

/// Pontos tocados no mapa → rota pelas ruas, reamostrada, com relevo. O nome é dado depois.
class RouteBuilder {
  RouteBuilder({required this.routing, required this.elevation, DateTime Function()? now, String Function()? newId})
      : _now = now ?? DateTime.now,
        _newId = newId ?? (() => 'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}');

  final RoutingService routing;
  final ElevationService elevation;
  final DateTime Function() _now;
  final String Function() _newId;

  Future<BuiltRoute> build(List<GeoPoint> waypoints) async => fromLine(waypoints, await routing.route(waypoints));

  /// Rota a partir de um caminho já traçado: reamostra e busca o relevo.
  Future<BuiltRoute> fromLine(List<GeoPoint> waypoints, List<GeoPoint> linha) async {
    final amostras = resample(linha, sampleStepM);
    final relevo = await _relevo(amostras) ?? (alts: List<double>.filled(amostras.length, 0), versao: 0);
    final pontos = [
      for (var i = 0; i < amostras.length; i++)
        ProfilePoint(_round(amostras[i].lat, 6), _round(amostras[i].lon, 6), _round(relevo.alts[i], 1)),
    ];
    final perfil = RouteProfile(pontos);
    return BuiltRoute(
      RouteRecord(
        id: _newId(),
        name: '',
        createdAt: _now(),
        waypoints: List.of(waypoints),
        points: pontos,
        distanceM: perfil.distance,
        gainM: perfil.gain,
        lossM: perfil.loss,
        relief: relevo.versao,
      ),
      flat: relevo.versao == 0,
    );
  }

  /// Refaz o relevo de uma rota salva (mesmos pontos), com as pontes e os túneis em reta.
  /// null = não deu agora (sem internet ou serviço fora do ar); tente de novo depois.
  Future<RouteRecord?> refreshRelief(RouteRecord rota) async {
    final relevo = await _relevo([for (final p in rota.points) p.geo]);
    if (relevo == null || relevo.versao < reliefVersion) return null;
    final pontos = [
      for (var i = 0; i < rota.points.length; i++)
        ProfilePoint(rota.points[i].lat, rota.points[i].lon, _round(relevo.alts[i], 1)),
    ];
    final perfil = RouteProfile(pontos);
    return rota.copyWith(points: pontos, gainM: perfil.gain, lossM: perfil.loss, relief: relevo.versao);
  }

  /// Altitude suavizada de cada ponto, com pontes e túneis em reta. Se o serviço das pontes
  /// falhar, fica a altitude do terreno (versão 1). null = a altitude falhou.
  Future<({List<double> alts, int versao})?> _relevo(List<GeoPoint> pontos) async {
    final List<double> brutas;
    try {
      brutas = await elevation.elevations(pontos);
    } catch (_) {
      return null;
    }
    try {
      final pontes = await routing.structures(pontos);
      final retas = flattenStructures(cumulativeDistances(pontos), brutas, pontes);
      return (alts: smoothElevations(retas), versao: reliefVersion);
    } catch (_) {
      return (alts: smoothElevations(brutas), versao: 1);
    }
  }
}
