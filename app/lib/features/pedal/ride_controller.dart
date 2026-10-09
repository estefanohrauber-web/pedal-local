import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_control.dart';
import '../../bike/bike_controller.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_source.dart';
import '../../core/voice.dart';
import '../../core/wake_lock.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../domain/geo.dart';
import '../../domain/ghost.dart';
import '../../domain/laps.dart';
import '../../domain/power.dart';
import '../../domain/ride_narrator.dart';
import '../../domain/ride_session.dart';
import '../../domain/route_profile.dart';
import '../../domain/route_variant.dart';
import '../../domain/training.dart';
import '../../domain/workout.dart';
import '../../domain/workout_blocks.dart';
import '../../domain/workout_runner.dart';
import 'ghost_options.dart';

/// Relógio do pedal. `clock.now()` é o relógio real no app e o relógio simulado nos testes de tela.
final clockProvider = Provider<DateTime Function()>((ref) => () => clock.now());
final rideIdProvider = Provider<String Function()>(
  (ref) => () => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
);
final rideTickProvider = Provider<Duration>((ref) => const Duration(milliseconds: 250));

/// Onde achar um treino pelo id (a biblioteca; nos testes, treinos curtos).
final workoutLookupProvider = Provider<Workout? Function(String id)>((ref) => workoutById);

/// Qualquer treino pelo id: da biblioteca ([workoutLookupProvider]) ou montado pelo usuário.
/// Enquanto os do usuário carregam, os deles dão null.
final findWorkoutProvider = Provider<Workout? Function(String id)>((ref) {
  final biblioteca = ref.watch(workoutLookupProvider);
  final meus = ref.watch(customWorkoutsProvider).value ?? const <CustomWorkout>[];
  return (id) {
    if (!isCustomWorkoutId(id)) return biblioteca(id);
    for (final m in meus) {
      if (m.id == id) return m.toWorkout();
    }
    return null;
  };
});

const _historyLength = 300; // 5 minutos de amostras
const _staleAfter = Duration(seconds: 3);
const _saveEverySeconds = 15.0;

/// O que pedalar: pedal livre (sem rota), uma rota no sentido e começo escolhidos (com ou
/// sem fantasma) ou um treino.
@immutable
class RideTarget {
  const RideTarget({this.routeId, this.reversed = false, this.startIndex = 0, this.ghost, this.workoutId});

  const RideTarget.treino(String id) : this(workoutId: id);

  static const livre = RideTarget();

  final String? routeId;
  final bool reversed;

  /// Índice dos pontos originais onde a volta começa (só vale para volta fechada).
  final int startIndex;

  /// Correr contra o recorde ou o último pedal (null = sem fantasma).
  final GhostKind? ghost;

  /// Treino da biblioteca (null = não é treino).
  final String? workoutId;

  @override
  bool operator ==(Object other) =>
      other is RideTarget &&
      other.routeId == routeId &&
      other.reversed == reversed &&
      other.startIndex == startIndex &&
      other.ghost == ghost &&
      other.workoutId == workoutId;

  @override
  int get hashCode => Object.hash(routeId, reversed, startIndex, ghost, workoutId);
}

/// Volta recém-completada, para a faixa “Volta N concluída em mm:ss”.
class LapAlert {
  const LapAlert(this.number, this.time, this.at);

  final int number;
  final double time;
  final DateTime at;
}

class RideView {
  const RideView({
    this.started = false,
    this.notFound = false,
    this.state = RideState.pronto,
    this.speedKmh = 0,
    this.power = 0,
    this.cadence = 0,
    this.heartRate,
    this.distance = 0,
    this.total = double.infinity,
    this.grade = 0,
    this.movingTime = 0,
    this.kcal = 0,
    this.level = 4,
    this.estimating = false,
    this.pausedByBike = false,
    this.powerHistory = const [],
    this.routeName,
    this.position,
    this.alert,
    this.alertAt,
    this.profile,
    this.lapLength,
    this.lapsDone = 0,
    this.lapAlert,
    this.ghostGapS,
    this.ghostGapM,
    this.ghostPosition,
    this.voiceOn = false,
    this.workout,
    this.frame,
    this.ftp = 0,
    this.bikeAdjusts = false,
    this.suggestedLevel,
  });

  final bool started;
  final bool notFound;
  final RideState state;
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
  final double distance;
  final double total;
  final double grade;
  final double movingTime;
  final double kcal;
  final int level;
  final bool estimating;
  final bool pausedByBike;
  final List<double> powerHistory;
  final String? routeName;
  final GeoPoint? position;
  final RideAlert? alert;
  final DateTime? alertAt;
  final RouteProfile? profile;

