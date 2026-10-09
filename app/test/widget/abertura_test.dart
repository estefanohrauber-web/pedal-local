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
        locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
        bikeLogProvider.overrideWithValue(BikeLog()),
      ],
      child: const PedalLocalApp(),
    ),
  );
}

void main() {
  testWidgets('abertura: a rota se desenha com o nome, depois a bolinha e o pininho; tudo some no app', (tester) async {
    await _abrirApp(tester);
    await tester.pump();
    expect(find.byKey(aberturaKey), findsOneWidget);
    PedalaquiMark marca() => tester.widget<PedalaquiMark>(find.byType(PedalaquiMark));
    PedalaquiWordmark nome() => tester.widget<PedalaquiWordmark>(find.byType(PedalaquiWordmark));
    RevealMask revela() => tester.widget<RevealMask>(find.byType(RevealMask));
    expect(marca().progress, lessThan(0.05)); // a linha começa do zero
    expect(revela().fraction, lessThan(0.05));

    await tester.pump(const Duration(milliseconds: 600)); // no meio do caminho
    expect(marca().progress, inExclusiveRange(0.2, 0.9));
    expect(revela().fraction, inExclusiveRange(0.05, 0.95)); // o nome vem junto com a linha
    expect(marca().dot, 0); // a bolinha só depois do caminho pronto
    expect(nome().pin, 0);
    expect(find.text('Bora pedalar?'), findsNothing); // o app por baixo ainda não foi montado

    await tester.pump(const Duration(milliseconds: 700)); // 1,3 s: caminho pronto, bolinha aparecendo
    expect(marca().progress, 1);
    expect(revela().fraction, 1);
    expect(marca().dot, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 300)); // 1,6 s: tudo inteiro
    expect(marca().dot, closeTo(1, 0.01));
    expect(nome().pin, closeTo(1, 0.01));

    await tester.pumpAndSettle();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('abertura: um toque pula para o app', (tester) async {
    await _abrirApp(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(aberturaKey));
    await tester.pump(); // o resto da animação começa a contar neste quadro
    await tester.pump(const Duration(milliseconds: 400)); // termina em menos de 0,3 s
    await tester.pump();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });
}
