import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_log.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/core/widgets/pedalaqui_logo.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/features/abertura/abertura.dart';

import '../support/fakes.dart';

Future<void> _abrirApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        ridesStoreProvider.overrideWithValue(MemoryRidesStore()),
        routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
        wakeLockProvider.overrideWithValue(FakeWakeLock()),
        voiceProvider.overrideWithValue(FakeVoice()),
        mapTilesEnabledProvider.overrideWithValue(false),
        locationServiceProvider.overrideWithValue(
          const FixedLocationService(null),
        ),
        bikeLogProvider.overrideWithValue(BikeLog()),
      ],
      child: const PedalLocalApp(),
    ),
  );
}

void main() {
  testWidgets(
    'abertura: a rota se desenha, o nome aparece e tudo some no app',
    (tester) async {
      await _abrirApp(tester);
      await tester.pump();
      expect(find.byKey(aberturaKey), findsOneWidget);
      final inicio = tester.widget<PedalaquiMark>(find.byType(PedalaquiMark));
      expect(inicio.progress, lessThan(0.1)); // a linha começa a se desenhar
      await tester.pump(const Duration(milliseconds: 800));
      final meio = tester.widget<PedalaquiMark>(find.byType(PedalaquiMark));
      expect(meio.progress, 1);
      expect(meio.dot, greaterThan(0));
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // 1,3 s: o nome já apareceu inteiro
      final nome = find.descendant(
        of: find.byKey(aberturaKey),
        matching: find.byType(PedalaquiWordmark),
      );
      expect(nome, findsOneWidget);
      final opacidade = tester.widget<Opacity>(
        find.ancestor(of: nome, matching: find.byType(Opacity)).first,
      );
      expect(opacidade.opacity, closeTo(1, 0.01));
      await tester.pumpAndSettle();
      expect(find.byKey(aberturaKey), findsNothing);
      expect(find.text('Bora pedalar?'), findsOneWidget);
    },
  );

  testWidgets('abertura: um toque pula para o app', (tester) async {
    await _abrirApp(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(aberturaKey));
    await tester.pump(); // o resto da animação começa a contar neste quadro
    await tester.pump(
      const Duration(milliseconds: 400),
    ); // termina em menos de 0,3 s
    await tester.pump();
    expect(find.byKey(aberturaKey), findsNothing);
  });
}
