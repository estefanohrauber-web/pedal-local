import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ride_narrator.dart';
import 'package:pedal_local/domain/ride_session.dart';

void main() {
  test('tempo falado', () {
    expect(spokenTime(1), '1 segundo');
    expect(spokenTime(42.4), '42 segundos');
    expect(spokenTime(60), '1 minuto');
    expect(spokenTime(252), '4 minutos e 12 segundos');
    expect(spokenTime(61), '1 minuto e 1 segundo');
    expect(spokenTime(3600), '1 hora');
    expect(spokenTime(7380), '2 horas e 3 minutos');
  });

  test('fantasma falado', () {
    expect(spokenGhost(12), 'Você está 12 segundos à frente do fantasma.');
    expect(spokenGhost(-75), 'Você está 1 minuto e 15 segundos atrás do fantasma.');
    expect(spokenGhost(0.4), 'Lado a lado com o fantasma.');
  });

  test('avisa subida e descida', () {
    final n = RideNarrator();
    expect(n.update(distance: 10, movingTime: 5, alert: const RideAlert(AlertKind.subida, 0.062)),
        ['Subida de 6 por cento chegando. Aumente a carga.']);
    expect(n.update(distance: 20, movingTime: 6, alert: const RideAlert(AlertKind.descida, -0.05)),
        ['Descida chegando. Pode aliviar a carga.']);
    expect(n.update(distance: 30, movingTime: 7), isEmpty);
  });

  test('cada quilômetro, uma vez, com o tempo e o fantasma', () {
    final n = RideNarrator();
    expect(n.update(distance: 999, movingTime: 170), isEmpty);
    expect(n.update(distance: 1001, movingTime: 172), ['1 quilômetro, em 2 minutos e 52 segundos.']);
    expect(n.update(distance: 1500, movingTime: 250), isEmpty);
    expect(n.update(distance: 2003, movingTime: 330, ghostGapS: -4),
        ['2 quilômetros, em 5 minutos e 30 segundos. Você está 4 segundos atrás do fantasma.']);
  });

  test('volta concluída no lugar do quilômetro', () {
    final n = RideNarrator();
    expect(n.update(distance: 1002, movingTime: 180, lapDone: 1, lapTime: 180, ghostGapS: 9),
        ['Volta 1 concluída em 3 minutos. Você está 9 segundos à frente do fantasma.']);
    expect(n.update(distance: 1100, movingTime: 190), isEmpty);
  });

  test('na ida: metade e 200 metros do fim, uma vez cada', () {
    final n = RideNarrator(routeLength: 3000);
    expect(n.update(distance: 1499, movingTime: 300), ['1 quilômetro, em 5 minutos.']);
    expect(n.update(distance: 1501, movingTime: 301), ['Metade da rota.']);
    expect(n.update(distance: 2805, movingTime: 560), ['2 quilômetros, em 9 minutos e 20 segundos.', 'Faltam 200 metros!']);
    expect(n.update(distance: 2900, movingTime: 580), isEmpty);
  });

  test('passou o fantasma e o fantasma passou você, sem repetir', () {
    final n = RideNarrator();
    expect(n.update(distance: 50, movingTime: 10, ghostGapM: 5), isEmpty); // juntos
    expect(n.update(distance: 80, movingTime: 15, ghostGapM: 20), ['O fantasma passou você.']);
    expect(n.update(distance: 120, movingTime: 20, ghostGapM: 3), isEmpty);
    expect(n.update(distance: 160, movingTime: 25, ghostGapM: -16), ['Você passou o fantasma!']);
    expect(n.update(distance: 200, movingTime: 30, ghostGapM: -40), isEmpty);
  });

  test('frase do fim', () {
    final n = RideNarrator();
    expect(n.finished(completed: true, laps: 1, movingTime: 600, ghostGapS: 12),
        'Rota concluída em 10 minutos! Você venceu o fantasma por 12 segundos!');
    expect(n.finished(completed: false, laps: 3, movingTime: 900), 'Pedal encerrado: 3 voltas em 15 minutos.');
    expect(n.finished(completed: false, laps: 0, movingTime: 95, ghostGapS: -5),
        'Pedal encerrado: 1 minuto e 35 segundos. O fantasma ganhou por 5 segundos.');
  });
}
