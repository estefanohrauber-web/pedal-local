import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/calendario.dart';
import 'package:pedal_local/domain/stats.dart';

RideStat pedal(DateTime quando, double km) => RideStat(
  startedAt: quando,
  distanceM: km * 1000,
  movingTimeS: 600,
  gainM: 0,
);

void main() {
  test('km de cada dia do mês (outros meses ficam de fora)', () {
    final km = kmPorDia(
      [
        pedal(DateTime(2026, 10, 5, 8), 2),
        pedal(DateTime(2026, 10, 5, 20), 1.5),
        pedal(DateTime(2026, 10, 8, 19), 9.6),
        pedal(DateTime(2026, 9, 30, 20), 5),
      ],
      ano: 2026,
      mes: 10,
    );
    expect(km, {5: 3.5, 8: 9.6});
  });

  test(
    'tom do dia: 0 sem pedal; 1, 2 e 3 conforme os km perto do maior do mês',
    () {
      expect(tomDoDia(0, 10), 0);
      expect(tomDoDia(2, 10), 1);
      expect(tomDoDia(5, 10), 2);
      expect(tomDoDia(10, 10), 3);
      expect(tomDoDia(0.4, 0.4), 3);
    },
  );

  test('dias seguidos até hoje (ou até ontem, se ainda não pedalou hoje)', () {
    final hoje = DateTime(2026, 10, 11, 9);
    expect(diasSeguidos([], hoje), 0);
    expect(
      diasSeguidos([
        pedal(DateTime(2026, 10, 10, 20), 3),
        pedal(DateTime(2026, 10, 9, 20), 3),
      ], hoje),
      2,
    );
    expect(
      diasSeguidos([
        pedal(DateTime(2026, 10, 11, 7), 3),
        pedal(DateTime(2026, 10, 10, 20), 3),
        pedal(DateTime(2026, 10, 8, 20), 3),
      ], hoje),
      2,
    );
    expect(diasSeguidos([pedal(DateTime(2026, 10, 8, 20), 3)], hoje), 0);
  });

  test(
    'grade do mês começando na segunda: outubro de 2026 começa numa quinta',
    () {
      final grade = gradeDoMes(2026, 10);
      expect(grade.take(3), [null, null, null]);
      expect(grade[3], DateTime(2026, 10, 1));
      expect(grade.whereType<DateTime>().length, 31);
      expect(grade.length % 7, 0);
    },
  );

  test('nomes em português', () {
    expect(nomeDoMes(2026, 10), 'Outubro 2026');
    expect(nomeDoDia(DateTime(2026, 10, 10)), 'Sábado, 10 de outubro');
    expect(nomeDoDia(DateTime(2026, 10, 5)), 'Segunda, 5 de outubro');
  });
}
