import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_source.dart';
import '../../core/wake_lock.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../domain/geo.dart';
import '../../domain/laps.dart';
import '../../domain/power.dart';
import '../../domain/ride_session.dart';
import '../../domain/route_profile.dart';
import '../../domain/route_variant.dart';

/// Relógio do pedal. `clock.now()` é o relógio real no app e o relógio simulado nos testes de tela.
final clockProvider = Provider<DateTime Function()>((ref) => () => clock.now());
final rideIdProvider = Provider<String Function()>(
  (ref) => () => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
);
final rideTickProvider = Provider<Duration>((ref) => const Duration(milliseconds: 250));

const _historyLength = 300; // 5 minutos de amostras
const _staleAfter = Duration(seconds: 3);
const _saveEverySeconds = 15.0;

/// O que pedalar: pedal livre (sem rota) ou uma rota no sentido e começo escolhidos.
@immutable
class RideTarget {
  const RideTarget({this.routeId, this.reversed = false, this.startIndex = 0});

  static const livre = RideTarget();

  final String? routeId;
  final bool reversed;

  /// Índice dos pontos originais onde a volta começa (só vale para volta fechada).
  final int startIndex;

  @override
  bool operator ==(Object other) =>
      other is RideTarget && other.routeId == routeId && other.reversed == reversed && other.startIndex == startIndex;

  @override
  int get hashCode => Object.hash(routeId, reversed, startIndex);
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
    }
    _margem = settings.margemVolta;
    final relogio = ref.read(clockProvider);
    final Terrain terreno = _loop ?? _profile ?? const FlatTerrain();
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
    final loop = _loop;
    if (loop != null) {
      final voltas = loop.lapsAt(session.snapshot().distance);
      if (voltas > _lapsSeen) {
        _lapsSeen = voltas;
        final tempos = lapTimes(session.samples, loop.lapLength);
        _lapAlert = LapAlert(voltas, tempos.length >= voltas ? tempos[voltas - 1] : 0, now);
      }
    }
    if (session.samples.length > _seenSamples) {
      _history.addAll(session.samples.skip(_seenSamples).map((s) => s.power));
      _seenSamples = session.samples.length;
      if (_history.length > _historyLength) _history.removeRange(0, _history.length - _historyLength);
    }
    _sinceSave += dt;
    if (_sinceSave >= _saveEverySeconds) {
      _sinceSave = 0;
      _save(completed: false);
    }
    _publish();
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
    session.finish();
    _stop();
    await _save(completed: true);
    if (ref.mounted) {
      ref
        ..invalidate(recentRidesProvider)
        ..invalidate(rideStatsProvider);
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
      mode: _profile != null ? RideMode.rota : RideMode.livre,
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
  }

  void _publish() {
    final session = _session;
    if (session == null) return;
    final snap = session.snapshot();
    final voltas = _loop?.lapsAt(snap.distance) ?? 0;
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
    );
  }
}

final rideProvider = NotifierProvider.autoDispose.family<RideController, RideView, RideTarget>(RideController.new);
