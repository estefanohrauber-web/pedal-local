import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_log.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/custom_workouts_store.dart';
import 'package:pedal_local/data/ha_envio.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';

import '../support/fakes.dart';

const endereco = 'http://192.168.3.70/api/webhook/pedalaqui-teste';

/// A lista da tela (e não a rolagem de dentro do campo de texto).
Finder get lista => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// O app com os pedidos ao Home Assistant presos em [pedidos].
Future<ProviderContainer> abrir(WidgetTester tester, List<http.Request> pedidos, {AppSettings? settings}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final rides = MemoryRidesStore();
  await rides.upsert(RideRecord(
    id: 'a',
    mode: RideMode.livre,
    startedAt: DateTime(2026, 11, 3, 19),
    movingTimeS: 1392,
    distanceM: 8400,
    avgPowerW: 161,
    avgSpeedKmh: 21.7,
    gainM: 0,
    kcal: 224,
    completed: true,
  ));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore(settings ?? const AppSettings())),
      ridesStoreProvider.overrideWithValue(rides),
      routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
      customWorkoutsStoreProvider.overrideWithValue(MemoryCustomWorkoutsStore()),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      voiceProvider.overrideWithValue(FakeVoice()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
      bikeLogProvider.overrideWithValue(BikeLog()),
      haEnvioEstadoStoreProvider.overrideWithValue(MemoryHaEnvioEstadoStore()),
      httpClientProvider.overrideWithValue(MockClient((req) async {
        pedidos.add(req);
        return http.Response('', 200);
      })),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

void main() {
  testWidgets('Ajustes › Avançado: o endereço do Home Assistant e o “Mandar agora”', (tester) async {
    final pedidos = <http.Request>[];
    final container = await abrir(tester, pedidos);
    expect(pedidos, isEmpty, reason: 'sem endereço, não manda nada ao abrir');
    await tester.tap(find.text('Você').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Potência, estimativa, dados da bike e Home Assistant'), findsOneWidget);
    await tester.tap(find.text('Avançado'));
    await tester.pumpAndSettle();

    final campo = find.byKey(const Key('endereco-ha'));
    await tester.scrollUntilVisible(campo, 300, scrollable: lista);
    expect(find.text('Enviar para o Home Assistant'), findsOneWidget);
    expect(find.text('Mandar agora'), findsNothing);
    await tester.enterText(campo, ' $endereco ');
    await tester.pumpAndSettle();
    expect((await container.read(settingsStoreProvider).load()).haEndereco, endereco);
    await tester.scrollUntilVisible(find.text('Mandar agora'), 300, scrollable: lista);
    expect(find.text('Ainda não mandou.'), findsOneWidget);

    await tester.tap(find.text('Mandar agora'));
    await tester.pumpAndSettle();
    expect(pedidos, hasLength(1));
    expect(pedidos.single.url.toString(), endereco);
    expect((jsonDecode(pedidos.single.body) as Map)['resumo'], {
      'pedais': 1,
      'distancia_m': 8400,
      'tempo_s': 1392,
      'subida_m': 0,
    });
    expect(find.text('Pedais mandados para o Home Assistant.'), findsOneWidget);
    expect(find.textContaining('Último envio: '), findsOneWidget);

    // o pedido do campo (esperando 2 s para juntar as teclas) vê que já foi e não repete
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(pedidos, hasLength(1));
  });

  testWidgets('ao abrir o app com endereço e sem envio ainda, manda uma vez', (tester) async {
    final pedidos = <http.Request>[];
    await abrir(tester, pedidos, settings: const AppSettings(nome: 'Ana', haEndereco: endereco));
    expect(pedidos, hasLength(1));
    expect((jsonDecode(pedidos.single.body) as Map)['nome'], 'Ana');
  });
}