  /// Comprimento da volta (só na volta fechada).
  final double? lapLength;
  final int lapsDone;
  final LapAlert? lapAlert;

  /// Segundos à frente do fantasma (negativo = atrás). Null = sem fantasma.
  final double? ghostGapS;

  /// Metros que o fantasma está à frente (negativo = atrás).
  final double? ghostGapM;
  final GeoPoint? ghostPosition;

  /// Avisos falados ligados.
  final bool voiceOn;

  /// Treino em andamento e o instante dele (null = não é treino).
  final Workout? workout;
  final WorkoutFrame? frame;

  /// FTP usado nas metas do treino.
  final double ftp;

  /// A bike está segurando a meta sozinha (modo ERG).
  final bool bikeAdjusts;

  /// Com a potência estimada: a carga que dá a meta a 85 rpm.
  final int? suggestedLevel;

  bool get isWorkout => workout != null;

  bool get hasGhost => ghostGapS != null;
  bool get isRoute => profile != null;
  bool get isLoop => lapLength != null;

  /// Volta em andamento (começa em 1).
  int get lap => lapsDone + 1;

  /// Distância dentro da volta atual (na ida, a distância toda).
  double get lapDistance => isLoop ? distance - lapsDone * lapLength! : distance;
}

/// Pedal livre (sem rota) ou pedal numa rota salva, no sentido e começo escolhidos.
class RideController extends Notifier<RideView> {
  RideController(this.target);

  final RideTarget target;
  String? get routeId => target.routeId;
  List<ProfilePoint>? _track;
  LoopTerrain? _loop;
  Ghost? _ghost;
  Workout? _workout;
  WorkoutRunner? _runner;
  WorkoutTerrain? _terrenoTreino;
  WorkoutFrame? _frame;
  BikeControl? _controle;
  int? _alvoEnviado;
  double _ftp = 0;
  PowerCalibration _calibracao = const PowerCalibration(base: 0.6, factor: 0.25);
  bool _treinoCompleto = false;
  RideNarrator? _narrador;
  Voice? _voz;
  bool _vozLigada = false;
  double _margem = 0.03;
  int _lapsSeen = 0;
  LapAlert? _lapAlert;
  RideSession? _session;
  PowerResolver? _resolver;
  RouteProfile? _profile;
  String? _routeName;
  WakeLock? _wakeLock;
  Timer? _ticker;
  StreamSubscription<BikeReading>? _readingSub;
  StreamSubscription<BikeConnection>? _connectionSub;
  DateTime? _startedAt;
  DateTime? _lastTick;
  DateTime? _lastReading;
  String? _rideId;
  RideAlert? _alert;
  DateTime? _alertAt;
  double _sinceSave = 0;
  int _level = 4;
  int _seenSamples = 0;
  bool _pausedByBike = false;
  bool _starting = false;
  bool _finished = false;
  final List<double> _history = [];

  @override
  RideView build() {
    ref.onDispose(_stop);
    return const RideView();
  }

