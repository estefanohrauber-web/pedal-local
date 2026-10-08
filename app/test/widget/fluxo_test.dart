import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';

import '../support/fakes.dart';

/// Celular pequeno (360 × 690 dp) para pegar textos e caixas que não cabem.
void celularPequeno(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> abrirApp(WidgetTester tester, MemoryRidesStore rides) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      voiceProvider.overrideWithValue(FakeVoice()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

void main() {
  testWidgets('todas as abas cabem num celular pequeno', (tester) async {
    celularPequeno(tester);
    await abrirApp(tester, MemoryRidesStore());
    for (final aba in ['Explorar', 'Treinos', 'Você', 'Início']) {
      await tester.tap(find.text(aba).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('pedal livre completo: pedalar, encerrar e ver o resumo', (tester) async {
    celularPequeno(tester);
    final rides = MemoryRidesStore();
    final container = await abrirApp(tester, rides);
    final bike = FakeBikeSource(name: 'FS-TESTE');
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    await tester.pumpAndSettle();
    expect(find.text('FS-TESTE'), findsOneWidget);

    await tester.tap(find.text('Pedal livre').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Encerrar'), findsOneWidget);
    expect(find.text('Carga 4'), findsOneWidget);

    await tester.tap(find.byTooltip('Aumentar carga'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Carga 5'), findsOneWidget);

    await tester.tap(find.text('Pausar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.textContaining('Pedal pausado'), findsOneWidget);

    await tester.tap(find.text('Encerrar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Encerrar o pedal?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Pedal concluído!'), findsOneWidget);
    expect((await rides.recent()).single.completed, isTrue);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Último pedal'), findsOneWidget);
  });
}
