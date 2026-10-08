import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/core/router/app_router.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/workout.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';

import '../support/fakes.dart';

const _curto = Workout(id: 'curto', name: 'Treino curto', summary: 'Dois trechos.', category: 'Intervalos', steps: [
  WorkoutStep(10, 0.5),
  WorkoutStep(10, 1.0, cue: 'Forte!'),
]);
const _rampa = Workout(id: 'rampa', name: 'Rampa curta', summary: 'Teste.', category: 'Teste', rampTest: true, steps: [
  WorkoutStep(10, 0.4),
  WorkoutStep(60, 0.5),
  WorkoutStep(60, 0.56),
  WorkoutStep(60, 0.62),
  WorkoutStep(20, 0.4),
]);

Future<ProviderContainer> _abrir(
  WidgetTester tester, {
  required MemorySettingsStore settings,
  MemoryRidesStore? rides,
}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      ridesStoreProvider.overrideWithValue(rides ?? MemoryRidesStore()),
      routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      voiceProvider.overrideWithValue(FakeVoice()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
      workoutLookupProvider.overrideWithValue((id) => {'curto': _curto, 'rampa': _rampa}[id] ?? workoutById(id)),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

Finder get _lista => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// Pedala até [fim] aparecer (no máximo [segundos] de pedal), com a bike mandando [watts].
Future<void> _pedalarAte(WidgetTester tester, FakeBikeSource bike, Finder fim, {int segundos = 120, int watts = 150}) async {
  for (var i = 0; i < segundos * 2 && fim.evaluate().isEmpty; i++) {
    bike.emitReading(BikeReading(cadence: 85, power: watts, timestamp: clock.now()));
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets('aba Treinos: FTP estimado, começar um plano e ver o próximo treino', (tester) async {
    final settings = MemorySettingsStore(const AppSettings(pesoKg: 75));
    await _abrir(tester, settings: settings);
    await tester.tap(find.text('Treinos').last);
    await tester.pumpAndSettle();
    expect(find.text('150 W'), findsOneWidget);
    expect(find.text('FTP estimado pelo seu peso'), findsOneWidget);
    expect(find.text('Fazer o teste de rampa · 20 min'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Começando · 4 semanas'), 200, scrollable: _lista);
    await tester.tap(find.text('Começando · 4 semanas'));
    await tester.pumpAndSettle();
    expect(find.text('Semana 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Começar este plano'), 300, scrollable: _lista);
    await tester.tap(find.text('Começar este plano'));
    await tester.pumpAndSettle();
    expect((await settings.load()).planoId, 'comecando');
    await tester.scrollUntilVisible(find.text('Parar este plano'), 300, scrollable: _lista);
    expect(find.text('Parar este plano'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Próximo treino'), 200, scrollable: _lista);
    expect(find.text('Semana 1 de 4 · 0 de 12 treinos'), findsOneWidget);
    expect(find.text('Primeiro giro'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Sweet spot 2 × 10 min'), 400, scrollable: _lista);
    expect(find.text('40 min · Difícil'), findsWidgets);
  });

  testWidgets('treino do começo ao fim: a bike segura a meta, termina sozinho e pergunta como foi', (tester) async {
    final settings = MemorySettingsStore(const AppSettings(ftp: 200));
    final container = await _abrir(tester, settings: settings);
    final bike = FakeBikeSource()..control = FakeBikeControl();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/treino/curto');
    await tester.pumpAndSettle();
    expect(find.text('Trechos'), findsOneWidget);
    expect(find.text('Muito leve · 100 W'), findsOneWidget);
    expect(find.text('A bike ajusta a carga sozinha'), findsOneWidget);
    await tester.tap(find.text('Começar treino'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Muito leve'), findsOneWidget);
    expect(find.text('100 W'), findsOneWidget);
    expect((bike.control! as FakeBikeControl).powers.first, 100);

    await _pedalarAte(tester, bike, find.text('Forte!'));
    expect(find.text('200 W'), findsOneWidget);
    expect((bike.control! as FakeBikeControl).powers.last, 200);

    await _pedalarAte(tester, bike, find.text('Treino concluído!'));
    await tester.pumpAndSettle();
    expect(find.text('Treino concluído!'), findsOneWidget);
    expect(find.text('Como foi o treino?'), findsOneWidget);
    await tester.tap(find.text('Fácil'));
    await tester.pumpAndSettle();
    expect(find.text('Anotado! As metas dos próximos treinos vão subir 3%.'), findsOneWidget);
    expect((await settings.load()).intensidade, 1.03);
  });

  testWidgets('teste de rampa: “Não aguento mais” mostra e guarda o FTP', (tester) async {
    final settings = MemorySettingsStore(const AppSettings(ftp: 200));
    final container = await _abrir(tester, settings: settings);
    final bike = FakeBikeSource();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/treino/rampa');
    await tester.pumpAndSettle();
    expect(find.text('Como funciona'), findsOneWidget);
    await tester.tap(find.text('Começar o teste'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _pedalarAte(tester, bike, find.text('Não aguento mais'));
    // Mais de um minuto de rampa a 150 W antes de desistir.
    for (var i = 0; i < 140; i++) {
      bike.emitReading(BikeReading(cadence: 85, power: 150, timestamp: clock.now()));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.ensureVisible(find.text('Não aguento mais'));
    await tester.tap(find.text('Não aguento mais'));
    await tester.pump();
    expect(find.text('Seu FTP: 113 W. Agora, pedal leve para soltar.'), findsOneWidget);
    await _pedalarAte(tester, bike, find.text('Treino concluído!'), watts: 80);
    await tester.pumpAndSettle();
    expect(find.text('Seu FTP: 113 W'), findsOneWidget);
    expect((await settings.load()).ftp, 113);
  });
}
