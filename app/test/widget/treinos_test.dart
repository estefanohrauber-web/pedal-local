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
import 'package:pedal_local/data/custom_workouts_store.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/workout.dart';
import 'package:pedal_local/domain/workout_blocks.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';

import '../support/fakes.dart';

const _curto = Workout(id: 'curto', name: 'Treino curto', summary: 'Dois trechos.', category: 'Intervalos', steps: [
  WorkoutStep(10, 0.5),
  WorkoutStep(10, 1.0, cue: 'Forte!'),
]);
const _livre = Workout(id: 'livre', name: 'Com pedal livre', summary: 'Livre.', category: 'Meus treinos', steps: [
  WorkoutStep(10, 0.5),
  WorkoutStep(30, 0.5, free: true),
  WorkoutStep(10, 1.0),
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
  MemoryCustomWorkoutsStore? customs,
}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      ridesStoreProvider.overrideWithValue(rides ?? MemoryRidesStore()),
      routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
      customWorkoutsStoreProvider.overrideWithValue(customs ?? MemoryCustomWorkoutsStore()),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      voiceProvider.overrideWithValue(FakeVoice()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
      workoutLookupProvider.overrideWithValue((id) => {'curto': _curto, 'rampa': _rampa, 'livre': _livre}[id] ?? workoutById(id)),
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

  testWidgets('no pedal do treino: mais forte, +1 min e pular bloco', (tester) async {
    final settings = MemorySettingsStore(const AppSettings(ftp: 200));
    final container = await _abrir(tester, settings: settings);
    final bike = FakeBikeSource()..control = FakeBikeControl();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/treino-pedal/curto');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _pedalarAte(tester, bike, find.text('0:01 de 0:20'), segundos: 3);
    expect(find.text('100 W'), findsOneWidget);
    await tester.ensureVisible(find.text('Mais forte +5 %'));
    await tester.tap(find.text('Mais forte +5 %'));
    await tester.pump();
    expect(find.text('105 W'), findsOneWidget);
    expect(find.text('Metas +5 % neste pedal'), findsOneWidget);
    await tester.tap(find.text('+1 min'));
    await tester.pump();
    expect(find.textContaining('de 1:20'), findsOneWidget);
    await tester.tap(find.text('Pular bloco'));
    await tester.pump();
    expect(find.text('Forte!'), findsOneWidget);
    expect(find.text('210 W'), findsOneWidget);
  });

  testWidgets('no pedal livre: sem meta e sem os botões de mais leve e mais forte', (tester) async {
    final settings = MemorySettingsStore(const AppSettings(ftp: 200));
    final container = await _abrir(tester, settings: settings);
    final bike = FakeBikeSource();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/treino-pedal/livre');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Depois: 0:30 pedal livre'), findsOneWidget);
    await _pedalarAte(tester, bike, find.text('Pedal livre'), segundos: 20);
    expect(find.text('Sem meta, no seu ritmo'), findsOneWidget);
    expect(find.text('Mais leve −5 %'), findsNothing);
    expect(find.text('Pular bloco'), findsOneWidget);
  });

  testWidgets('criar um treino do zero: adiciona uma série, dá nome e salva', (tester) async {
    final customs = MemoryCustomWorkoutsStore();
    await _abrir(tester, settings: MemorySettingsStore(const AppSettings(ftp: 200)), customs: customs);
    await tester.tap(find.text('Treinos').last);
    await tester.pumpAndSettle();
    expect(find.text('Meus treinos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Criar treino'), 200, scrollable: _lista);
    await tester.tap(find.text('Criar treino'));
    await tester.pumpAndSettle();
    expect(find.text('Novo treino'), findsOneWidget);
    expect(find.text('Aquecer'), findsOneWidget);
    expect(find.text('Soltar'), findsOneWidget);
    expect(find.text('15 min · Leve · carga 7'), findsOneWidget);

    await tester.tap(find.text('Adicionar bloco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Série de tiros'));
    await tester.pumpAndSettle();
    expect(find.text('4 vezes'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar repetições'));
    await tester.pump();
    expect(find.text('5 vezes'), findsOneWidget);
    await tester.ensureVisible(find.text('Pronto'));
    await tester.enterText(find.byType(TextField).last, 'Vai!');
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    expect(find.text('Série de tiros · 5 ×'), findsOneWidget);
    expect(find.text('1 min muito forte (220\u00a0W) + 1 min muito leve'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Tiros de terça');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final salvo = (await customs.all()).single;
    expect(salvo.name, 'Tiros de terça');
    expect(salvo.blocks.map((b) => b.kind), [BlockKind.aquecer, BlockKind.serie, BlockKind.soltar]);
    expect(salvo.blocks[1].reps, 5);
    expect(salvo.blocks[1].cue, 'Vai!');
    // Depois de salvar, abre a tela do treino.
    expect(find.text('Trechos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tiro 1 de 5. Vai!'), 200, scrollable: _lista);
    expect(find.text('Tiro 1 de 5. Vai!'), findsOneWidget);
  });

  testWidgets('copiar um treino pronto e mudar a intensidade dos tiros', (tester) async {
    final customs = MemoryCustomWorkoutsStore();
    final container = await _abrir(tester, settings: MemorySettingsStore(const AppSettings(ftp: 200)), customs: customs);
    container.read(appRouterProvider).push('/treino/intervalos-5x1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copiar e editar'));
    await tester.tap(find.text('Copiar e editar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Intervalos 5 × 1 min (cópia)'), findsOneWidget);
    expect(find.text('Série de tiros · 5 ×'), findsOneWidget);
    await tester.tap(find.text('Série de tiros · 5 ×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forte').first);
    await tester.pump();
    expect(find.text('97 % · 194 W'), findsOneWidget);
    await tester.ensureVisible(find.text('Pronto'));
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final salvo = (await customs.all()).single;
    expect(salvo.name, 'Intervalos 5 × 1 min (cópia)');
    expect(salvo.blocks[1].from, 0.97);
    expect(salvo.blocks[1].reps, 5);
  });

  testWidgets('editar: sair sem salvar pergunta; apagar pede confirmação', (tester) async {
    final customs = MemoryCustomWorkoutsStore();
    await customs.upsert(CustomWorkout(
      id: 'meu-a',
      name: 'Subidas do bairro',
      blocks: [WorkoutBlock.novo(BlockKind.subida)],
      createdAt: DateTime(2026, 10, 9),
      updatedAt: DateTime(2026, 10, 9),
    ));
    await _abrir(tester, settings: MemorySettingsStore(const AppSettings(ftp: 200)), customs: customs);
    await tester.tap(find.text('Treinos').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Subidas do bairro'), 200, scrollable: _lista);
    await tester.tap(find.text('Subidas do bairro'));
    await tester.pumpAndSettle();
    expect(find.text('Moderado · 170 W · 70–85 rpm · subida de 6%'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar treino'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Subidões');
    await tester.pump();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar as mudanças?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Editar treino'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Trechos'), findsOneWidget);
    expect((await customs.all()).single.name, 'Subidas do bairro');

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar este treino?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();
    expect(await customs.all(), isEmpty);
    expect(find.text('Meus treinos'), findsOneWidget);
    expect(find.text('Subidas do bairro'), findsNothing);
  });

  testWidgets('treino montado: começa o pedal com o nome dele', (tester) async {
    final customs = MemoryCustomWorkoutsStore();
    await customs.upsert(CustomWorkout(
      id: 'meu-a',
      name: 'Subidas do bairro',
      blocks: [WorkoutBlock.novo(BlockKind.subida)],
      createdAt: DateTime(2026, 10, 9),
      updatedAt: DateTime(2026, 10, 9),
    ));
    final container = await _abrir(tester, settings: MemorySettingsStore(const AppSettings(ftp: 200)), customs: customs);
    final bike = FakeBikeSource();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/treino/meu-a');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Começar treino'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Subidas do bairro'), findsOneWidget);
    expect(find.text('170 W · 70–85 rpm'), findsOneWidget);
  });
}
