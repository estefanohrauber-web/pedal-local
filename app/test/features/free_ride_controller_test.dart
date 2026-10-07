import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/features/pedal_livre/free_ride_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeBikeSource bike;
  late FakeWakeLock wake;
  late MemoryRidesStore rides;
  late ProviderContainer container;
  late DateTime agora;

  setUp(() async {
    bike = FakeBikeSource();
    wake = FakeWakeLock();
    rides = MemoryRidesStore();
    agora = DateTime(2026, 10, 7, 20);
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      wakeLockProvider.overrideWithValue(wake),
      clockProvider.overrideWithValue(() => agora),
      rideIdProvider.overrideWithValue(() => 'r1'),
      rideTickProvider.overrideWithValue(const Duration(hours: 1)),
      reconnectDelaysProvider.overrideWithValue(const [Duration(hours: 1)]),
    ]);
    addTearDown(container.dispose);
    container.listen(freeRideProvider, (anterior, proximo) {});
    await container.read(bikeControllerProvider.notifier).useSource(bike);
  });

  FreeRideController ctrl() => container.read(freeRideProvider.notifier);
  FreeRideView view() => container.read(freeRideProvider);

  Future<void> pedalar(int segundos, {int? power = 150, double cadence = 80}) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      bike.emitReading(BikeReading(cadence: cadence, power: power, timestamp: agora));
      await settle();
      ctrl().tick();
    }
  }

  Future<void> esperar(int segundos) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      ctrl().tick();
    }
  }

  test('start liga a tela, salva o pedal e começa pedalando', () async {
    await ctrl().start();
    expect(wake.enabled, isTrue);
    expect(view().started, isTrue);
    expect(view().state, RideState.pedalando);
    final salvo = await rides.byId('r1');
    expect(salvo!.completed, isFalse);
    expect(salvo.mode, RideMode.livre);
  });

  test('pedalando com 150 W ganha velocidade e grava o histórico de potência', () async {
    await ctrl().start();
    await pedalar(10);
    expect(view().speedKmh, greaterThan(15));
    expect(view().distance, greaterThan(0));
    expect(view().power, 150);
    expect(view().powerHistory.length, 10);
  });

  test('sem leitura por mais de 3 s, a potência zera', () async {
    await ctrl().start();
    await pedalar(5);
    await esperar(4);
    expect(view().power, 0);
  });

  test('carga muda entre 1 e 10', () async {
    await ctrl().start();
    for (var i = 0; i < 20; i++) {
      ctrl().changeLevel(1);
    }
    expect(view().level, 10);
    for (var i = 0; i < 20; i++) {
      ctrl().changeLevel(-1);
    }
    expect(view().level, 1);
  });

  test('pausar e continuar', () async {
    await ctrl().start();
    await pedalar(3);
    ctrl().togglePause();
    expect(view().state, RideState.pausado);
    ctrl().togglePause();
    expect(view().state, RideState.pedalando);
  });

  test('queda da bike pausa; reconexão retoma', () async {
    await ctrl().start();
    await pedalar(3);
    bike.emitConnection(BikeConnection.caiu);
    await settle();
    expect(view().state, RideState.pausado);
    expect(view().pausedByBike, isTrue);
    bike.emitConnection(BikeConnection.conectada);
    await settle();
    expect(view().state, RideState.pedalando);
    expect(view().pausedByBike, isFalse);
  });

  test('finish salva concluído com amostras e desliga a tela', () async {
    await ctrl().start();
    await pedalar(12);
    final id = await ctrl().finish();
    expect(id, 'r1');
    final salvo = await rides.byId('r1');
    expect(salvo!.completed, isTrue);
    expect(salvo.samples.length, greaterThanOrEqualTo(12));
    expect(salvo.distanceM, greaterThan(0));
    expect(salvo.avgPowerW, greaterThan(100));
    expect(wake.enabled, isFalse);
  });
}
