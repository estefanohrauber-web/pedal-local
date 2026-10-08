import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/training_plans.dart';
import 'package:pedal_local/domain/workout.dart';

void main() {
  test('todos os treinos dos planos existem na biblioteca', () {
    for (final p in trainingPlans) {
      for (final id in p.sessions) {
        expect(workoutById(id), isNotNull, reason: '${p.id}: $id');
      }
    }
    expect(planById('comecando')!.weeks.length, 4);
    expect(planById('nada'), isNull);
  });

  group('progresso', () {
    final plano = planById('comecando')!;
    final inicio = DateTime(2026, 10, 1);

    test('cada treino feito depois do início marca uma sessão; o resto fica aberto', () {
      final p = planProgress(plano, inicio, [
        DoneWorkout('primeiro-giro', DateTime(2026, 10, 2)),
        DoneWorkout('primeiro-giro', DateTime(2026, 9, 20)), // antes do plano: não conta
        DoneWorkout('primeiro-giro', DateTime(2026, 10, 4)),
      ]);
      expect(p.done.take(3), [true, false, true]);
      expect(p.doneCount, 2);
      expect(p.nextIndex, 1);
      expect(p.nextWorkoutId, 'cadencia-alta');
      expect(p.week, 0);
      expect(p.doneInWeek(0), 2);
      expect(p.finished, isFalse);
    });

    test('fora de ordem também conta, e a semana avança', () {
      final feitos = [
        for (final id in ['cadencia-alta', 'primeiro-giro', 'primeiro-giro', 'recuperacao'])
          DoneWorkout(id, DateTime(2026, 10, 3)),
      ];
      final p = planProgress(plano, inicio, feitos);
      expect(p.week, 1);
      expect(p.nextWorkoutId, 'intervalos-5x1');
      expect(p.doneInWeek(1), 1);
    });

    test('plano terminado', () {
      final p = planProgress(plano, inicio, [for (final id in plano.sessions) DoneWorkout(id, DateTime(2026, 10, 5))]);
      expect(p.finished, isTrue);
      expect(p.nextIndex, isNull);
      expect(p.week, 3);
    });
  });

  test('a resposta “como foi?” ajusta a intensidade, dentro dos limites', () {
    expect(adjustIntensity(1, Feeling.facil), 1.03);
    expect(adjustIntensity(1, Feeling.muitoDificil), 0.97);
    expect(adjustIntensity(1.14, Feeling.facil), maxIntensity);
    expect(adjustIntensity(0.87, Feeling.naoTerminei), minIntensity);
    expect(adjustIntensity(1, Feeling.dificil), 1);
  });
}
