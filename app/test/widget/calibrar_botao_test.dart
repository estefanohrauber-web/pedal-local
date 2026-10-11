import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
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

void main() {
  testWidgets('calibrar o botão: toca a cada volta, desfaz e guarda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2070);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ajustes = MemorySettingsStore();
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
        ],
        child: const PedalLocalApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PedalLocalApp)),
    );
    container.read(appRouterProvider).push('/bike/botao');
    await tester.pumpAndSettle();

    expect(find.text('Toque a cada volta completa'), findsOneWidget);
    final contar = find.byKey(const Key('contar-volta'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(contar);
      await tester.pump();
    }
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Desfazer o último toque'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Cheguei no mais pesado'));
    await tester.pumpAndSettle();
    expect(find.text('Pronto! Seu botão dá 2 voltas.'), findsOneWidget);
    expect((await ajustes.load()).voltasBotao, 2);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Calibrar o botão'), findsNothing);
  });
}
