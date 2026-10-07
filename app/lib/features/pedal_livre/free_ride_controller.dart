import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_source.dart';
import '../../core/wake_lock.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../domain/power.dart';
import '../../domain/ride_session.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final rideIdProvider = Provider<String Function()>(
  (ref) => () => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
);
final rideTickProvider = Provider<Duration>((ref) => const Duration(milliseconds: 250));

const _historyLength = 300; // 5 minutos de amostras
const _staleAfter = Duration(seconds: 3);
const _saveEverySeconds = 15.0;

class FreeRideView {
  const FreeRideView({
    this.started = false,
    this.state = RideState.pronto,
    this.speedKmh = 0,
    this.power = 0,
    this.cadence = 0,
    this.heartRate,
    this.distance = 0,
    this.movingTime = 0,
    this.kcal = 0,
    this.level = 4,
    this.estimating = false,
    this.pausedByBike = false,
    this.powerHistory = const [],
  });

  final bool started;
  final RideState state;
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
  final double distance;
  final double movingTime;
  final double kcal;
  final int level;
  final bool estimating;
  final bool pausedByBike;
  final List<double> powerHistory;
}

class FreeRideController extends Notifier<FreeRideView> {
  RideSession? _session;
  PowerResolver? _resolver;
  WakeLock? _wakeLock;
  Timer? _ticker;
  StreamSubscription<BikeReading>? _readingSub;
  StreamSubscription<BikeConnection>? _connectionSub;
  DateTime? _startedAt;
  DateTime? _lastTick;
  DateTime? _lastReading;
  String? _rideId;
  double _sinceSave = 0;
  int _level = 4;
  int _seenSamples = 0;
  bool _pausedByBike = false;
  final List<double> _history = [];

  @override
  FreeRideView build() {
    ref.onDispose(_stop);
    return const FreeRideView();
  }

  Future<void> start() async {
    if (_session != null) return;
    final settings = await ref.read(settingsStoreProvider).load();
    if (!ref.mounted || _session != null) return;
    final clock = ref.read(clockProvider);
    _session = RideSession(terrain: const FlatTerrain(), riderMassKg: settings.pesoKg)..start();
    _resolver = PowerResolver(
      mode: settings.modoPotencia,
      calibration: PowerCalibration(base: settings.base, factor: settings.fator),
    );
    _level = settings.cargaPadrao;
    _startedAt = clock();
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
    session.advance(dt);
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

  /// Encerra, salva como concluído e devolve o id do pedal.
  Future<String> finish() async {
    final session = _session!;
    session.finish();
    _stop();
    await _save(completed: true);
    if (ref.mounted) {
      ref.invalidate(recentRidesProvider);
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
    await ref.read(ridesStoreProvider).upsert(RideRecord(
          id: id,
          mode: RideMode.livre,
          startedAt: started,
          movingTimeS: snap.movingTime,
          distanceM: snap.distance,
          avgPowerW: snap.avgPower,
          avgSpeedKmh: snap.avgSpeedKmh,
          gainM: snap.climbed,
          kcal: snap.kcal,
          completed: completed,
          samples: List.of(session.samples),
        ));
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
    state = FreeRideView(
      started: true,
      state: snap.state,
      speedKmh: snap.speedKmh,
      power: snap.power,
      cadence: snap.cadence,
      heartRate: snap.heartRate,
      distance: snap.distance,
      movingTime: snap.movingTime,
      kcal: snap.kcal,
      level: _level,
      estimating: _resolver?.effectiveMode == PowerMode.estimada,
      pausedByBike: _pausedByBike,
      powerHistory: List.unmodifiable(_history),
    );
  }
}

final freeRideProvider = NotifierProvider.autoDispose<FreeRideController, FreeRideView>(FreeRideController.new);
