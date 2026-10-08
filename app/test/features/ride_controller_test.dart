import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';

import '../support/fakes.dart';
import '../support/geo_helpers.dart';

RouteRecord rotaDeTeste(String id, List<double> alts) {
  final pontos = northProfile(alts);
  return RouteRecord(
    id: id,
    name: 'Rua de teste',
    createdAt: DateTime(2026, 10, 8),
    waypoints: [pontos.first.geo, pontos.last.geo],
    points: pontos,
    distanceM: (alts.length - 1) * 20.0,
    gainM: 0,
    lossM: 0,
  );
}

void main() {
  late FakeBikeSource bike;
  late FakeWakeLock wake;
  late MemoryRidesStore rides;
  late MemoryRoutesStore routes;
  late ProviderContainer container;
  late DateTime agora;

  setUp(() async {
    bike = FakeBikeSource();
    wake = FakeWakeLock();
    rides = MemoryRidesStore();
    routes = MemoryRoutesStore();
    agora = DateTime(2026, 10, 8, 20);
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      routesStoreProvider.overrideWithValue(routes),
      wakeLockProvider.overrideWithValue(wake),
      clockProvider.overrideWithValue(() => agora),
      rideIdProvider.overrideWithValue(() => 'p1'),
      rideTickProvider.overrideWithValue(const Duration(hours: 1)),
      reconnectDelaysProvider.overrideWithValue(const [Duration(hours: 1)]),
    ]);
    addTearDown(container.dispose);
    await container.read(bikeControllerProvider.notifier).useSource(bike);
  });

  RideController ctrl(String? rota) {
    container.listen(rideProvider(rota), (anterior, proximo) {});
    return container.read(rideProvider(rota).notifier);
  }

  RideView view(String? rota) => container.read(rideProvider(rota));

  Future<void> pedalar(String? rota, int segundos, {int? power = 150, double cadence = 80}) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      bike.emitReading(BikeReading(cadence: cadence, power: power, timestamp: agora));
      await settle();
      ctrl(rota).tick();
    }
  }

  group('pedal livre', () {
    test('start liga a tela, salva o pedal e começa pedalando', () async {
      await ctrl(null).start();
      expect(wake.enabled, isTrue);
      expect(view(null).started, isTrue);
      expect(view(null).state, RideState.pedalando);
      expect(view(null).isRoute, isFalse);
      final salvo = await rides.byId('p1');
      expect(salvo!.completed, isFalse);
      expect(salvo.mode, RideMode.livre);
    });

    test('pedalando com 150 W ganha velocidade e grava o histórico de potência', () async {
      await ctrl(null).start();
      await pedalar(null, 10);
      expect(view(null).speedKmh, greaterThan(15));
      expect(view(null).distance, greaterThan(0));
      expect(view(null).power, 150);
      expect(view(null).powerHistory.length, 10);
    });

    test('sem leitura por mais de 3 s, a potência zera', () async {
      await ctrl(null).start();
      await pedalar(null, 5);
      for (var i = 0; i < 16; i++) {
        agora = agora.add(const Duration(milliseconds: 250));
        ctrl(null).tick();
      }
      expect(view(null).power, 0);
    });

    test('carga muda entre 1 e 10; pausar e continuar', () async {
      await ctrl(null).start();
      for (var i = 0; i < 20; i++) {
        ctrl(null).changeLevel(1);
      }
      expect(view(null).level, 10);
      ctrl(null).togglePause();
      expect(view(null).state, RideState.pausado);
      ctrl(null).togglePause();
      expect(view(null).state, RideState.pedalando);
    });

    test('queda da bike pausa; reconexão retoma', () async {
      await ctrl(null).start();
      await pedalar(null, 3);
      bike.emitConnection(BikeConnection.caiu);
      await settle();
      expect(view(null).pausedByBike, isTrue);
      expect(view(null).state, RideState.pausado);
      bike.emitConnection(BikeConnection.conectada);
      await settle();
      expect(view(null).state, RideState.pedalando);
    });

    test('finish salva concluído, desliga a tela e é idempotente', () async {
      await ctrl(null).start();
      await pedalar(null, 12);
      expect(await ctrl(null).finish(), 'p1');
      expect(await ctrl(null).finish(), 'p1');
      final salvo = await rides.byId('p1');
      expect(salvo!.completed, isTrue);
      expect(salvo.samples.length, greaterThanOrEqualTo(12));
      expect(wake.enabled, isFalse);
    });
  });

  group('pedal na rota', () {
    test('anda pela rota, mostra a posição e conclui no fim', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760))); // 100 m planos
      await ctrl('r').start();
      expect(view('r').isRoute, isTrue);
      expect(view('r').routeName, 'Rua de teste');
      expectNear(view('r').total, 100, 0.5);
      final inicio = view('r').position!;
      for (var s = 0; s < 120 && view('r').state != RideState.concluido; s++) {
        await pedalar('r', 1);
      }
      expect(view('r').state, RideState.concluido);
      expect(view('r').position!.lat, greaterThan(inicio.lat));
      await ctrl('r').finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.mode, RideMode.rota);
      expect(salvo.routeId, 'r');
      expect(salvo.completed, isTrue);
    });

    test('avisa a subida que vem pela frente', () async {
      await routes.upsert(rotaDeTeste('s', [for (var i = 0; i < 16; i++) 760 + i * 1.2])); // 6 %
      await ctrl('s').start();
      await pedalar('s', 2);
      expect(view('s').alert?.kind, AlertKind.subida);
      expect(view('s').alertAt, isNotNull);
      expect(view('s').grade, closeTo(0.06, 0.001));
    });

    test('rota que não existe', () async {
      await ctrl('nada').start();
      expect(view('nada').notFound, isTrue);
      expect(view('nada').started, isFalse);
      expect(wake.enabled, isFalse);
    });

    test('posição começa no primeiro ponto', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760)));
      await ctrl('r').start();
      final p = view('r').position!;
      expect(p, isA<GeoPoint>());
      expectNear(p.lat, -23.5, 1e-9);
    });
  });
}
