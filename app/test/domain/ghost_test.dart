import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ghost.dart';
import 'package:pedal_local/domain/laps.dart';
import 'package:pedal_local/domain/ride_session.dart';

import '../support/geo_helpers.dart';

/// Uma amostra por segundo, andando [vel] m/s (pode mudar no meio).
List<RideSample> amostras(int segundos, double Function(int s) vel) {
  final lista = <RideSample>[];
  var d = 0.0;
  for (var s = 1; s <= segundos; s++) {
    d += vel(s);
    lista.add(RideSample(t: s.toDouble(), distance: d, speedKmh: vel(s) * 3.6, power: 150, cadence: 80));
  }
  return lista;
}

void main() {
  group('fantasma de uma ida', () {
    final ghost = Ghost.ride(amostras(100, (s) => 5)); // 500 m em 100 s

    test('sabe quando passou por cada distância e onde está em cada tempo', () {
      expect(ghost.length, 500);
      expect(ghost.time, 100);
      expectNear(ghost.timeAt(250), 50, 1e-9);
      expectNear(ghost.timeAt(2.5), 0.5, 1e-9);
      expectNear(ghost.distanceAt(30), 150, 1e-9);
      expect(ghost.timeAt(0), 0);
    });

    test('quem está mais adiantado no mesmo tempo tem vantagem positiva', () {
      // Em 40 s o fantasma estava em 200 m; você já está em 240 m.
      expectNear(ghost.gapSeconds(240, 40), 8, 1e-9); // ele passou em 240 m só aos 48 s
      expectNear(ghost.gapMeters(240, 40), -40, 1e-9); // ele está 40 m atrás
      expectNear(ghost.gapSeconds(150, 40), -10, 1e-9);
      expectNear(ghost.gapMeters(150, 40), 50, 1e-9);
    });

    test('depois do fim o fantasma espera na chegada', () {
      expect(ghost.distanceAt(130), 500);
      expect(ghost.timeAt(600), 100);
    });

    test('parado sem andar: vale a primeira vez que chegou na distância', () {
      final comParada = Ghost.ride([
        const RideSample(t: 1, distance: 10, speedKmh: 36, power: 100, cadence: 80),
        const RideSample(t: 2, distance: 10, speedKmh: 0, power: 100, cadence: 80),
        const RideSample(t: 3, distance: 20, speedKmh: 36, power: 100, cadence: 80),
      ]);
      expect(comParada.timeAt(10), 1);
      expectNear(comParada.timeAt(15), 2.5, 1e-9);
      expect(comParada.distanceAt(2), 10);
    });
  });

  group('fantasma de uma volta', () {
    // Volta de 300 m: a primeira em 60 s (5 m/s), a segunda em 30 s (10 m/s), e mais 50 m.
    final pedal = amostras(95, (s) => s <= 60 ? 5 : 10);
    final voltas = lapSlices(pedal, 300);

    test('a volta escolhida se repete a cada volta', () {
      final segunda = Ghost.lap(pedal, voltas[1]);
      expect(segunda.repeats, isTrue);
      expectNear(segunda.length, 300, 1e-9);
      expectNear(segunda.time, 30, 1e-9);
      expectNear(segunda.timeAt(150), 15, 1e-9);
      expectNear(segunda.timeAt(450), 45, 1e-9); // uma volta inteira + meia
      expectNear(segunda.distanceAt(70), 700, 1e-9);
    });

    test('a primeira volta começa do zero e a volta é esticada para o comprimento de hoje', () {
      final primeira = Ghost.lap(pedal, voltas[0], lapLength: 330);
      expectNear(primeira.length, 330, 1e-9);
      expectNear(primeira.time, 60, 1e-9);
      expectNear(primeira.timeAt(165), 30, 1e-9);
    });
  });
}
