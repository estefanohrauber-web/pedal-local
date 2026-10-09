import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_log.dart';
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
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:pedal_local/domain/stats.dart';

import '../support/fakes.dart';
import '../support/geo_helpers.dart';

final _volta = squareLoop(100, alts: (i) => 700.0 + (i <= 10 ? i : 20 - i));

RouteRecord _rotaVolta() => RouteRecord(
      id: 'v',
      name: 'Volta da praça',
      createdAt: DateTime(2026, 10, 1),
      waypoints: [_volta.first.geo, _volta.last.geo],
      points: _volta,
      distanceM: RouteProfile(_volta).distance,
      gainM: 10,
      lossM: 10,
      colorIndex: 1,
    );

/// Pedal de 2 voltas e meia na volta de 400 m, a 8 m/s, com a potência subindo.
RideRecord _pedalVoltas(String id, DateTime quando, {double segundos = 125}) {
  final amostras = [
    for (var t = 1; t <= segundos; t++)
      RideSample(t: t.toDouble(), distance: t * 8.0, speedKmh: 20.0 + t % 20, power: 100.0 + t, cadence: 80),
  ];
  return RideRecord(
    id: id,
    routeId: 'v',
    mode: RideMode.rota,
    startedAt: quando,
    movingTimeS: segundos,
    distanceM: segundos * 8,
    avgPowerW: 160,
    avgSpeedKmh: 28.8,
    gainM: 25,
    kcal: 20,
    completed: true,
    samples: amostras,
    laps: (segundos * 8 / RouteProfile(_volta).distance).floor(),
    loop: true,
    track: _volta,
  );
}

