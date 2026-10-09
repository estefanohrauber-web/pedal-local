import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:pedal_local/domain/ride_narrator.dart';
import 'package:pedal_local/domain/power.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/workout.dart';
import 'package:pedal_local/features/pedal/ghost_options.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';

import '../support/fakes.dart';
import '../support/geo_helpers.dart';

RouteRecord rotaDeTeste(String id, List<double> alts) {
  final pontos = northProfile(alts);
  return RouteRecord(
    id: id,
    name: 'Rua de teste',
    createdAt: DateTime(2026, 10, 8),
    waypoints: [pontos.first.geo, pontos.last.geo],
    points: pontos,
    distanceM: (alts.length - 1) * 20.0,
    gainM: 0,
    lossM: 0,
  );
}

RouteRecord rotaComPontos(String id, List<ProfilePoint> pontos) => RouteRecord(
      id: id,
      name: 'Volta de teste',
      createdAt: DateTime(2026, 10, 8),
      waypoints: [pontos.first.geo, pontos.last.geo],
      points: pontos,
      distanceM: RouteProfile(pontos).distance,
      gainM: 0,
      lossM: 0,
    );

/// Treinos curtos para os testes andarem rápido.
const treinoCurto = Workout(id: 'curto', name: 'Curto', summary: '', category: 'Intervalos', steps: [
  WorkoutStep(10, 0.5),
  WorkoutStep(10, 1.0, grade: 0.05, cue: 'Forte!'),
]);
const rampaCurta = Workout(id: 'rampa', name: 'Rampa', summary: '', category: 'Teste', rampTest: true, steps: [
  WorkoutStep(10, 0.4),
  WorkoutStep(60, 0.5),
  WorkoutStep(60, 0.56),
  WorkoutStep(60, 0.62),
  WorkoutStep(30, 0.4),
]);

Workout? treinoDeTeste(String id) => {'curto': treinoCurto, 'rampa': rampaCurta}[id] ?? workoutById(id);

/// Pedal anterior concluído na rota, a [vel] m/s constante.
RideRecord pedalAnterior(String id, String rota, {required int segundos, required double vel}) => RideRecord(
      id: id,
      routeId: rota,
      mode: RideMode.rota,
      startedAt: DateTime(2026, 10, 1, 18),
      movingTimeS: segundos.toDouble(),
      distanceM: segundos * vel,
      avgPowerW: 150,
      avgSpeedKmh: vel * 3.6,
      gainM: 0,
      kcal: 1,
      completed: true,
      laps: 1,
      samples: [
        for (var t = 1; t <= segundos; t++)
          RideSample(t: t.toDouble(), distance: t * vel, speedKmh: vel * 3.6, power: 150, cadence: 80),
      ],
    );

