import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/bike/sim_source.dart';

class _HalfRandom implements math.Random {
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

final _agora = DateTime(2026, 10, 7, 20);

BikeReading amostrar(SimSource sim, int n) {
  late BikeReading r;
  for (var i = 0; i < n; i++) {
    r = sim.sample();
  }
  return r;
}

void main() {
  test('converge para a potência alvo com cadência plausível', () {
    final sim = SimSource(random: _HalfRandom(), now: () => _agora);
    final r = amostrar(sim, 20);
    expect(r.power, closeTo(150, 1));
    expect(r.cadence, inInclusiveRange(70, 90));
    expect(r.timestamp, _agora);
  });

  test('mais forte e mais fraco mudam o alvo', () {
    final sim = SimSource(random: _HalfRandom(), now: () => _agora);
    sim
      ..harder()
      ..harder();
    expect(sim.target, 200);
    expect(amostrar(sim, 20).power, closeTo(200, 1));
    for (var i = 0; i < 10; i++) {
      sim.easier();
    }
    expect(sim.target, 0);
    final parado = amostrar(sim, 20);
    expect(parado.power, 0);
    expect(parado.cadence, 0);
    for (var i = 0; i < 30; i++) {
      sim.harder();
    }
    expect(sim.target, 400);
  });

  test('connect emite leituras e muda o estado', () async {
    final sim = SimSource(interval: const Duration(milliseconds: 5));
    final leituras = <BikeReading>[];
    final sub = sim.readings.listen(leituras.add);
    await sim.connect();
    expect(sim.state, BikeConnection.conectada);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await sim.disconnect();
    expect(sim.state, BikeConnection.desconectada);
    expect(leituras, isNotEmpty);
    await sub.cancel();
    await sim.dispose();
  });
}
