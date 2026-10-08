import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'rides_store.dart';
import 'route_builder.dart';
import 'routes_store.dart';
import 'services/elevation_service.dart';
import 'services/location_service.dart';
import 'services/request_pacer.dart';
import 'services/routing_service.dart';
import 'settings_store.dart';

/// Aberto no main() e sobrescrito no ProviderScope.
final databaseProvider = Provider<Database>(
  (ref) => throw StateError('Abra o banco no main() e sobrescreva databaseProvider.'),
);

final settingsStoreProvider = Provider<SettingsStore>((ref) => SqliteSettingsStore(ref.watch(databaseProvider)));

final ridesStoreProvider = Provider<RidesStore>((ref) => SqliteRidesStore(ref.watch(databaseProvider)));

final routesStoreProvider = Provider<RoutesStore>((ref) => SqliteRoutesStore(ref.watch(databaseProvider)));

final settingsProvider = FutureProvider<AppSettings>((ref) => ref.watch(settingsStoreProvider).load());

final recentRidesProvider = FutureProvider<List<RideRecord>>((ref) => ref.watch(ridesStoreProvider).recent());

final rideByIdProvider = FutureProvider.family<RideRecord?, String>(
  (ref, id) => ref.watch(ridesStoreProvider).byId(id),
);

final routesProvider = FutureProvider<List<RouteRecord>>((ref) => ref.watch(routesStoreProvider).all());

final routeByIdProvider = FutureProvider.family<RouteRecord?, String>(
  (ref, id) => ref.watch(routesStoreProvider).byId(id),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Fila única para o Valhalla: rota e altitude somadas ficam em no máximo 1 pedido por segundo.
final valhallaPacerProvider = Provider<RequestPacer>((ref) => RequestPacer());

final routeBuilderProvider = Provider<RouteBuilder>((ref) {
  final client = ref.watch(httpClientProvider);
  final pacer = ref.watch(valhallaPacerProvider);
  return RouteBuilder(routing: RoutingService(client, pacer), elevation: ElevationService(client, pacer));
});

final locationServiceProvider = Provider<LocationService>((ref) => const GeolocatorLocationService());