  Future<void> start() async {
    if (_session != null || _starting) return;
    _starting = true;
    final settings = await ref.read(settingsStoreProvider).load();
    if (!ref.mounted) return;
    final id = routeId;
    if (id != null) {
      final route = await ref.read(routesStoreProvider).byId(id);
      if (!ref.mounted) return;
      if (route == null) {
        state = const RideView(notFound: true);
        return;
      }
      final pontos = routeVariant(route.points, reversed: target.reversed, startIndex: target.startIndex);
      _track = pontos;
      _profile = RouteProfile(pontos);
      if (isLoop(route.points)) _loop = LoopTerrain(_profile!);
      _routeName = route.name;
      final tipo = target.ghost;
      if (tipo != null) {
        final pedais = await ref.read(ridesStoreProvider).forRoute(id, withSamples: true);
        if (!ref.mounted) return;
        final opcoes = ghostOptions(pedais, reversed: target.reversed, lapLength: _loop?.lapLength);
        for (final o in opcoes) {
          if (o.kind == tipo) _ghost = o.ghost;
        }
      }
    }
    final treinoId = target.workoutId;
    if (treinoId != null) {
      final treino = ref.read(workoutLookupProvider)(treinoId);
      if (treino == null) {
        state = const RideView(notFound: true);
        return;
      }
      _workout = treino;
      _ftp = settings.ftp ?? defaultFtp(settings.pesoKg);
      _runner = WorkoutRunner(treino, ftp: _ftp, intensity: settings.intensidade);
      _terrenoTreino = WorkoutTerrain();
      final controle = ref.read(bikeControllerProvider).source?.control;
      _controle = settings.controleBike && controle != null && controle.features.any ? controle : null;
    }
    _calibracao = PowerCalibration(base: settings.base, factor: settings.fator);
    _margem = settings.margemVolta;
    _vozLigada = settings.voz;
    _voz = ref.read(voiceProvider);
    await _voz!.choose(settings.vozId);
    if (!ref.mounted) return;
    _narrador = RideNarrator(routeLength: _loop == null ? _profile?.distance : null);
    final relogio = ref.read(clockProvider);
    final Terrain terreno = _loop ?? _profile ?? _terrenoTreino ?? const FlatTerrain();
    _session = RideSession(terrain: terreno, riderMassKg: settings.pesoKg)..start();
    _resolver = PowerResolver(
      mode: settings.modoPotencia,
      calibration: PowerCalibration(base: settings.base, factor: settings.fator),
    );
    _level = settings.cargaPadrao;
    _startedAt = relogio();
    _lastTick = _startedAt;
    _rideId = ref.read(rideIdProvider)();
    final source = ref.read(bikeControllerProvider).source;
    _readingSub = source?.readings.listen(onReading);
    _connectionSub = source?.connection.listen(_onConnection);
    _wakeLock = ref.read(wakeLockProvider);
    await _wakeLock!.enable();
    await _save(completed: false);
    if (!ref.mounted) return;
    _ticker = Timer.periodic(ref.read(rideTickProvider), (_) => tick());
    _publish();
  }

  @visibleForTesting
  void onReading(BikeReading r) {
    final session = _session;
    final resolver = _resolver;
    if (session == null || resolver == null || !ref.mounted) return;
    _lastReading = ref.read(clockProvider)();
    final watts = resolver.resolve(cadence: r.cadence, power: r.power, timestamp: r.timestamp, level: _level);
    session.setInputs(powerW: watts.toDouble(), cadence: r.cadence ?? 0, heartRate: r.heartRate?.toDouble());
  }

  void _onConnection(BikeConnection c) {
    final session = _session;
    if (session == null || !ref.mounted) return;
    final caiu = c == BikeConnection.caiu || c == BikeConnection.desconectada;
    if (caiu && session.state == RideState.pedalando) {
      session
        ..pause()
        ..setInputs(powerW: 0, cadence: 0);
      _pausedByBike = true;
      _falar([RideNarrator.bikeDropped]);
      _publish();
    } else if (c == BikeConnection.conectada && _pausedByBike) {
      _pausedByBike = false;
      session.resume();
      _publish();
    }
  }

  @visibleForTesting
  void tick() {
    final session = _session;
    if (session == null || session.state == RideState.concluido || !ref.mounted) return;
    final now = ref.read(clockProvider)();
    final dt = (now.difference(_lastTick ?? now).inMicroseconds / 1e6).clamp(0.0, 1.0).toDouble();
    _lastTick = now;
    final last = _lastReading;
    if (last == null || now.difference(last) > _staleAfter) session.setInputs(powerW: 0, cadence: 0);
    final alerts = session.advance(dt);
    if (alerts.isNotEmpty) {
      _alert = alerts.last;
      _alertAt = now;
    }
    final snap = session.snapshot();
    final loop = _loop;
    LapAlert? novaVolta;
    if (loop != null) {
      final voltas = loop.lapsAt(snap.distance);
      if (voltas > _lapsSeen) {
        _lapsSeen = voltas;
        final tempos = lapTimes(session.samples, loop.lapLength);
        novaVolta = _lapAlert = LapAlert(voltas, tempos.length >= voltas ? tempos[voltas - 1] : 0, now);
      }
    }
    if (session.samples.length > _seenSamples) {
      final novas = session.samples.skip(_seenSamples).map((s) => s.power).toList();
      _history.addAll(novas);
      for (final p in novas) {
        _runner?.addSample(p);
      }
      _seenSamples = session.samples.length;
      if (_history.length > _historyLength) _history.removeRange(0, _history.length - _historyLength);
    }
    final runner = _runner;
    if (runner != null) {
      _passoDoTreino(runner, session, snap);
    } else {
      final ghost = _ghost;
      _falar(_narrador?.update(
        distance: snap.distance,
        movingTime: snap.movingTime,
        alert: alerts.isEmpty ? null : alerts.last,
        lapDone: novaVolta?.number,
        lapTime: novaVolta?.time,
        ghostGapS: ghost?.gapSeconds(snap.distance, snap.movingTime),
        ghostGapM: ghost?.gapMeters(snap.distance, snap.movingTime),
      ));
    }
    _sinceSave += dt;
    if (_sinceSave >= _saveEverySeconds) {
      _sinceSave = 0;
      _save(completed: false);
    }
    _publish();
  }

