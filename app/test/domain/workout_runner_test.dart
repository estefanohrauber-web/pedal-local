import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/workout.dart';
import 'package:pedal_local/domain/workout_runner.dart';

void main() {
  group('treino de intervalos', () {
    final w = workoutById('intervalos-5x1')!;

    test('começa no aquecimento e fala o trecho', () {
      final r = WorkoutRunner(w, ftp: 150);
      final f = r.update(0, power: 0, cadence: 0);
      expect(f.index, 0);
      expect(r.stepChanged, 0);
      expect(r.spoken.single, startsWith('Aquecendo. 5 minutos'));
      expect(f.total, 1200);
      r.update(1, power: 70, cadence: 80);
      expect(r.stepChanged, isNull);
      expect(r.spoken, isEmpty);
    });

    test('avisa 5 s antes do tiro e diz a meta quando ele começa', () {
      final r = WorkoutRunner(w, ftp: 150);
      r.update(0, power: 80, cadence: 85);
      r.update(296, power: 95, cadence: 85);
      expect(r.spoken, ['Em 5 segundos: 1 minuto muito forte.']);
      final f = r.update(300, power: 95, cadence: 85);
      expect(f.index, 1);
      expect(f.targetWatts, 158);
      expect(f.zone.number, 5);
      expect(r.stepChanged, 1);
      expect(r.spoken.single, 'Forte! 1 minuto muito forte, 158 watts, giro de 85 a 100.');
      expect(f.next!.from, 0.5);
    });

    test('na meta, abaixo e acima; e um toque só por trecho', () {
      final r = WorkoutRunner(w, ftp: 150);
      r.update(0, power: 80, cadence: 85);
      expect(r.update(305, power: 100, cadence: 90).compliance, Compliance.semAlvo); // tempo para ajustar
      expect(r.update(310, power: 160, cadence: 90).compliance, Compliance.naMeta);
      expect(r.update(311, power: 190, cadence: 90).compliance, Compliance.acima);
      final falas = <String>[];
      for (var t = 312; t <= 340; t++) {
        final f = r.update(t.toDouble(), power: 120, cadence: 90);
        expect(f.compliance, Compliance.abaixo);
        falas.addAll(r.spoken);
      }
      expect(falas, ['Aumente um pouco a carga ou o giro.']);
    });

    test('giro fora da faixa', () {
      final r = WorkoutRunner(w, ftp: 150);
      r.update(0, power: 80, cadence: 85);
      expect(r.update(312, power: 158, cadence: 70).cadenceHint, 'Gire mais rápido');
      expect(r.update(313, power: 158, cadence: 110).cadenceHint, 'Gire mais devagar');
      expect(r.update(314, power: 158, cadence: 92).cadenceHint, isNull);
    });

    test('a intensidade do plano muda as metas; no fim, terminado', () {
      final r = WorkoutRunner(w, ftp: 150, intensity: 1.1);
      expect(r.watts(1.0), 165);
      expect(r.update(1200, power: 60, cadence: 80).done, isTrue);
      expect(r.update(600, power: 60, cadence: 80).done, isFalse);
    });
  });

  group('teste de rampa', () {
    test('acompanha a rampa até cansar; o FTP é 75 % do melhor minuto e pula para soltar', () {
      final r = WorkoutRunner(rampTestWorkout, ftp: 150, intensity: 1.2);
      expect(r.intensity, 1); // o teste não usa o ajuste do plano
      final falas = <String>[];
      WorkoutFrame? f;
      // 5 min de aquecimento + 10 degraus seguindo o alvo, depois para de fazer força.
      for (var t = 0; t < 300 + 600 + 40 && !(f?.rampEnded ?? false); t++) {
        final double alvo = t < 300 ? 70.0 : r.watts(0.5 + 0.06 * ((t - 300) ~/ 60)).toDouble();
        final p = t < 900 ? alvo : 30.0;
        r.addSample(p);
        f = r.update(t.toDouble(), power: p, cadence: t < 900 ? 85 : 60);
        falas.addAll(r.spoken);
      }
      expect(f!.rampEnded, isTrue);
      // Melhor minuto: o último degrau completo (0,5 + 0,06 × 9 = 1,04 do FTP = 156 W).
      expect(f.rampFtp, (156 * 0.75).roundToDouble());
      expect(f.index, rampTestWorkout.steps.length - 1);
      expect(falas, contains(startsWith('Começou a rampa: 75 watts')));
      expect(falas, contains('Teste encerrado. Seu FTP é de 117 watts. Agora, 5 minutos leves para soltar as pernas.'));
      // Depois do pulo, o treino termina 5 min depois.
      final depois = r.update(950 + 300, power: 50, cadence: 80);
      expect(depois.done, isTrue);
    });

    test('“não aguento mais” logo no começo: sem FTP', () {
      final r = WorkoutRunner(rampTestWorkout, ftp: 150);
      for (var t = 0; t < 320; t++) {
        r.addSample(80);
        r.update(t.toDouble(), power: 80, cadence: 85);
      }
      r.endRamp();
      expect(r.rampEnded, isTrue);
      expect(r.rampFtp, isNull);
      expect(r.spoken.last, startsWith('Teste encerrado cedo demais'));
      expect(r.update(321, power: 50, cadence: 80).index, rampTestWorkout.steps.length - 1);
    });
  });

  group('pedal livre', () {
    const w = Workout(id: 'livre', name: 'Livre', summary: '', category: 'Meus treinos', steps: [
      WorkoutStep(10, 0.5),
      WorkoutStep(60, 0.5, free: true),
      WorkoutStep(60, 1.0),
    ]);

    test('sem meta e sem toque de fora da meta; a voz diz que é livre', () {
      final r = WorkoutRunner(w, ftp: 200);
      r.update(0, power: 100, cadence: 80);
      final f = r.update(10, power: 100, cadence: 80);
      expect(f.index, 1);
      expect(f.targetWatts, 0);
      expect(r.spoken.single, '1 minuto de pedal livre, no seu ritmo.');
      final falas = <String>[];
      for (var t = 11; t < 60; t++) {
        final g = r.update(t.toDouble(), power: 20, cadence: 40);
        expect(g.compliance, Compliance.semAlvo);
        expect(g.cadenceHint, isNull);
        falas.addAll(r.spoken);
      }
      expect(falas, isEmpty);
      expect(r.update(71, power: 200, cadence: 85).targetWatts, 200); // depois do livre, a meta volta
    });

    test('o próximo trecho livre não tem meta', () {
      final r = WorkoutRunner(w, ftp: 200);
      expect(r.update(0, power: 100, cadence: 80).nextWatts, isNull);
    });
  });

  group('ajustes durante o pedal', () {
    const w = Workout(id: 'aj', name: 'Ajustes', summary: '', category: 'Meus treinos', steps: [
      WorkoutStep(10, 0.5),
      WorkoutStep(10, 1.0, cue: 'Forte!'),
    ]);

    test('pular vai para o começo do próximo trecho; no último, termina', () {
      final r = WorkoutRunner(w, ftp: 200);
      r.update(2, power: 100, cadence: 80);
      expect(r.skipStep(), isTrue);
      expect(r.spoken, ['Pulando para o próximo bloco.']);
      final f = r.update(3, power: 100, cadence: 80);
      expect(f.index, 1);
      expect(f.inStep, closeTo(1, 1e-9));
      expect(r.spoken.single, startsWith('Forte!'));
      expect(r.skipStep(), isTrue);
      expect(r.update(4, power: 100, cadence: 80).done, isTrue);
      expect(r.skipStep(), isFalse); // já acabou
    });

    test('+1 min estica o trecho de agora, até 30 minutos a mais', () {
      final r = WorkoutRunner(w, ftp: 200);
      r.update(2, power: 100, cadence: 80);
      expect(r.extendStep(), isTrue);
      expect(r.spoken, ['Mais 1 minuto.']);
      expect(r.workout.seconds, 80);
      expect(r.workout.steps.first.seconds, 70);
      final f = r.update(3, power: 100, cadence: 80);
      expect(f.index, 0);
      expect(f.remaining, closeTo(67, 1e-9));
      expect(f.total, 80);
      for (var i = 1; i < 30; i++) {
        expect(r.extendStep(), isTrue);
      }
      expect(r.extendStep(), isFalse);
      expect(r.workout.steps.first.seconds, 10 + 30 * 60);
    });

    test('mais leve e mais forte: 5 % por toque, de −30 % a +30 %, nas metas daqui para a frente', () {
      final r = WorkoutRunner(w, ftp: 200);
      r.update(2, power: 100, cadence: 80);
      expect(r.nudge(1), isTrue);
      expect(r.spoken, ['Mais forte: 105 watts.']);
      var f = r.update(3, power: 100, cadence: 80);
      expect(f.targetWatts, 105);
      expect(f.adjustment, closeTo(0.05, 1e-9));
      expect(f.nextWatts, 210);
      r.nudge(-1);
      r.nudge(-1);
      expect(r.spoken.last, 'Mais leve: 95 watts.');
      expect(r.update(4, power: 100, cadence: 80).adjustment, closeTo(-0.05, 1e-9));
      for (var i = 0; i < 10; i++) {
        r.nudge(1);
      }
      expect(r.adjustment, closeTo(0.3, 1e-9));
      expect(r.nudge(1), isFalse);
      f = r.update(5, power: 100, cadence: 80);
      expect(f.targetWatts, 130);
    });

    test('no teste de rampa, nada disso', () {
      final r = WorkoutRunner(rampTestWorkout, ftp: 150);
      r.update(0, power: 60, cadence: 80);
      r.update(2, power: 60, cadence: 80);
      expect(r.skipStep(), isFalse);
      expect(r.extendStep(), isFalse);
      expect(r.nudge(1), isFalse);
      expect(r.spoken, isEmpty);
    });
  });
}
