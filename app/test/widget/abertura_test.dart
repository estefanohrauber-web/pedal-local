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

Future<void> _abrirApp(WidgetTester tester, {bool linhaPronta = false}) async {
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
        locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
        bikeLogProvider.overrideWithValue(BikeLog()),
        aberturaLinhaProntaProvider.overrideWithValue(linhaPronta),
      ],
      child: const PedalLocalApp(),
    ),
  );
}

PedalaquiMark _marca(WidgetTester t) => t.widget<PedalaquiMark>(find.byType(PedalaquiMark));
PedalaquiWordmark _nome(WidgetTester t) => t.widget<PedalaquiWordmark>(find.byType(PedalaquiWordmark));
RevealMask _revela(WidgetTester t) => t.widget<RevealMask>(find.byType(RevealMask));

void main() {
  testWidgets('abertura: a rota se desenha; depois a bolinha com o anel, o nome e o pininho; a bolinha abre o app', (tester) async {
    await _abrirApp(tester);
    await tester.pump();
    expect(find.byKey(aberturaKey), findsOneWidget);
    expect(_marca(tester).progress, lessThan(0.05)); // a linha começa do zero
    expect(_revela(tester).fraction, 0); // o nome só depois da linha

    await tester.pump(const Duration(milliseconds: 400)); // no meio do caminho
    expect(_marca(tester).progress, inExclusiveRange(0.2, 0.9));
    expect(_marca(tester).dot, 0);
    expect(_revela(tester).fraction, 0);
    expect(find.text('Bora pedalar?'), findsNothing); // o app por baixo ainda não foi montado

    await tester.pump(const Duration(milliseconds: 550)); // 0,95 s: linha pronta, bolinha e nome chegando
    expect(_marca(tester).progress, 1);
    expect(_marca(tester).dot, greaterThan(0));
    expect(_marca(tester).ring, inExclusiveRange(0, 1)); // o anel se espalhando
    expect(_revela(tester).fraction, greaterThan(0.3));

    await tester.pump(const Duration(milliseconds: 650)); // 1,6 s: logo completa, parada
    expect(_marca(tester).dot, closeTo(1, 0.01));
    expect(_nome(tester).pin, closeTo(1, 0.01));
    expect(_revela(tester).fraction, 1);
    expect(find.text('Bora pedalar?'), findsOneWidget); // o app já está pronto por baixo

    await tester.pumpAndSettle();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('abertura: com a linha já desenhada pela tela de carregamento, continua dali', (tester) async {
    await _abrirApp(tester, linhaPronta: true);
    await tester.pump();
    expect(_marca(tester).progress, 1);
    expect(_marca(tester).dot, 0);
    expect(_revela(tester).fraction, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_marca(tester).dot, closeTo(1, 0.01));
    expect(_revela(tester).fraction, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('abertura: um toque pula para a transição', (tester) async {
    await _abrirApp(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(aberturaKey));
    await tester.pump(); // a transição começa a contar neste quadro
    await tester.pump(const Duration(milliseconds: 500)); // termina em menos de 0,5 s
    await tester.pump();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });
}