  /// Potência dos últimos 3 s (a de agora oscila demais para dizer se está na meta).
  double _potencia3s(RideSession session, double agora) {
    final s = session.samples;
    if (s.length < 3) return agora;
    return (s[s.length - 1].power + s[s.length - 2].power + s[s.length - 3].power) / 3;
  }

  void _passoDoTreino(WorkoutRunner runner, RideSession session, RideSnapshot snap) {
    final frame = runner.update(
      snap.movingTime,
      power: _potencia3s(session, snap.power),
      cadence: snap.cadence,
    );
    _frame = frame;
    _falar(List.of(runner.spoken));
    if (runner.stepChanged != null) _terrenoTreino?.grade = frame.step.grade;
    _mandarAlvo(frame, mudouPasso: runner.stepChanged != null);
    if (frame.done && !_treinoCompleto) {
      _treinoCompleto = true;
      session.finish();
    }
  }

  /// Manda a meta para a bike: potência (ERG) quando ela aceita; senão, a inclinação dos
  /// trechos de subida. Numa rampa, atualiza a cada 5 W.
  void _mandarAlvo(WorkoutFrame frame, {required bool mudouPasso}) {
    final controle = _controle;
    if (controle == null) return;
    if (controle.features.power) {
      final alvo = frame.targetWatts;
      final ultimo = _alvoEnviado;
      if (mudouPasso || ultimo == null || (alvo - ultimo).abs() >= 5) {
        _alvoEnviado = alvo;
        controle.setPower(alvo);
      }
    } else if (mudouPasso && controle.features.simulation) {
      controle.setGrade(frame.step.grade);
    }
  }

  /// Teste de rampa: “não aguento mais”.
  void endRamp() {
    final runner = _runner;
    if (runner == null) return;
    runner.endRamp();
    _falar(List.of(runner.spoken));
    final session = _session;
    if (session != null) _passoDoTreino(runner, session, session.snapshot());
    _publish();
  }

  void _falar(List<String>? frases) {
    final voz = _voz;
    if (!_vozLigada || voz == null || frases == null) return;
    for (final f in frases) {
      voz.speak(f);
    }
  }

  /// Liga ou desliga a voz (e guarda a escolha para os próximos pedais).
  Future<void> toggleVoice() async {
    _vozLigada = !_vozLigada;
    if (!_vozLigada) _voz?.stop();
    _publish();
    final store = ref.read(settingsStoreProvider);
    final atual = await store.load();
    await store.save(atual.copyWith(voz: _vozLigada));
    if (ref.mounted) ref.invalidate(settingsProvider);
  }

  void changeLevel(int delta) {
    _level = (_level + delta).clamp(1, 10);
    _publish();
  }

  void togglePause() {
    final session = _session;
    if (session == null) return;
    if (session.state == RideState.pedalando) {
      session.pause();
    } else if (session.state == RideState.pausado) {
      _pausedByBike = false;
      session.resume();
    }
    _publish();
  }

  /// Encerra, salva como concluído e devolve o id do pedal. Chamar de novo só devolve o id.
  Future<String> finish() async {
    final session = _session!;
    if (_finished) return _rideId!;
    _finished = true;
    final snap = session.snapshot();
    final perfil = _profile;
    final ghost = _ghost;
    if (_workout != null) {
      _falar([
        _treinoCompleto
            ? 'Treino concluído em ${spokenTime(snap.movingTime)}! Muito bem.'
            : 'Treino encerrado: ${spokenTime(snap.movingTime)}.',
      ]);
    } else {
      _falar([
        _narrador!.finished(
          completed: perfil != null && _loop == null && snap.distance >= perfil.distance - 0.5,
          laps: _loop?.lapsAt(snap.distance) ?? 0,
          movingTime: snap.movingTime,
          ghostGapS: ghost?.gapSeconds(snap.distance, snap.movingTime),
        ),
      ]);
    }
    session.finish();
    _stop();
    await _save(completed: true);
    final novoFtp = _runner?.rampFtp;
    if (novoFtp != null) {
      final store = ref.read(settingsStoreProvider);
      await store.save((await store.load()).copyWith(ftp: novoFtp));
      if (ref.mounted) ref.invalidate(settingsProvider);
    }
    if (ref.mounted) {
      ref
        ..invalidate(recentRidesProvider)
        ..invalidate(rideStatsProvider)
        ..invalidate(doneWorkoutsProvider);
      _publish();
    }
    return _rideId!;
  }

