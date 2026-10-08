import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/core/links.dart';
import 'package:pedal_local/core/theme/app_theme.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/geocoding_service.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/services/request_pacer.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/fake_valhalla.dart';
import '../support/fakes.dart';
import '../support/geo_helpers.dart';

RouteRecord rotaDeTeste(String id, String nome, int pontos) {
  final perfil = northProfile(List.filled(pontos, 760));
  return RouteRecord(
    id: id,
    name: nome,
    createdAt: DateTime(2026, 10, 8),
    waypoints: [perfil.first.geo, perfil.last.geo],
    points: perfil,
    distanceM: (pontos - 1) * 20.0,
    gainM: 0,
    lossM: 0,
  );
}

final _semEspera = RequestPacer(gap: Duration.zero);

Future<ProviderContainer> abrirApp(
  WidgetTester tester, {
  required MemoryRoutesStore routes,
  MemoryRidesStore? rides,
  http.Client? servicos,
  List<Uri>? links,
  GeocodingService? busca,
}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Valhalla falso: uma reta de 100 m; a altitude sobe 1 m a cada ponto.
  final client = servicos ?? fakeValhalla(linha: northLine(2, 100), altura: (i) => 700.0 + i);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides ?? MemoryRidesStore()),
      routesStoreProvider.overrideWithValue(routes),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(GeoPoint(-23.5, -46.6))),
      openLinkProvider.overrideWithValue((uri) async => links?.add(uri)),
      geocodingServiceProvider.overrideWithValue(
        busca ?? GeocodingService(MockClient((req) async => http.Response('{"features": []}', 200))),
      ),
      routeBuilderProvider.overrideWithValue(
        RouteBuilder(routing: RoutingService(client, _semEspera), elevation: ElevationService(client, _semEspera)),
      ),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

