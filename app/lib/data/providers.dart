import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../domain/stats.dart';
import '../domain/training_plans.dart';
import '../domain/workout_blocks.dart';
import 'custom_workouts_store.dart';
import 'loop_generator.dart';
import 'rides_store.dart';
import 'route_builder.dart';
import 'routes_store.dart';
import 'services/elevation_service.dart';
import 'services/geocoding_service.dart';
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

final customWorkoutsStoreProvider = Provider<CustomWorkoutsStore>(
  (ref) => SqliteCustomWorkoutsStore(ref.watch(databaseProvider)),
);

/// Os treinos montados pelo usuário, o mais novo primeiro.
final customWorkoutsProvider = FutureProvider<List<CustomWorkout>>((ref) => ref.watch(customWorkoutsStoreProvider).all());

final settingsProvider = FutureProvider<AppSettings>((ref) => ref.watch(settingsStoreProvider).load());

final recentRidesProvider = FutureProvider<List<RideRecord>>((ref) => ref.watch(ridesStoreProvider).recent());

/// Números de todos os pedais (totais e semana da aba Você).
final rideStatsProvider = FutureProvider<List<RideStat>>((ref) => ref.watch(ridesStoreProvider).stats());

/// Pedais de uma rota (comparação no resumo). Lido de novo a cada abertura.
final ridesForRouteProvider = FutureProvider.autoDispose.family<List<RideRecord>, String>(
  (ref, routeId) => ref.watch(ridesStoreProvider).forRoute(routeId),
);

/// Pedais de uma rota com as amostras, para correr contra o fantasma.
final ghostRidesProvider = FutureProvider.autoDispose.family<List<RideRecord>, String>(
  (ref, routeId) => ref.watch(ridesStoreProvider).forRoute(routeId, withSamples: true),
);

/// Treinos feitos até o fim (progresso do plano).
final doneWorkoutsProvider = FutureProvider<List<DoneWorkout>>((ref) => ref.watch(ridesStoreProvider).doneWorkouts());

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

/// Gerador de voltas automáticas (usa o mesmo traçado e relevo das rotas).
final loopGeneratorProvider = Provider<LoopGenerator>((ref) => LoopGenerator(ref.watch(routeBuilderProvider)));

/// Busca de endereços (Photon).
final geocodingServiceProvider = Provider<GeocodingService>((ref) => GeocodingService(ref.watch(httpClientProvider)));

final locationServiceProvider = Provider<LocationService>((ref) => const GeolocatorLocationService());