  Future<void> _save({required bool completed}) async {
    final session = _session;
    final id = _rideId;
    final started = _startedAt;
    if (session == null || id == null || started == null) return;
    final snap = session.snapshot();
    var pedal = RideRecord(
      id: id,
      routeId: routeId,
      mode: _workout != null
          ? RideMode.treino
          : _profile != null
              ? RideMode.rota
              : RideMode.livre,
      startedAt: started,
      movingTimeS: snap.movingTime,
      distanceM: snap.distance,
      avgPowerW: snap.avgPower,
      avgSpeedKmh: snap.avgSpeedKmh,
      gainM: snap.climbed,
      kcal: snap.kcal,
      completed: completed,
      samples: List.of(session.samples),
      laps: _voltasCompletas(snap.distance),
      loop: _loop != null,
      reversed: target.reversed,
      track: _track,
      workoutId: _workout?.id,
      ftp: _runner?.rampFtp,
    );
    final loop = _loop;
    if (completed && loop != null) {
      final fechada = closeLap(
        samples: session.samples,
        lapLength: loop.lapLength,
        margin: _margem,
        climbedUpTo: loop.climbedUpTo,
      );
      if (fechada != null) {
        pedal = pedal.copyWith(
          movingTimeS: fechada.movingTime,
          distanceM: fechada.distance,
          avgPowerW: fechada.avgPower,
          avgSpeedKmh: fechada.avgSpeedKmh,
          gainM: fechada.climbed,
          kcal: fechada.kcal,
          samples: fechada.samples,
          laps: fechada.laps,
          trimmedM: fechada.trimmed,
        );
      }
    }
    await ref.read(ridesStoreProvider).upsert(pedal);
  }

  int _voltasCompletas(double distancia) {
    if (_workout != null) return _treinoCompleto || _runner?.rampFtp != null ? 1 : 0;
    final loop = _loop;
    if (loop != null) return loop.lapsAt(distancia);
    final perfil = _profile;
    return perfil != null && distancia >= perfil.distance - 0.5 ? 1 : 0;
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _readingSub?.cancel();
    _readingSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _wakeLock?.disable();
    _wakeLock = null;
    _controle?.release();
    _controle = null;
  }

  void _publish() {
    final session = _session;
    if (session == null) return;
    final snap = session.snapshot();
    final voltas = _loop?.lapsAt(snap.distance) ?? 0;
    final ghost = _ghost;
    final perfil = _profile;
    GeoPoint? ondeFantasma;
    if (ghost != null && perfil != null) {
      final d = ghost.distanceAt(snap.movingTime);
      final volta = _loop?.lapLength;
      ondeFantasma = perfil.positionAt(volta == null || volta <= 0 ? d : d - (d / volta + 1e-9).floor() * volta);
    }
    state = RideView(
      started: true,
      state: snap.state,
      speedKmh: snap.speedKmh,
      power: snap.power,
      cadence: snap.cadence,
      heartRate: snap.heartRate,
      distance: snap.distance,
      total: snap.total,
      grade: snap.grade,
      movingTime: snap.movingTime,
      kcal: snap.kcal,
      level: _level,
      estimating: _resolver?.effectiveMode == PowerMode.estimada,
      pausedByBike: _pausedByBike,
      powerHistory: List.unmodifiable(_history),
      routeName: _routeName,
      position: _profile?.positionAt(snap.distance - voltas * (_loop?.lapLength ?? 0)),
      alert: _alert,
      alertAt: _alertAt,
      profile: _profile,
      lapLength: _loop?.lapLength,
      lapsDone: voltas,
      lapAlert: _lapAlert,
      ghostGapS: ghost?.gapSeconds(snap.distance, snap.movingTime),
      ghostGapM: ghost?.gapMeters(snap.distance, snap.movingTime),
      ghostPosition: ondeFantasma,
      voiceOn: _vozLigada,
      workout: _workout,
      frame: _frame,
      ftp: _ftp,
      bikeAdjusts: _controle?.features.power ?? false,
      suggestedLevel: _frame == null || _resolver?.effectiveMode != PowerMode.estimada
          ? null
          : ((_frame!.targetWatts / 85 - _calibracao.base) / _calibracao.factor).round().clamp(1, 10),
    );
  }
}

final rideProvider = NotifierProvider.autoDispose.family<RideController, RideView, RideTarget>(RideController.new);