void main() {
  testWidgets('Explorar mostra as rotas salvas, mesmo num celular pequeno', (tester) async {
    tester.view.physicalSize = const Size(1080, 2070);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final routes = MemoryRoutesStore();
    await routes.upsert(rotaDeTeste('r1', 'Volta do bairro pela praça e pela padaria', 6));
    await abrirApp(tester, routes: routes);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    expect(find.text('Minhas rotas'), findsOneWidget);
    expect(find.text('Volta do bairro pela praça e pela padaria'), findsOneWidget);
    expect(find.text('Pedalar esta rota'), findsOneWidget);
  });

  Future<Rect> abrirCriarRota(WidgetTester tester) async {
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar rota'));
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(const Key('mapa-criar-rota')));
  }

  /// Toca no mapa (o mapa espera o tempo do toque duplo) e espera o traçado automático.
  Future<void> tocarNoMapa(WidgetTester tester, List<Offset> pontos) async {
    for (final p in pontos) {
      await tester.tapAt(p);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('criar rota: tocar pontos, traça sozinho e salva com a próxima cor livre', (tester) async {
    final routes = MemoryRoutesStore();
    await routes.upsert(rotaDeTeste('antiga', 'Antiga', 6)); // cor 0
    await abrirApp(tester, routes: routes);
    final mapa = await abrirCriarRota(tester);
    expect(find.textContaining('Toque no mapa para marcar o início'), findsOneWidget);

    await tocarNoMapa(tester, [mapa.center.translate(-60, 0), mapa.center.translate(60, -60)]);
    expect(find.text('Salvar rota'), findsOneWidget);
    expect(find.textContaining('0,10 km'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nome da rota'), 'Rua de casa');
    await tester.tap(find.text('Salvar rota'));
    await tester.pumpAndSettle();
    final nova = (await routes.all()).firstWhere((r) => r.id != 'antiga');
    expect(nova.name, 'Rua de casa');
    expect(nova.colorIndex, 1);
    expect(nova.waypoints.length, 2);
    expect(find.text('Rua de casa'), findsOneWidget);
  });

  testWidgets('criar rota: ida e volta, arrastar um ponto e segurar para apagar', (tester) async {
    final routes = MemoryRoutesStore();
    await abrirApp(tester, routes: routes);
    final mapa = await abrirCriarRota(tester);
    await tocarNoMapa(tester, [
      mapa.center.translate(-60, 0),
      mapa.center.translate(60, -60),
      mapa.center.translate(60, 40),
    ]);
    expect(find.byKey(const Key('ponto-2')), findsOneWidget);

    // arrastar o ponto do meio
    final antes = tester.getCenter(find.byKey(const Key('ponto-1')));
    await tester.drag(find.byKey(const Key('ponto-1')), const Offset(-40, 30));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final depois = tester.getCenter(find.byKey(const Key('ponto-1')));
    expect((depois - antes).dx, lessThan(-20));
    expect((depois - antes).dy, greaterThan(15));

    // segurar apaga, e o aviso deixa desfazer
    await tester.longPress(find.byKey(const Key('ponto-1')));
    await tester.pumpAndSettle();
    expect(find.text('Ponto apagado'), findsOneWidget);
    expect(find.byKey(const Key('ponto-2')), findsNothing);
    await tester.tap(find.text('Desfazer').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ponto-2')), findsOneWidget);

    // ida e volta: volta pelos mesmos pontos até o começo
    await tester.ensureVisible(find.text('Ida e volta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ida e volta'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rota'));
    await tester.pumpAndSettle();
    expect((await routes.all()).single.waypoints.length, 5);
  });

  testWidgets('criar rota: busca um endereço e adiciona o ponto ali', (tester) async {
    final busca = GeocodingService(MockClient((req) async => http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'coordinates': [-46.6, -23.5],
                },
                'properties': {'name': 'Praça da Sé', 'city': 'São Paulo'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));
    await abrirApp(tester, routes: MemoryRoutesStore(), busca: busca);
    await abrirCriarRota(tester);
    await tester.enterText(find.byKey(const Key('busca-endereco')), 'praça');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Praça da Sé'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ponto-0')), findsNothing);
    await tester.tap(find.text('Adicionar ponto aqui'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ponto-0')), findsOneWidget);
    expect(find.text('Adicionar ponto aqui'), findsNothing);
  });

  testWidgets('Explorar: cada rota com sua cor; tocar no cartão destaca a rota no mapa', (tester) async {
    final routes = MemoryRoutesStore();
    await routes.upsert(rotaDeTeste('r1', 'Volta do bairro', 6)); // cor 0
    await routes.upsert(rotaDeTeste('r2', 'Ladeira', 8).copyWith(colorIndex: 1)); // passa por cima da r1
    await abrirApp(tester, routes: routes);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();

    List<Polyline<String>> linhas() =>
        tester.widget<PolylineLayer<String>>(find.byWidgetPredicate((w) => w is PolylineLayer<String>)).polylines;
    Polyline<String> linha(String id) => linhas().firstWhere((p) => p.hitValue == id);

    expect(linha('r1').color, AppColors.rotas[0]);
    expect(linha('r2').color, AppColors.rotas[1]);
    expect(linha('r1').borderStrokeWidth, greaterThan(0));
    expect(find.byTooltip('Mostrar todas'), findsNothing);

    await tester.ensureVisible(find.text('Ladeira'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ladeira'));
    await tester.pumpAndSettle();
    expect(linhas().last.hitValue, 'r2'); // destacada fica por cima
    expect(linha('r2').strokeWidth, greaterThan(linha('r1').strokeWidth));
    expect(linha('r1').color.a, lessThan(1));
    expect(find.byTooltip('Mostrar todas'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar todas'));
    await tester.pumpAndSettle();
    expect(linha('r1').color, AppColors.rotas[0]);
    expect(find.byTooltip('Mostrar todas'), findsNothing);
  });

  testWidgets('altitude fora do ar: avisa e deixa tentar de novo', (tester) async {
    var altitudeNoAr = false;
    final servicos = fakeValhalla(
      linha: northLine(2, 100),
      altura: (i) => 700.0 + i,
      heightStatus: () => altitudeNoAr ? 200 : 503,
    );
    await abrirApp(tester, routes: MemoryRoutesStore(), servicos: servicos);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar rota'));
    await tester.pumpAndSettle();
    final mapa = tester.getRect(find.byKey(const Key('mapa-criar-rota')));
    await tocarNoMapa(tester, [mapa.center.translate(-60, 0), mapa.center.translate(60, -60)]);
    expect(find.textContaining('subidas e descidas'), findsOneWidget);

    altitudeNoAr = true;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('subidas e descidas'), findsNothing);
    expect(find.text('Salvar rota'), findsOneWidget);
  });

  testWidgets('crédito do mapa leva a "Corrigir o mapa" do OpenStreetMap', (tester) async {
    final links = <Uri>[];
    await abrirApp(tester, routes: MemoryRoutesStore(), links: links);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar rota'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Créditos do mapa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Valhalla'), findsOneWidget);
    await tester.tap(find.text('Corrigir o mapa'));
    await tester.pumpAndSettle();
    expect(links, [Uri.parse('https://www.openstreetmap.org/fixthemap')]);
  });

  testWidgets('pedalar uma rota até o fim leva ao resumo', (tester) async {
    final routes = MemoryRoutesStore();
    final rides = MemoryRidesStore();
    await routes.upsert(rotaDeTeste('r1', 'Rua curta', 7)); // 120 m
    final container = await abrirApp(tester, routes: routes, rides: rides);
    final bike = FakeBikeSource(name: 'FS-TESTE');
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedalar esta rota'));
    await tester.pumpAndSettle();
    // Preparar: é uma ida; dá para inverter e voltar ao sentido original antes de começar.
    expect(find.text('Ida (de um ponto a outro)'), findsOneWidget);
    await tester.tap(find.text('Inverter sentido'));
    await tester.pump();
    expect(find.textContaining('Sentido invertido'), findsOneWidget);
    await tester.tap(find.textContaining('Sentido invertido'));
    await tester.pump();
    await tester.tap(find.text('Começar pedal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rua curta'), findsOneWidget);

    for (var i = 0; i < 120 && find.text('Rota concluída!').evaluate().isEmpty; i++) {
      bike.emitReading(BikeReading(cadence: 85, power: 250, timestamp: clock.now()));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.text('Rota concluída!'), findsOneWidget);
    final pedal = (await rides.recent()).single;
    expect(pedal.mode, RideMode.rota);
    expect(pedal.routeId, 'r1');
    expect(pedal.completed, isTrue);
    expect(pedal.laps, 1);
    expect(find.byKey(const Key('mapa-pedal')), findsOneWidget);
    expect(find.text('Velocidade'), findsOneWidget);

    // O cartão de comparação carrega depois e empurra o fim da tela: rola, espera e rola de novo.
    final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    for (var i = 0; i < 2; i++) {
      await tester.scrollUntilVisible(find.text('Apagar este pedal'), 300, scrollable: lista);
      await tester.pumpAndSettle();
    }
    expect(find.text('Primeira vez nesta rota neste sentido.'), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Último pedal'), findsOneWidget);
    // Cartão da rota no topo + pedal no histórico, ambos com o nome da rota.
    expect(find.text('Rua curta'), findsNWidgets(2));
  });
}
