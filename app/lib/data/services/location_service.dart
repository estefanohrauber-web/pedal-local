import 'package:geolocator/geolocator.dart';

import '../../domain/geo.dart';

/// Onde a pessoa está agora, ou `null` se não der (sem permissão, GPS desligado, demora).
abstract class LocationService {
  Future<GeoPoint?> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// Para testes: sempre devolve o mesmo ponto.
class FixedLocationService implements LocationService {
  const FixedLocationService(this.point);

  final GeoPoint? point;

  @override
  Future<GeoPoint?> current() async => point;
}
