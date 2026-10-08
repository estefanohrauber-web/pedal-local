import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/stats.dart';

RideStat pedal(DateTime quando, {double km = 10, double min = 30, double subida = 100}) =>
    RideStat(startedAt: quando, distanceM: km * 1000, movingTimeS: min * 60, gainM: subida);

void main() {
  // quinta-feira, 8 de outubro de 2026
  final agora = DateTime(2026, 10, 8, 20);

  test('a semana começa na segunda à meia-noite', () {
    expect(weekStart(agora), DateTime(2026, 10, 5));
    expect(weekStart(DateTime(2026, 10, 5, 0, 1)), DateTime(2026, 10, 5));
    expect(weekStart(DateTime(2026, 10, 11, 23)), DateTime(2026, 10, 5));
    expect(weekStart(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
  });

  test('resumo da semana só conta a semana atual', () {
    final s = summarize(
      [
        pedal(DateTime(2026, 10, 8, 9), km: 9.6, min: 20, subida: 341),
        pedal(DateTime(2026, 10, 5, 7), km: 3.2, min: 6, subida: 81),
        pedal(DateTime(2026, 10, 4, 18), km: 50),
      ],
      from: weekStart(agora),
    );
    expect(s.count, 2);
    expect(s.distanceM, closeTo(12800, 1e-6));
    expect(s.movingTimeS, 26 * 60);
    expect(s.gainM, 422);
  });

  test('totais desde o começo', () {
    final t = summarize([pedal(DateTime(2026, 1, 1)), pedal(agora)]);
    expect(t.count, 2);
    expect(t.distanceM, 20000);
  });

  test('histórico agrupado por semana, com nomes amigáveis', () {
    final grupos = groupByWeek(
      [
        pedal(DateTime(2026, 10, 8, 9)),
        pedal(DateTime(2026, 10, 6, 9)),
        pedal(DateTime(2026, 10, 1, 9)),
        pedal(DateTime(2026, 9, 22, 9)),
      ],
      now: agora,
    );
    expect(grupos.map((g) => g.label), ['Esta semana', 'Semana passada', 'Semana de 21/09']);
    expect(grupos.map((g) => g.items.length), [2, 1, 1]);
    expect(grupos.first.distanceM, 20000);
  });

  test('comparação com montanhas', () {
    expect(mountainText(0), isNull);
    expect(mountainText(1446), '50% do Pico da Bandeira (2.892 m)');
    expect(mountainText(2966), '99% do Pico da Neblina (2.995 m)');
    expect(mountainText(5784), '2 vezes o Pico da Bandeira (2.892 m)');
    expect(mountainText(8985), '3 vezes o Pico da Neblina (2.995 m)');
  });
}
