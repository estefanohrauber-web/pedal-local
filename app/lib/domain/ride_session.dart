import 'dart:math' as math;

import 'physics.dart';

/// Terreno sob a sessão: inclinação em função da distância percorrida.
abstract interface class Terrain {
  /// Comprimento em metros; `double.infinity` = sem fim (pedal livre).
  double get distance;
  double gradeAt(double distance);
  double lookahead(double distance, double span);
}

/// Pedal livre: plano e sem fim.
class FlatTerrain implements Terrain {
  const FlatTerrain();

  @override
  double get distance => double.infinity;

  @override
  double gradeAt(double distance) => 0;

  @override
  double lookahead(double distance, double span) => 0;
}

enum RideState { pronto, pedalando, pausado, concluido }

enum AlertKind { subida, descida }

class RideAlert {
  const RideAlert(this.kind, this.grade);
  final AlertKind kind;
  final double grade;
}

class RideSample {
  const RideSample({
    required this.t,
    required this.distance,
    required this.speedKmh,
    required this.power,
    required this.cadence,
    this.heartRate,
  });

  final double t; // tempo em movimento (s)
  final double distance; // m
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
}

class RideSnapshot {
  const RideSnapshot({
    required this.state,
    required this.distance,
    required this.total,
    required this.speedKmh,
    required this.power,
    required this.cadence,
    required this.heartRate,
    required this.grade,
    required this.movingTime,
    required this.avgPower,
    required this.avgSpeedKmh,
    required this.kcal,
    required this.climbed,
  });

  final RideState state;
  final double distance;
  final double total;
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
  final double grade;
  final double movingTime;
  final double avgPower;
  final double avgSpeedKmh;
  final double kcal;
  final double climbed;
}

const alertLookaheadM = 200.0;
const climbAlertGrade = 0.04;
const descentAlertGrade = -0.03;

/// Sessão de pedal. Estados: pronto → pedalando ⇄ pausado → concluido.
class RideSession {
  RideSession({required this.terrain, required this.riderMassKg});

  final Terrain terrain;
  final double riderMassKg;
  final List<RideSample> samples = [];

  RideState _state = RideState.pronto;
  double _speed = 0;
  double _distance = 0;
  double _movingTime = 0;
  double _energyJ = 0;
  double _climbed = 0;
  double _sinceSample = 0;
  double _power = 0;
  double _cadence = 0;
  double? _heartRate;
  // Um aviso só volta depois que o trecho à frente deixa de ser subida/descida.
  bool _armClimb = true;
  bool _armDescent = true;

  RideState get state => _state;

  void start() {
    if (_state == RideState.pronto) _state = RideState.pedalando;
  }

  void pause() {
    if (_state == RideState.pedalando) {
      _state = RideState.pausado;
      _speed = 0;
    }
  }

  void resume() {
    if (_state == RideState.pausado) _state = RideState.pedalando;
  }

  void finish() {
    _state = RideState.concluido;
    _speed = 0;
  }

  void setInputs({required double powerW, required double cadence, double? heartRate}) {
    _power = math.max(0.0, powerW);
    _cadence = cadence;
    _heartRate = heartRate;
  }

  List<RideAlert> advance(double seconds) {
    final alerts = <RideAlert>[];
    var remaining = seconds;
    while (_state == RideState.pedalando && remaining > 1e-9) {
      final dt = math.min(physicsDt, remaining);
      remaining -= dt;
      final grade = terrain.gradeAt(_distance);
      _speed = stepSpeed(_speed, powerW: _power, grade: grade, riderMassKg: riderMassKg, dt: dt);
      final step = _speed * dt;
      _distance += step;
      if (grade > 0) _climbed += grade * step;
      if (_speed > 0 || _power > 0) {
        _movingTime += dt;
        _energyJ += _power * dt;
        _sinceSample += dt;
        if (_sinceSample >= 1 - 1e-9) {
          _sinceSample -= 1;
          samples.add(_sample());
        }
      }
      if (_distance >= terrain.distance) {
        _distance = terrain.distance;
        _state = RideState.concluido;
        samples.add(_sample());
        break;
      }
      final alert = _checkAlert();
      if (alert != null) alerts.add(alert);
    }
    return alerts;
  }

  RideSnapshot snapshot() => RideSnapshot(
        state: _state,
        distance: _distance,
        total: terrain.distance,
        speedKmh: _speed * 3.6,
        power: _power,
        cadence: _cadence,
        heartRate: _heartRate,
        grade: terrain.gradeAt(_distance),
        movingTime: _movingTime,
        avgPower: _movingTime > 0 ? _energyJ / _movingTime : 0,
        avgSpeedKmh: _movingTime > 0 ? _distance / _movingTime * 3.6 : 0,
        kcal: _energyJ / 1000,
        climbed: _climbed,
      );

  RideSample _sample() => RideSample(
        t: _movingTime,
        distance: _distance,
        speedKmh: _speed * 3.6,
        power: _power,
        cadence: _cadence,
        heartRate: _heartRate,
      );

  RideAlert? _checkAlert() {
    final g = terrain.lookahead(_distance, alertLookaheadM);
    if (g < climbAlertGrade / 2) _armClimb = true;
    if (g > descentAlertGrade / 2) _armDescent = true;
    if (_armClimb && g >= climbAlertGrade) {
      _armClimb = false;
      return RideAlert(AlertKind.subida, g);
    }
    if (_armDescent && g <= descentAlertGrade) {
      _armDescent = false;
      return RideAlert(AlertKind.descida, g);
    }
    return null;
  }
}
