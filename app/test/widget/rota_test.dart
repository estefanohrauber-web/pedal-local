import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/fakes.dart';
import '../support/geo_helpers.dart';

RouteRecord rotaDeTeste(String id, String nome, int pontos) {
  final perfil = northProfile(List.filled(pontos, 760));
  return RouteRecord(
    id: id,
    name: nome,
    createdAt: DateTime(2026, 10, 8),
    waypoints: [perfil.first.geo, perfil.last.geo],
    points: perfil,
    distanceM: (pontos - 1) * 20.0,
    gainM: 0,
    lossM: 0,
  );
}

/// Serviços falsos: OSRM devolve uma reta de 100 m; altimetria sobe 1 m a cada ponto.
MockClient servicosFalsos() => MockClient((req) async {
      if (req.url.host == 'routing.openstreetmap.de') {
        final linha = northLine(2, 100);
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    for (final p in linha) [p.lon, p.lat],
                  ],
                },
              },
            ],
          }),
          200,
        );
      }
      final k = req.url.queryParameters['latitude']!.split(',').length;
      return http.Response(jsonEncode({'elevation': [for (var i = 0; i < k; i++) 700 + i]}), 200);
    });

Future<ProviderContainer> abrirApp(WidgetTester tester, {required MemoryRoutesStore routes, MemoryRidesStore? rides}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final client = servicosFalsos();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides ?? MemoryRidesStore()),
      routesStoreProvider.overrideWithValue(routes),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(GeoPoint(-23.5, -46.6))),
      routeBuilderProvider.overrideWithValue(
        RouteBuilder(routing: RoutingService(client), elevation: ElevationService(client)),
      ),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

void main() {
  testWidgets('Explorar mostra as rotas salvas, mesmo num celular pequeno', (tester) async {
    tester.view.physicalSize = const Size(1080, 2070);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final routes = MemoryRoutesStore();
    await routes.upsert(rotaDeTeste('r1', 'Volta do bairro pela praça e pela padaria', 6));
    await abrirApp(tester, routes: routes);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    expect(find.text('Minhas rotas'), findsOneWidget);
    expect(find.text('Volta do bairro pela praça e pela padaria'), findsOneWidget);
    expect(find.text('Pedalar esta rota'), findsOneWidget);
  });

  testWidgets('criar rota: tocar pontos, calcular e salvar', (tester) async {
    final routes = MemoryRoutesStore();
    await abrirApp(tester, routes: routes);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar rota'));
    await tester.pumpAndSettle();
    expect(find.text('Toque no mapa para marcar o início.'), findsOneWidget);

    final mapa = tester.getRect(find.byKey(const Key('mapa-criar-rota')));
    await tester.tapAt(mapa.center.translate(-60, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(mapa.center.translate(60, -60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('2 pontos'), findsOneWidget);

    await tester.tap(find.text('Calcular rota'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar rota'), findsOneWidget);
    expect(find.textContaining('0,10 km'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Rua de casa');
    await tester.tap(find.text('Salvar rota'));
    await tester.pumpAndSettle();
    expect((await routes.all()).single.name, 'Rua de casa');
    expect(find.text('Rua de casa'), findsOneWidget);
  });

  testWidgets('pedalar uma rota até o fim leva ao resumo', (tester) async {
    final routes = MemoryRoutesStore();
    final rides = MemoryRidesStore();
    await routes.upsert(rotaDeTeste('r1', 'Rua curta', 7)); // 120 m
    final container = await abrirApp(tester, routes: routes, rides: rides);
    final bike = FakeBikeSource(name: 'FS-TESTE');
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedalar esta rota'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rua curta'), findsOneWidget);

    for (var i = 0; i < 120 && find.text('Rota concluída!').evaluate().isEmpty; i++) {
      bike.emitReading(BikeReading(cadence: 85, power: 250, timestamp: clock.now()));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.text('Rota concluída!'), findsOneWidget);
    final pedal = (await rides.recent()).single;
    expect(pedal.mode, RideMode.rota);
    expect(pedal.routeId, 'r1');
    expect(pedal.completed, isTrue);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Último pedal'), findsOneWidget);
    // Cartão da rota no topo + pedal no histórico, ambos com o nome da rota.
    expect(find.text('Rua curta'), findsNWidgets(2));
  });
}
