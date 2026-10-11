// Fotos das telas do app sem celular, com a fonte de verdade (Plus Jakarta Sans).
//
//   flutter test tool/fotos_test.dart --update-goldens
//
// Salva em tool/fotos/*.png (fora do git). Precisa das fontes em C:\dev\tmp\fontes
// (PlusJakartaSans-400.ttf … -800.ttf) ou na pasta da variável FONTES_PEDALAQUI.
// O mapa sai sem as ruas (sem internet nos testes): só a rota, os marcadores e o fundo.
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_live.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_scanner.dart';
import 'package:pedal_local/core/router/app_router.dart';
import 'package:pedal_local/core/theme/app_theme.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/custom_workouts_store.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';

import '../test/support/fakes.dart';

const _metrosPorGrau = 6371000 * math.pi / 180;

/// Rota de 3,2 km em S, com uma subida depois da metade (para o relevo ter forma).
List<ProfilePoint> rotaEntrePontes() => [
  for (var i = 0; i <= 160; i++)
    ProfilePoint(
      -23.55 + i * 20 * 0.8 / _metrosPorGrau,
      -46.63 + math.sin(i / 160 * math.pi * 1.6) * 0.004,
      760 + 24 * math.exp(-math.pow((i - 100) / 18, 2)) - 6 * math.exp(-math.pow((i - 40) / 20, 2)),
    ),
];

/// Scanner que sempre acha as bikes dadas, sem Bluetooth.
class _ScannerFixo extends BikeScanner {
  _ScannerFixo(this.bikes);

  final List<FoundDevice> bikes;

  @override
  Future<BleProblem?> check() async => null;

  @override
  Stream<List<FoundDevice>> scan({Duration duration = const Duration(seconds: 12)}) => Stream.value(bikes);
}

/// Pedal com valores fixos (sem relógio nem bike).
class _PedalFixo extends RideController {
  _PedalFixo(super.target, this.fixo);

  final RideView fixo;

  @override
  RideView build() => fixo;

  @override
  Future<void> start() async {}
}

/// “Ao vivo” fixo, com uma leitura.
class _AoVivoFixo extends BikeLiveController {
  _AoVivoFixo(this.fixo);

  final BikeLiveState fixo;

  @override
  BikeLiveState build() => fixo;
}

Future<void> _carregarFontes() async {
  final pasta = Platform.environment['FONTES_PEDALAQUI'] ?? r'C:\dev\tmp\fontes';
  Future<ByteData> ler(String caminho) async => ByteData.sublistView(await File(caminho).readAsBytes());
  final jakarta = FontLoader('Plus Jakarta Sans');
  for (final peso in [400, 500, 600, 700, 800]) {
    jakarta.addFont(ler('$pasta/PlusJakartaSans-$peso.ttf'));
  }
  await jakarta.load();
  final flutter = Platform.environment['FLUTTER_ROOT'] ?? r'C:\dev\flutter';
  final icones = FontLoader('MaterialIcons')
    ..addFont(ler('$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf'));
  await icones.load();
}

ThemeData _tema() => buildAppTheme(textTheme: ThemeData().textTheme.apply(fontFamily: 'Plus Jakarta Sans'));

/// Abre o app no celular de 360 × 800, vai para [rota] e salva a foto [nome].
Future<void> fotografar(
  WidgetTester tester,
  String nome,
  String rota, {
  List<dynamic> overrides = const [],
  MemoryRidesStore? pedais,
  MemoryRoutesStore? rotas,
  AppSettings ajustes = const AppSettings(nome: 'Estéfano'),
  Future<void> Function(WidgetTester tester, ProviderContainer container)? depois,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
  tester.view.viewPadding = const FakeViewPadding(top: 72, bottom: 48);
  addTearDown(tester.view.reset);
  final configuracoes = MemorySettingsStore();
  await configuracoes.save(ajustes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(configuracoes),
        ridesStoreProvider.overrideWithValue(pedais ?? MemoryRidesStore()),
        routesStoreProvider.overrideWithValue(rotas ?? MemoryRoutesStore()),
        customWorkoutsStoreProvider.overrideWithValue(MemoryCustomWorkoutsStore()),
        wakeLockProvider.overrideWithValue(FakeWakeLock()),
        voiceProvider.overrideWithValue(FakeVoice()),
        mapTilesEnabledProvider.overrideWithValue(false),
        appThemeProvider.overrideWithValue(_tema()),
        brandTextStyleProvider.overrideWithValue(const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w800)),
        ...overrides.cast(),
      ],
      child: const PedalLocalApp(),
    ),
  );
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100)); // a abertura, quadro a quadro
  }
  final container = ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
  container.read(appRouterProvider).go(rota);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await depois?.call(tester, container);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('fotos/$nome.png'));
}

