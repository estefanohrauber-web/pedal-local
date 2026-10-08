import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

double _zero(double _) => 0;

class FakeTerrain implements Terrain {
  FakeTerrain({this.distance = 5000, this.grade = _zero, this.ahead = _zero});

  @override
  final double distance;
  final double Function(double) grade;
  final double Function(double) ahead;

  @override
  double gradeAt(double distance) => grade(distance);

  @override
  double lookahead(double distance, double span) => ahead(distance);
}

List<RideAlert> pedal(RideSession ride, int seconds) {
  final alerts = <RideAlert>[];
  for (var i = 0; i < seconds; i++) {
    alerts.addAll(ride.advance(1));
  }
  return alerts;
}

RideSession nova({Terrain? terrain}) =>
    RideSession(terrain: terrain ?? FakeTerrain(), riderMassKg: 75)..start();

void main() {
  test('antes de começar não anda', () {
    final ride = RideSession(terrain: FakeTerrain(), riderMassKg: 75);
    ride.setInputs(powerW: 200, cadence: 85);
    ride.advance(10);
    expect(ride.state, RideState.pronto);
    expect(ride.snapshot().distance, 0);
  });

  test('pedalando no plano avança e ganha velocidade', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 60);
    final s = ride.snapshot();
    expect(s.state, RideState.pedalando);
    expect(s.distance, greaterThan(300));
    expect(s.speedKmh, greaterThan(20));
    expect(s.cadence, 80);
  });

  test('chega ao fim e conclui', () {
    final ride = nova(terrain: FakeTerrain(distance: 100))..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 120);
    expect(ride.state, RideState.concluido);
    expect(ride.snapshot().distance, 100);
  });

  test('pausar zera a velocidade e congela a distância', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 30);
    ride.pause();
    final d = ride.snapshot().distance;
    pedal(ride, 10);
    expect(ride.state, RideState.pausado);
    expect(ride.snapshot().distance, d);
    expect(ride.snapshot().speedKmh, 0);
    ride.resume();
    pedal(ride, 5);
    expect(ride.snapshot().distance, greaterThan(d));
  });

  test('aviso de subida só repete depois de passar o trecho', () {
    double ahead(double d) => d < 300 ? 0.06 : (d < 600 ? 0 : 0.06);
    final ride = nova(terrain: FakeTerrain(distance: 2000, ahead: ahead))..setInputs(powerW: 200, cadence: 85);
    final alerts = pedal(ride, 400);
    expect(alerts.map((a) => a.kind), [AlertKind.subida, AlertKind.subida]);
    expect(alerts.first.grade, 0.06);
  });

  test('aviso de subida diz a inclinação da subida, não a média com o plano', () {
    // 300 m planos e depois 10 % de subida.
    final perfil = RouteProfile(northProfile([for (var i = 0; i < 41; i++) i <= 15 ? 760.0 : 760.0 + (i - 15) * 2]));
    final ride = nova(terrain: perfil)..setInputs(powerW: 200, cadence: 85);
    final alerts = pedal(ride, 60);
    expect(alerts.first.kind, AlertKind.subida);
    expect(alerts.first.grade, closeTo(0.10, 0.005));
  });

  test('aviso de descida', () {
    final ride = nova(terrain: FakeTerrain(ahead: (_) => -0.05))..setInputs(powerW: 100, cadence: 70);
    expect(pedal(ride, 30).map((a) => a.kind), [AlertKind.descida]);
  });

  test('médias e calorias', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 60);
    final s = ride.snapshot();
    expect(s.avgPower, closeTo(150, 1e-9));
    expect(s.kcal, closeTo(9, 1e-9)); // 150 W × 60 s = 9000 J
    expect(s.avgSpeedKmh, greaterThan(15));
    expect(s.avgSpeedKmh, lessThan(s.speedKmh));
  });

  test('grava uma amostra por segundo, com frequência cardíaca', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80, heartRate: 120);
    pedal(ride, 10);
    expect(ride.samples.length, 10);
    expect(ride.samples.last.t, closeTo(10, 1e-9));
    expect(ride.samples.last.heartRate, 120);
    expect(ride.samples.last.power, 150);
  });

  test('terreno plano nunca conclui sozinho; finish() encerra', () {
    final ride = RideSession(terrain: const FlatTerrain(), riderMassKg: 75)
      ..start()
      ..setInputs(powerW: 200, cadence: 85);
    pedal(ride, 600);
    expect(ride.state, RideState.pedalando);
    ride.finish();
    final d = ride.snapshot().distance;
    pedal(ride, 10);
    expect(ride.state, RideState.concluido);
    expect(ride.snapshot().distance, d);
  });

  test('acumula a subida feita', () {
    final ride = nova(terrain: FakeTerrain(distance: 1000, grade: (_) => 0.05))..setInputs(powerW: 250, cadence: 85);
    pedal(ride, 1200);
    expect(ride.state, RideState.concluido);
    expect(ride.snapshot().climbed, closeTo(50, 0.5));
  });
}
