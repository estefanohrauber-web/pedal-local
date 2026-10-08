import '../domain/geo.dart';
import '../domain/route_profile.dart';
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

  Future<BuiltRoute> build(List<GeoPoint> waypoints) async {
    final linha = await routing.route(waypoints);
    final amostras = resample(linha, sampleStepM);
    List<double> alts;
    var flat = false;
    try {
      alts = smoothElevations(await elevation.elevations(amostras));
    } catch (_) {
      alts = List.filled(amostras.length, 0);
      flat = true;
    }
    final pontos = [
      for (var i = 0; i < amostras.length; i++)
        ProfilePoint(_round(amostras[i].lat, 6), _round(amostras[i].lon, 6), _round(alts[i], 1)),
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
      ),
      flat: flat,
    );
  }
}