void main() {
  late FakeBikeSource bike;
  late FakeWakeLock wake;
  late FakeVoice voz;
  late MemoryRidesStore rides;
  late MemoryRoutesStore routes;
  late ProviderContainer container;
  late DateTime agora;

  setUp(() async {
    bike = FakeBikeSource();
    wake = FakeWakeLock();
    voz = FakeVoice();
    rides = MemoryRidesStore();
    routes = MemoryRoutesStore();
    agora = DateTime(2026, 10, 8, 20);
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      routesStoreProvider.overrideWithValue(routes),
      wakeLockProvider.overrideWithValue(wake),
      voiceProvider.overrideWithValue(voz),
      workoutLookupProvider.overrideWithValue(treinoDeTeste),
      clockProvider.overrideWithValue(() => agora),
      rideIdProvider.overrideWithValue(() => 'p1'),
      rideTickProvider.overrideWithValue(const Duration(hours: 1)),
      reconnectDelaysProvider.overrideWithValue(const [Duration(hours: 1)]),
    ]);
    addTearDown(container.dispose);
    await container.read(bikeControllerProvider.notifier).useSource(bike);
  });

  /// Aceita o id da rota (ou null = pedal livre) ou um RideTarget completo.
  RideTarget alvo(Object? rota) => rota is RideTarget ? rota : RideTarget(routeId: rota as String?);

  RideController ctrl(Object? rota) {
    container.listen(rideProvider(alvo(rota)), (anterior, proximo) {});
    return container.read(rideProvider(alvo(rota)).notifier);
  }

  RideView view(Object? rota) => container.read(rideProvider(alvo(rota)));

  Future<void> pedalar(Object? rota, int segundos, {int? power = 150, double cadence = 80}) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      bike.emitReading(BikeReading(cadence: cadence, power: power, timestamp: agora));
      await settle();
      ctrl(rota).tick();
    }
  }

  group('pedal livre', () {
    test('start liga a tela, salva o pedal e começa pedalando', () async {
      await ctrl(null).start();
      expect(wake.enabled, isTrue);
      expect(view(null).started, isTrue);
      expect(view(null).state, RideState.pedalando);
      expect(view(null).isRoute, isFalse);
      final salvo = await rides.byId('p1');
      expect(salvo!.completed, isFalse);
      expect(salvo.mode, RideMode.livre);
    });

    test('pedalando com 150 W ganha velocidade e grava o histórico de potência', () async {
      await ctrl(null).start();
      await pedalar(null, 10);
      expect(view(null).speedKmh, greaterThan(15));
      expect(view(null).distance, greaterThan(0));
      expect(view(null).power, 150);
      expect(view(null).powerHistory.length, 10);
    });

    test('sem leitura por mais de 3 s, a potência zera', () async {
      await ctrl(null).start();
      await pedalar(null, 5);
      for (var i = 0; i < 16; i++) {
        agora = agora.add(const Duration(milliseconds: 250));
        ctrl(null).tick();
      }
      expect(view(null).power, 0);
    });

    test('carga muda entre 1 e 10; pausar e continuar', () async {
      await ctrl(null).start();
      for (var i = 0; i < 20; i++) {
        ctrl(null).changeLevel(1);
      }
      expect(view(null).level, 10);
      ctrl(null).togglePause();
      expect(view(null).state, RideState.pausado);
      ctrl(null).togglePause();
      expect(view(null).state, RideState.pedalando);
    });

    test('queda da bike pausa; reconexão retoma', () async {
      await ctrl(null).start();
      await pedalar(null, 3);
      bike.emitConnection(BikeConnection.caiu);
      await settle();
      expect(view(null).pausedByBike, isTrue);
      expect(view(null).state, RideState.pausado);
      bike.emitConnection(BikeConnection.conectada);
      await settle();
      expect(view(null).state, RideState.pedalando);
    });

    test('finish salva concluído, desliga a tela e é idempotente', () async {
      await ctrl(null).start();
      await pedalar(null, 12);
      expect(await ctrl(null).finish(), 'p1');
      expect(await ctrl(null).finish(), 'p1');
      final salvo = await rides.byId('p1');
      expect(salvo!.completed, isTrue);
      expect(salvo.samples.length, greaterThanOrEqualTo(12));
      expect(wake.enabled, isFalse);
    });
  });

  group('pedal na rota', () {
    test('anda pela rota, mostra a posição e conclui no fim', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760))); // 100 m planos
      await ctrl('r').start();
      expect(view('r').isRoute, isTrue);
      expect(view('r').routeName, 'Rua de teste');
      expectNear(view('r').total, 100, 0.5);
      final inicio = view('r').position!;
      for (var s = 0; s < 120 && view('r').state != RideState.concluido; s++) {
        await pedalar('r', 1);
      }
      expect(view('r').state, RideState.concluido);
      expect(view('r').position!.lat, greaterThan(inicio.lat));
      await ctrl('r').finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.mode, RideMode.rota);
      expect(salvo.routeId, 'r');
      expect(salvo.completed, isTrue);
    });

    test('avisa a subida que vem pela frente', () async {
      await routes.upsert(rotaDeTeste('s', [for (var i = 0; i < 16; i++) 760 + i * 1.2])); // 6 %
      await ctrl('s').start();
      await pedalar('s', 2);
      expect(view('s').alert?.kind, AlertKind.subida);
      expect(view('s').alertAt, isNotNull);
      expect(view('s').grade, closeTo(0.06, 0.001));
    });

    test('rota que não existe', () async {
      await ctrl('nada').start();
      expect(view('nada').notFound, isTrue);
      expect(view('nada').started, isFalse);
      expect(wake.enabled, isFalse);
    });

    test('posição começa no primeiro ponto', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760)));
      await ctrl('r').start();
      final p = view('r').position!;
      expect(p, isA<GeoPoint>());
      expectNear(p.lat, -23.5, 1e-9);
    });
  });

  group('sentido e começo', () {
    test('sentido invertido começa no fim e anda para o outro lado', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760)));
      const inverso = RideTarget(routeId: 'r', reversed: true);
      await ctrl(inverso).start();
      final inicio = view(inverso).position!;
      expectNear(inicio.lat, northLine(6, 20).last.lat, 1e-9);
      await pedalar(inverso, 5);
      expect(view(inverso).position!.lat, lessThan(inicio.lat));
      await ctrl(inverso).finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.reversed, isTrue);
      expect(salvo.track!.first.lat, closeTo(inicio.lat, 1e-9));
    });

    test('ida até o fim conta 1 volta; encerrar no meio conta 0', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760)));
      await ctrl('r').start();
      await pedalar('r', 3);
      await ctrl('r').finish();
      expect((await rides.byId('p1'))!.laps, 0);
    });

    test('começo escolhido na volta fechada', () async {
      final volta = squareLoop(100);
      await routes.upsert(rotaComPontos('v', volta));
      const daqui = RideTarget(routeId: 'v', startIndex: 7);
      await ctrl(daqui).start();
      expect(view(daqui).position, volta[7].geo);
      expect(view(daqui).isLoop, isTrue);
    });
  });

  group('voltas', () {
    Future<double> pedalarAteVolta(Object rota, int voltas) async {
      for (var s = 0; s < 600 && view(rota).lapsDone < voltas; s++) {
        await pedalar(rota, 1);
      }
      return view(rota).distance;
    }

    test('a volta fechada não termina: segue para a próxima e avisa cada volta', () async {
      await routes.upsert(rotaComPontos('v', squareLoop(100)));
      await ctrl('v').start();
      expect(view('v').lap, 1);
      await pedalarAteVolta('v', 1);
      expect(view('v').state, RideState.pedalando);
      expect(view('v').lap, 2);
      expect(view('v').lapAlert?.number, 1);
      expect(view('v').lapAlert!.time, greaterThan(0));
      expect(view('v').lapDistance, lessThan(view('v').lapLength!));
    });

    test('encerrar logo depois de fechar a volta descarta o que passou (dentro da margem)', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(margemVolta: 0.1));
      await routes.upsert(rotaComPontos('v', squareLoop(100)));
      await ctrl('v').start();
      await pedalarAteVolta('v', 1);
      await pedalar('v', 1);
      final volta = view('v').lapLength!;
      expect(view('v').distance, greaterThan(volta));
      await ctrl('v').finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.laps, 1);
      expect(salvo.loop, isTrue);
      expectNear(salvo.distanceM, volta, 0.01);
      expect(salvo.trimmedM, greaterThan(0));
      expectNear(salvo.samples.last.distance, volta, 0.01);
    });

    test('passou da margem: guarda tudo', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(margemVolta: 0.01));
      await routes.upsert(rotaComPontos('v', squareLoop(100)));
      await ctrl('v').start();
      await pedalarAteVolta('v', 1);
      await pedalar('v', 5);
      final andado = view('v').distance;
      await ctrl('v').finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.laps, 1);
      expect(salvo.trimmedM, 0);
      expectNear(salvo.distanceM, andado, 0.01);
    });
  });

  group('fantasma', () {
    test('corre contra o recorde: vantagem em segundos e metros e o fantasma no mapa', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(51, 760))); // 1 km plano
      await rides.upsert(pedalAnterior('antigo', 'r', segundos: 200, vel: 5));
      const alvo = RideTarget(routeId: 'r', ghost: GhostKind.recorde);
      await ctrl(alvo).start();
      expect(view(alvo).hasGhost, isTrue);
      expect(view(alvo).ghostGapS, 0);
      await pedalar(alvo, 30, power: 300);
      final v = view(alvo);
      expectNear(v.ghostGapS!, v.distance / 5 - v.movingTime, 0.01);
      expectNear(v.ghostGapM!, v.movingTime * 5 - v.distance, 0.01);
      expect(v.ghostPosition, isNotNull);
      expect(v.ghostPosition, isNot(v.position));
    });

    test('sem pedal anterior no sentido escolhido, não tem fantasma', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(51, 760)));
      await rides.upsert(pedalAnterior('antigo', 'r', segundos: 200, vel: 5));
      const alvo = RideTarget(routeId: 'r', reversed: true, ghost: GhostKind.recorde);
      await ctrl(alvo).start();
      await pedalar(alvo, 2);
      expect(view(alvo).hasGhost, isFalse);
      expect(view(alvo).ghostPosition, isNull);
    });
  });

  group('voz', () {
    test('fala cada quilômetro e, no fim, o resumo do pedal', () async {
      await ctrl(null).start();
      expect(view(null).voiceOn, isTrue);
      for (var i = 0; i < 300 && view(null).distance < 1010; i++) {
        await pedalar(null, 1);
      }
      expect(voz.spoken.where((f) => f.startsWith('1 quilômetro, em ')).length, 1);
      await ctrl(null).finish();
      expect(voz.spoken.last, startsWith('Pedal encerrado: '));
    });

    test('avisa a subida, a queda da bike e a chegada da rota', () async {
      await routes.upsert(rotaDeTeste('r', [for (var i = 0; i < 31; i++) i < 15 ? 760.0 : 760.0 + (i - 15) * 2]));
      await ctrl('r').start();
      for (var i = 0; i < 120 && view('r').distance < 250; i++) {
        await pedalar('r', 1);
      }
      expect(voz.spoken, contains(startsWith('Subida de 10 por cento chegando')));
      bike.emitConnection(BikeConnection.caiu);
      await settle();
      expect(voz.spoken.last, RideNarrator.bikeDropped);
      bike.emitConnection(BikeConnection.conectada);
      await settle();
      for (var i = 0; i < 200 && view('r').state != RideState.concluido; i++) {
        await pedalar('r', 1, power: 300);
      }
      await ctrl('r').finish();
      expect(voz.spoken.last, startsWith('Rota concluída em '));
    });

    test('usa a voz escolhida nos Ajustes', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(vozId: 'g|voz-boa|pt-BR'));
      await ctrl(null).start();
      expect(voz.chosen.last, 'g|voz-boa|pt-BR');
    });

    test('desligar a voz para de falar e vale para os próximos pedais', () async {
      await ctrl(null).start();
      await ctrl(null).toggleVoice();
      expect(view(null).voiceOn, isFalse);
      expect(voz.stops, 1);
      expect((await container.read(settingsStoreProvider).load()).voz, isFalse);
      for (var i = 0; i < 300 && view(null).distance < 1010; i++) {
        await pedalar(null, 1);
      }
      expect(voz.spoken, isEmpty);
    });
  });

  group('treino', () {
    test('metas pelo FTP, voz, bike segurando a potência, subida do trecho e fim sozinho', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(ftp: 200));
      final controle = FakeBikeControl();
      bike.control = controle;
      const alvo = RideTarget.treino('curto');
      await ctrl(alvo).start();
      expect(view(alvo).isWorkout, isTrue);
      expect(view(alvo).ftp, 200);
      expect(view(alvo).bikeAdjusts, isTrue);
      await pedalar(alvo, 1);
      expect(view(alvo).frame!.index, 0);
      expect(view(alvo).frame!.targetWatts, 100);
      expect(controle.powers.first, 100);
      expect(voz.spoken, contains('10 segundos muito leve, 100 watts.'));
      await pedalar(alvo, 10);
      expect(view(alvo).frame!.index, 1);
      expect(view(alvo).frame!.targetWatts, 200);
      expect(controle.powers.last, 200);
      expect(view(alvo).grade, 0.05);
      expect(voz.spoken, contains('Forte! 10 segundos forte, 200 watts.'));
      for (var i = 0; i < 30 && view(alvo).state != RideState.concluido; i++) {
        await pedalar(alvo, 1);
      }
      expect(view(alvo).state, RideState.concluido);
      await ctrl(alvo).finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.mode, RideMode.treino);
      expect(salvo.workoutId, 'curto');
      expect(salvo.workoutDone, isTrue);
      expect(voz.spoken.last, startsWith('Treino concluído em '));
      expect(controle.releases, greaterThanOrEqualTo(1));
    });

    test('teste de rampa: “não aguento mais” calcula, fala e guarda o FTP', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(ftp: 200));
      const alvo = RideTarget.treino('rampa');
      await ctrl(alvo).start();
      await pedalar(alvo, 80, power: 150);
      ctrl(alvo).endRamp();
      expect(view(alvo).frame!.rampEnded, isTrue);
      expect(voz.spoken.last, 'Teste encerrado. Seu FTP é de 113 watts. Agora, 5 minutos leves para soltar as pernas.');
      await pedalar(alvo, 2, power: 80);
      expect(view(alvo).frame!.index, rampaCurta.steps.length - 1);
      await ctrl(alvo).finish();
      expect((await container.read(settingsStoreProvider).load()).ftp, 113);
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.ftp, 113);
      expect(salvo.workoutDone, isTrue);
    });

    test('controle desligado nos Ajustes: não manda nada; sem teste, FTP de 2 W/kg', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(controleBike: false, pesoKg: 80));
      final controle = FakeBikeControl();
      bike.control = controle;
      const alvo = RideTarget.treino('curto');
      await ctrl(alvo).start();
      await pedalar(alvo, 2);
      expect(controle.powers, isEmpty);
      expect(view(alvo).bikeAdjusts, isFalse);
      expect(view(alvo).ftp, 160);
    });

    test('com potência estimada, sugere a carga que dá a meta a 85 rpm', () async {
      await container.read(settingsStoreProvider).save(const AppSettings(ftp: 200, modoPotencia: PowerMode.estimada));
      const alvo = RideTarget.treino('curto');
      await ctrl(alvo).start();
      await pedalar(alvo, 1);
      expect(view(alvo).suggestedLevel, 2); // 100 W / 85 rpm = 1,18 → (1,18 − 0,6) / 0,25 ≈ 2
      await pedalar(alvo, 10);
      expect(view(alvo).suggestedLevel, 7); // 200 W
    });

    test('treino que não existe', () async {
      const alvo = RideTarget.treino('nada');
      await ctrl(alvo).start();
      expect(view(alvo).notFound, isTrue);
    });
  });
}