Future<ProviderContainer> _abrir(
  WidgetTester tester, {
  MemoryRoutesStore? routes,
  MemoryRidesStore? rides,
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore(settings)),
      ridesStoreProvider.overrideWithValue(rides ?? MemoryRidesStore()),
      routesStoreProvider.overrideWithValue(routes ?? MemoryRoutesStore()),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      voiceProvider.overrideWithValue(FakeVoice()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
      bikeLogProvider.overrideWithValue(BikeLog()),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

Finder get _listaVertical =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

void main() {
  testWidgets('Você: nome, semana com a meta, totais e histórico por semana', (tester) async {
    final rides = MemoryRidesStore();
    final agora = DateTime.now();
    await rides.upsert(_pedalVoltas('a', weekStart(agora).add(const Duration(seconds: 1))));
    await rides.upsert(_pedalVoltas('b', agora.subtract(const Duration(days: 14))));
    final routes = MemoryRoutesStore();
    await routes.upsert(_rotaVolta());
    await _abrir(tester, rides: rides, routes: routes, settings: const AppSettings(nome: 'Ana', metaSemanalKm: 10));
    expect(find.text('Olá, Ana!'), findsOneWidget); // Início
    await tester.tap(find.text('Você').last);
    await tester.pumpAndSettle();
    expect(find.text('Olá, Ana'), findsOneWidget);
    expect(find.text('Esta semana'), findsWidgets);
    expect(find.text('10% da meta'), findsOneWidget); // 1 km de 10 km
    expect(find.text('Desde o começo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Volta da praça').first, 300, scrollable: _listaVertical);
    expect(find.textContaining('2 voltas'), findsWidgets);
  });

  testWidgets('Ajustes: nome, margem e avançado escondido', (tester) async {
    final container = await _abrir(tester);
    await tester.tap(find.text('Você').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Margem para fechar a volta: 3%'), findsOneWidget);
    expect(find.text('Base'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Bia');
    await tester.scrollUntilVisible(find.byKey(const Key('avancado')), 300, scrollable: _listaVertical);
    await tester.tap(find.byKey(const Key('avancado')));
    await tester.pumpAndSettle();
    expect(find.text('Base'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Salvar'), 300, scrollable: _listaVertical);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect((await container.read(settingsStoreProvider).load()).nome, 'Bia');
  });

  testWidgets('Ajustes: voz com exemplo e desligar', (tester) async {
    final container = await _abrir(tester);
    await tester.tap(find.text('Você').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    Future<void> mostrar(String texto) async {
      await tester.scrollUntilVisible(find.text(texto), 100, scrollable: _listaVertical);
      await tester.ensureVisible(find.text(texto));
      await tester.pumpAndSettle();
    }

    await mostrar('Avisos falados no pedal');
    await tester.tap(find.text('Avisos falados no pedal'));
    await tester.pump();
    await mostrar('Ouvir um exemplo');
    await tester.tap(find.text('Ouvir um exemplo'));
    await tester.pump();
    final voz = container.read(voiceProvider) as FakeVoice;
    expect(voz.spoken, ['Subida de 6 por cento chegando. Aumente a carga.']);
    await tester.scrollUntilVisible(find.text('Salvar'), 300, scrollable: _listaVertical);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect((await container.read(settingsStoreProvider).load()).voz, isFalse);
  });

  testWidgets('Preparar volta fechada: sentido e começo tocando no mapa', (tester) async {
    final routes = MemoryRoutesStore();
    await routes.upsert(_rotaVolta());
    final container = await _abrir(tester, routes: routes);
    await container.read(bikeControllerProvider.notifier).useSource(FakeBikeSource());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedalar esta rota'));
    await tester.pumpAndSettle();
    expect(find.text('Volta fechada'), findsOneWidget);
    expect(find.text('Horário'), findsOneWidget);
    expect(find.text('Começo original'), findsNothing);
    final mapa = tester.getRect(find.byKey(const Key('mapa-preparar')));
    await tester.tapAt(mapa.center.translate(40, 40));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Começo original'), findsOneWidget);
    await tester.tap(find.text('Anti-horário'));
    await tester.pump();
    await tester.tap(find.text('Começar pedal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Volta 1 ·'), findsOneWidget);
  });

  testWidgets('Resumo: mapa colorido, troca de métrica, voltas e apagar', (tester) async {
    final rides = MemoryRidesStore();
    await rides.upsert(_pedalVoltas('a', DateTime(2026, 10, 8, 9)));
    final routes = MemoryRoutesStore();
    await routes.upsert(_rotaVolta());
    final container = await _abrir(tester, rides: rides, routes: routes);
    container.read(appRouterProvider).go('/resumo/a');
    await tester.pumpAndSettle();
    expect(find.text('Rota concluída!'), findsOneWidget);
    expect(find.textContaining('2 voltas +'), findsOneWidget);
    expect(find.byKey(const Key('mapa-pedal')), findsOneWidget);
    List<Polyline> linhas() => tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines;
    final cores = linhas().map((p) => p.color).toSet();
    expect(cores.length, greaterThan(3)); // branco de fundo + vários tons do degradê
    expect(find.textContaining('km/h'), findsWidgets);
    await tester.tap(find.text('Potência'));
    await tester.pumpAndSettle();
    expect(find.textContaining(' W'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('Volta 3'), 200, scrollable: _listaVertical);
    expect(find.textContaining('Volta 3'), findsOneWidget); // a parcial
    await tester.tap(find.textContaining('Volta 2'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('grafico-metrica')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('grafico-metrica')));
    await tester.pumpAndSettle();
    expect(find.textContaining('km ·'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Apagar este pedal'), 300, scrollable: _listaVertical);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Apagar este pedal'), 300, scrollable: _listaVertical);
    await tester.tap(find.text('Apagar este pedal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();
    expect(await rides.byId('a'), isNull);
  });

  testWidgets('Dados da bike: mostra o que chega e o que a bike não manda', (tester) async {
    final container = await _abrir(tester);
    final bike = FakeBikeSource();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/bike/dados');
    await tester.pumpAndSettle();
    bike.emitReading(BikeReading(cadence: 80, resistance: 5, timestamp: DateTime.now()));
    await tester.pump();
    bike.emitReading(BikeReading(cadence: 82, resistance: 8, timestamp: DateTime.now()));
    await tester.pump();
    expect(find.text('2 leituras recebidas'), findsOneWidget);
    expect(find.text('de 5 a 8'), findsOneWidget);
    expect(find.text('não manda'), findsWidgets); // potência (e o que mais não chegou)
  });

  testWidgets('Dados da bike: últimos pacotes crus e copiar o diário para mandar na conversa', (tester) async {
    final container = await _abrir(tester);
    final log = container.read(bikeLogProvider);
    final bike = FakeBikeSource();
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/bike/dados');
    await tester.pumpAndSettle();
    log.add('conectando a Winnek');
    log.packet(Uint8List.fromList([0x45, 0x00, 0xa0, 0x00]));
    bike.emitReading(BikeReading(cadence: 80, timestamp: DateTime.now()));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Copiar o diário'), 200, scrollable: _listaVertical);
    await tester.ensureVisible(find.text('Copiar o diário'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dados 45 00 a0 00'), findsOneWidget);
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copiado = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Copiar o diário'));
    await tester.pump();
    expect(copiado, contains('conectando a Winnek'));
    expect(copiado, contains('dados 45 00 a0 00'));
    expect(find.text('Diário copiado. É só colar na conversa.'), findsOneWidget);
  });
}
