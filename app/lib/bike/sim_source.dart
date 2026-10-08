import 'dart:async';
import 'dart:math' as math;

import '../domain/ftms_control.dart';
import 'bike_control.dart';
import 'bike_reading.dart';
import 'bike_source.dart';

/// Bike falsa: cadência e potência a cada [interval], para testar sem a bike real.
class SimSource implements BikeSource {
  SimSource({this.interval = const Duration(seconds: 1), math.Random? random, DateTime Function()? now})
      : _random = random ?? math.Random(),
        _now = now ?? DateTime.now;

  final Duration interval;
  final math.Random _random;
  final DateTime Function() _now;
  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  BikeConnection _state = BikeConnection.desconectada;
  Timer? _timer;
  int _target = 150;
  double _power = 0;

  int get target => _target;

  /// A bike simulada aceita potência alvo, como uma bike com modo ERG.
  @override
  late final BikeControl control = _SimControl(this);

  @override
  String get name => 'Bike simulada';

  @override
  bool get simulated => true;

  @override
  Stream<BikeReading> get readings => _readings.stream;

  @override
  Stream<BikeConnection> get connection => _connection.stream;

  @override
  BikeConnection get state => _state;

  BikeReading sample() {
    _power = math.max(0.0, _power + (_target - _power) * 0.4 + (_random.nextDouble() - 0.5) * 12);
    if (_target == 0 && _power < 15) _power = 0;
    final cadence = _power == 0
        ? 0.0
        : (65 + _power / 12 + (_random.nextDouble() - 0.5) * 4).clamp(55.0, 105.0).roundToDouble();
    return BikeReading(cadence: cadence, power: _power.round(), timestamp: _now());
  }

  void setTarget(int watts) => _target = watts.clamp(0, 2000);

  void harder() => _target = math.min(400, _target + 25);

  void easier() => _target = math.max(0, _target - 25);

  void _set(BikeConnection c) {
    _state = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect() async {
    _timer ??= Timer.periodic(interval, (_) {
      if (!_readings.isClosed) _readings.add(sample());
    });
    _set(BikeConnection.conectada);
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _set(BikeConnection.desconectada);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _readings.close();
    await _connection.close();
  }
}

class _SimControl implements BikeControl {
  _SimControl(this._sim);

  final SimSource _sim;

  @override
  FtmsFeatures get features => const FtmsFeatures(power: true);

  @override
  FtmsRange? get resistanceRange => null;

  @override
  Future<bool> setPower(int watts) async {
    _sim.setTarget(watts);
    return true;
  }

  @override
  Future<bool> setResistance(double level) async => false;

  @override
  Future<bool> setGrade(double grade) async => false;

  @override
  Future<void> release() async {}
}