void main() {
  setUpAll(_carregarFontes);

  final perfil = RouteProfile(rotaEntrePontes());
  final bike = FakeBikeSource(name: 'WINNEK BT-151');
  final aoVivo = BikeLiveState(
    status: BikeLive.aoVivo,
    last: BikeReading(cadence: 66, power: 173, speedKmh: 24.5, timestamp: DateTime(2026, 10, 11)),
  );
  List<dynamic> comBike() => [
    ftmsFactoryProvider.overrideWithValue((id, nome) => bike),
    bikeLiveProvider.overrideWith(() => _AoVivoFixo(aoVivo)),
  ];

  testWidgets('pedal na rota', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 11, 20, 41)), () async {
      final v = RideView(
        started: true,
        state: RideState.pedalando,
        speedKmh: 24.5,
        power: 173,
        cadence: 66,
        distance: 1840,
        total: perfil.distance,
        grade: 0.04,
        movingTime: 312,
        kcal: 41,
        avgSpeedKmh: 21.2,
        avgPower: 158,
        climbed: 18,
        routeName: 'Entre pontes',
        position: perfil.positionAt(1840),
        profile: perfil,
        alert: const RideAlert(AlertKind.subida, 0.06),
        alertAt: DateTime(2026, 10, 11, 20, 41),
        voiceOn: true,
      );
      await fotografar(
        tester,
        'pedal_rota',
        '/pedal-rota/r1',
        overrides: [...comBike(), rideProvider(const RideTarget(routeId: 'r1')).overrideWith(() => _PedalFixo(const RideTarget(routeId: 'r1'), v))],
        depois: (tester, container) async {
          await container.read(bikeControllerProvider.notifier).useSource(bike);
          await tester.pump(const Duration(milliseconds: 100));
        },
      );
    });
  });

  testWidgets('pedal na rota: mais dados', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 11, 20, 41)), () async {
      final v = RideView(
        started: true,
        state: RideState.pedalando,
        speedKmh: 24.5,
        power: 173,
        cadence: 66,
        distance: 1840,
        total: perfil.distance,
        grade: 0.04,
        movingTime: 312,
        kcal: 41,
        avgSpeedKmh: 21.2,
        avgPower: 158,
        climbed: 18,
        heartRate: 128,
        routeName: 'Entre pontes',
        position: perfil.positionAt(1840),
        profile: perfil,
        voiceOn: true,
      );
      await fotografar(
        tester,
        'pedal_rota_mais_dados',
        '/pedal-rota/r1',
        overrides: [...comBike(), rideProvider(const RideTarget(routeId: 'r1')).overrideWith(() => _PedalFixo(const RideTarget(routeId: 'r1'), v))],
        depois: (tester, container) async {
          await tester.tap(find.text('Mais dados'));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
      );
    });
  });

  testWidgets('conectar: dados chegando', (tester) async {
    await fotografar(
      tester,
      'conectar',
      '/bike',
      ajustes: const AppSettings(nome: 'Estéfano', ultimaBikeId: 'AA', ultimaBikeNome: 'WINNEK BT-151'),
      overrides: [
        ...comBike(),
        bikeScannerProvider.overrideWithValue(
          _ScannerFixo(const [
            FoundDevice(id: 'AA', name: 'WINNEK BT-151', likelyBike: true),
            FoundDevice(id: 'BB', name: 'FS-A3021', likelyBike: true),
          ]),
        ),
      ],
    );
  });

  testWidgets('início com a engrenagem', (tester) async {
    await fotografar(
      tester,
      'inicio',
      '/inicio',
      ajustes: const AppSettings(nome: 'Estéfano', ultimaBikeId: 'AA', ultimaBikeNome: 'WINNEK BT-151'),
      overrides: comBike(),
    );
  });

  testWidgets('calibrar o botão', (tester) async {
    await fotografar(
      tester,
      'calibrar_botao',
      '/bike/botao',
      depois: (tester, container) async {
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('contar-volta')));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('pedal na rota com o botão calibrado', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 11, 20, 41)), () async {
      final v = RideView(
        started: true,
        state: RideState.pedalando,
        speedKmh: 18.2,
        power: 196,
        cadence: 71,
        distance: 1840,
        total: perfil.distance,
        grade: 0.05,
        movingTime: 312,
        estimating: true,
        routeName: 'Entre pontes',
        position: perfil.positionAt(1840),
        profile: perfil,
        alert: const RideAlert(AlertKind.subida, 0.06),
        alertAt: DateTime(2026, 10, 11, 20, 41),
        alertHint: 'Gire o botão mais 5 voltas.',
        level: 5,
        knobTurns: 8,
        voiceOn: true,
      );
      await fotografar(
        tester,
        'pedal_rota_botao',
        '/pedal-rota/r1',
        overrides: [...comBike(), rideProvider(const RideTarget(routeId: 'r1')).overrideWith(() => _PedalFixo(const RideTarget(routeId: 'r1'), v))],
      );
    });
  });
}

