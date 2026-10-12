import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_scanner.dart';
import 'package:pedal_local/core/router/app_router.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/custom_workouts_store.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';

import '../support/fakes.dart';

/// Scanner que sempre acha as bikes dadas, sem Bluetooth.
class _ScannerFalso extends BikeScanner {
  _ScannerFalso(this.bikes);

  final List<FoundDevice> bikes;

  @override
  Future<BleProblem?> check() async => null;

  @override
  Stream<List<FoundDevice>> scan({
    Duration duration = const Duration(seconds: 12),
  }) => Stream.value(bikes);
}

/// Passa um tempo na tela sem esperar ela parar (a rodinha de “esperando” gira sem parar).
Future<void> passar(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('abrir a tela enquanto o app ainda reconecta a bike de sempre: não conecta duas vezes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bike = FakeBikeSource(name: 'WINNEK BT-151')..hold = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(
            MemorySettingsStore(const AppSettings(ultimaBikeId: 'AA', ultimaBikeNome: 'WINNEK BT-151')),
          ),
          ridesStoreProvider.overrideWithValue(MemoryRidesStore()),
          routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
          customWorkoutsStoreProvider.overrideWithValue(MemoryCustomWorkoutsStore()),
          wakeLockProvider.overrideWithValue(FakeWakeLock()),
          voiceProvider.overrideWithValue(FakeVoice()),
          mapTilesEnabledProvider.overrideWithValue(false),
          ftmsFactoryProvider.overrideWithValue((id, nome) => bike),
          bikeScannerProvider.overrideWithValue(
            _ScannerFalso(const [FoundDevice(id: 'AA', name: 'WINNEK BT-151', likelyBike: true)]),
          ),
        ],
        child: const PedalLocalApp(),
      ),
    );
    await passar(tester); // ao abrir, o app já tenta a bike de sempre (e ela demora)
    final container = ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
    expect(bike.connectCalls, 1);
    container.read(appRouterProvider).push('/bike');
    await passar(tester);
    expect(bike.connectCalls, 1); // a busca achou a mesma bike, mas ela já estava conectando
    bike.hold!.complete();
    await passar(tester);
    expect(container.read(bikeControllerProvider).connected, isTrue);
  });

  testWidgets(
    'conectar: a bike de sempre conecta sozinha e a lista mostra os dados chegando',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final ajustes = MemorySettingsStore();
      final bike = FakeBikeSource(name: 'WINNEK BT-151');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(ajustes),
            ridesStoreProvider.overrideWithValue(MemoryRidesStore()),
            routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
            customWorkoutsStoreProvider.overrideWithValue(
              MemoryCustomWorkoutsStore(),
            ),
            wakeLockProvider.overrideWithValue(FakeWakeLock()),
            voiceProvider.overrideWithValue(FakeVoice()),
            mapTilesEnabledProvider.overrideWithValue(false),
            ftmsFactoryProvider.overrideWithValue((id, nome) => bike),
            bikeScannerProvider.overrideWithValue(
              _ScannerFalso(const [
                FoundDevice(id: 'AA', name: 'WINNEK BT-151', likelyBike: true),
                FoundDevice(id: 'BB', name: 'FS-A3021', likelyBike: true),
              ]),
            ),
          ],
          child: const PedalLocalApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PedalLocalApp)),
      );
      // A bike de sempre fica gravada depois de abrir (ao abrir, o app já tentaria conectar).
      await ajustes.save(
        const AppSettings(ultimaBikeId: 'AA', ultimaBikeNome: 'WINNEK BT-151'),
      );
      container.invalidate(settingsProvider);
      await container.read(settingsProvider.future);
      container.read(appRouterProvider).push('/bike');
      await passar(tester);

      expect(find.text('Bluetooth ligado'), findsOneWidget);
      expect(find.text('WINNEK BT-151 encontrada'), findsOneWidget);
      expect(find.text('Conectada'), findsOneWidget);
      expect(find.text('Pronto, pedalar'), findsOneWidget);
      expect(
        find.text('FS-A3021'),
        findsOneWidget,
      ); // a outra bike, para trocar
      expect(find.textContaining('Tudo certo'), findsNothing);

      // Pacotes zerados: a bike responde, mas está parada.
      bike.emitReading(
        BikeReading(
          cadence: 0,
          power: 0,
          speedKmh: 0,
          timestamp: DateTime(2026),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('pedale um pouco para conferir'),
        findsOneWidget,
      );

      bike.emitReading(
        BikeReading(
          cadence: 62,
          power: 152,
          speedKmh: 23.2,
          timestamp: DateTime(2026),
        ),
      );
      await tester.pump();
      expect(find.text('62 rpm'), findsOneWidget);
      expect(
        find.text(
          'Tudo certo: giro, potência e velocidade estão vindo da bike.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Pronto, pedalar'));
      await passar(tester);
      expect(find.text('Conectar bike'), findsNothing);
    },
  );
}
