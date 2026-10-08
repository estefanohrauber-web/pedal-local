import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/features/pedal/ghost_options.dart';

import '../support/geo_helpers.dart';

/// Pedal numa rota a [vel] m/s constante por [segundos].
RideRecord pedal(
  String id,
  DateTime quando, {
  required int segundos,
  required double Function(int s) vel,
  int laps = 1,
  bool reversed = false,
  bool loop = false,
}) {
  final amostras = <RideSample>[];
  var d = 0.0;
  for (var s = 1; s <= segundos; s++) {
    d += vel(s);
    amostras.add(RideSample(t: s.toDouble(), distance: d, speedKmh: vel(s) * 3.6, power: 150, cadence: 80));
  }
  return RideRecord(
    id: id,
    routeId: 'r1',
    mode: RideMode.rota,
    startedAt: quando,
    movingTimeS: segundos.toDouble(),
    distanceM: d,
    avgPowerW: 150,
    avgSpeedKmh: d / segundos * 3.6,
    gainM: 0,
    kcal: 1,
    completed: true,
    samples: amostras,
    laps: laps,
    reversed: reversed,
    loop: loop,
  );
}

void main() {
  final ontem = DateTime(2026, 10, 7, 18);
  final hoje = DateTime(2026, 10, 8, 18);

  group('ida', () {
    test('recorde é o pedal mais rápido e último é o mais novo', () {
      final rapido = pedal('rapido', ontem, segundos: 100, vel: (s) => 5);
      final lento = pedal('lento', hoje, segundos: 125, vel: (s) => 4);
      final opcoes = ghostOptions([lento, rapido], reversed: false);
      expect(opcoes.map((o) => o.kind), [GhostKind.recorde, GhostKind.ultimo]);
      expect(opcoes[0].time, 100);
      expect(opcoes[0].label, 'Seu recorde');
      expect(opcoes[1].time, 125);
      expect(opcoes[1].label, 'Último pedal');
      expectNear(opcoes[0].ghost.timeAt(250), 50, 1e-9);
    });

    test('quando o recorde é o último pedal, só aparece o recorde', () {
      final opcoes = ghostOptions([pedal('a', hoje, segundos: 90, vel: (s) => 5)], reversed: false);
      expect(opcoes.map((o) => o.kind), [GhostKind.recorde]);
    });

    test('ignora o outro sentido e pedais que não chegaram ao fim', () {
      final outroSentido = pedal('inv', hoje, segundos: 80, vel: (s) => 6, reversed: true);
      final incompleto = pedal('inc', hoje, segundos: 30, vel: (s) => 5, laps: 0);
      expect(ghostOptions([outroSentido, incompleto], reversed: false), isEmpty);
      expect(ghostOptions([outroSentido, incompleto], reversed: true).single.time, 80);
    });
  });

  group('volta fechada', () {
    test('melhor volta de qualquer pedal e última volta completa do pedal mais novo', () {
      // Volta de 300 m. Ontem: 60 s e 30 s. Hoje: 50 s e 40 s.
      final antes = pedal('antes', ontem, segundos: 90, vel: (s) => s <= 60 ? 5 : 10, laps: 2, loop: true);
      final depois = pedal('depois', hoje, segundos: 90, vel: (s) => s <= 50 ? 6 : 7.5, laps: 2, loop: true);
      final opcoes = ghostOptions([depois, antes], reversed: false, lapLength: 300);
      expect(opcoes.map((o) => o.kind), [GhostKind.recorde, GhostKind.ultimo]);
      expectNear(opcoes[0].time, 30, 1e-9);
      expect(opcoes[0].label, 'Sua melhor volta');
      expect(opcoes[0].ghost.repeats, isTrue);
      expectNear(opcoes[1].time, 40, 1e-9);
      expect(opcoes[1].label, 'Sua última volta');
    });

    test('a volta incompleta do fim não conta', () {
      final p = pedal('p', hoje, segundos: 70, vel: (s) => 5, laps: 1, loop: true); // 350 m: 1 volta + 50 m
      final opcoes = ghostOptions([p], reversed: false, lapLength: 300);
      expect(opcoes.single.kind, GhostKind.recorde);
      expectNear(opcoes.single.time, 60, 1e-9);
    });
  });
}
