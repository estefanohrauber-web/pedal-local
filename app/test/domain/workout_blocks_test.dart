import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/workout.dart';
import 'package:pedal_local/domain/workout_blocks.dart';

/// O que aparece no desenho e na pedalada de um trecho (as frases podem mudar na cópia).
List<Object?> _forma(WorkoutStep s) => [s.seconds, s.from, s.to, s.grade, s.cadenceMin, s.cadenceMax, s.free];

CustomWorkout _treino(List<WorkoutBlock> blocos) => CustomWorkout(
  id: 'meu-teste',
  name: 'Tiros de terça',
  blocks: blocos,
  createdAt: DateTime(2026, 10, 9, 18),
  updatedAt: DateTime(2026, 10, 9, 19),
);

void main() {
  group('blocos viram trechos', () {
    test('aquecer, ritmo, rampa e soltar: um trecho, com a rampa nos que sobem ou descem', () {
      final aquecer = WorkoutBlock.novo(BlockKind.aquecer).toSteps().single;
      expect(_forma(aquecer), [600, 0.45, 0.65, 0.0, null, null, false]);
      final ritmo = WorkoutBlock.novo(BlockKind.ritmo).toSteps().single;
      expect(_forma(ritmo), [600, 0.70, 0.70, 0.0, null, null, false]);
      final rampa = WorkoutBlock.novo(BlockKind.rampa).toSteps().single;
      expect(_forma(rampa), [300, 0.60, 0.90, 0.0, null, null, false]);
      final soltar = WorkoutBlock.novo(BlockKind.soltar).toSteps().single;
      expect(_forma(soltar), [300, 0.55, 0.40, 0.0, null, null, false]);
    });

    test('subida: inclinação e giro; pedal livre: trecho sem meta a 50 %', () {
      final subida = WorkoutBlock.novo(BlockKind.subida).toSteps().single;
      expect(_forma(subida), [300, 0.85, 0.85, 0.06, 70, 85, false]);
      final livre = WorkoutBlock.novo(BlockKind.livre).toSteps().single;
      expect(_forma(livre), [300, 0.5, 0.5, 0.0, null, null, true]);
    });

    test('série: tiro e descanso repetidos, e a voz conta os tiros', () {
      final serie = WorkoutBlock.novo(BlockKind.serie);
      expect(serie.totalSeconds, 4 * 120);
      final trechos = serie.toSteps();
      expect(trechos.length, 8);
      expect(_forma(trechos[0]), [60, 1.10, 1.10, 0.0, null, null, false]);
      expect(_forma(trechos[1]), [60, 0.5, 0.5, 0.0, null, null, false]);
      expect(
        [for (final t in trechos) t.cue],
        ['Tiro 1 de 4', 'Recupere', 'Tiro 2 de 4', 'Recupere', 'Tiro 3 de 4', 'Recupere', 'Tiro 4 de 4', 'Recupere'],
      );
      final comFrase = serie.copyWith(cue: 'Vai!', reps: 2, cadenceMin: 90, cadenceMax: 100).toSteps();
      expect(comFrase.map((t) => t.cue), ['Tiro 1 de 2. Vai!', 'Recupere', 'Tiro 2 de 2. Vai!', 'Recupere']);
      expect(comFrase.first.cadenceMin, 90);
      expect(comFrase[1].hasCadence, isFalse);
    });

    test('copyWith: num bloco sem rampa o fim acompanha o começo; giro e frase podem ser apagados', () {
      final ritmo = WorkoutBlock.novo(BlockKind.ritmo).copyWith(from: 0.97);
      expect(ritmo.to, 0.97);
      final aquecer = WorkoutBlock.novo(BlockKind.aquecer).copyWith(from: 0.5);
      expect(aquecer.to, 0.65);
      final subida = WorkoutBlock.novo(BlockKind.subida).copyWith(cue: 'Força!');
      final semNada = subida.copyWith(cadenceMin: null, cadenceMax: null, cue: null);
      expect(semNada.cadenceMin, isNull);
      expect(semNada.cue, isNull);
      expect(semNada.grade, 0.06);
    });
  });

  group('treino do usuário', () {
    test('vira um treino com os números de sempre, na categoria Meus treinos', () {
      final w = _treino([
        WorkoutBlock.novo(BlockKind.aquecer),
        WorkoutBlock.novo(BlockKind.serie),
        WorkoutBlock.novo(BlockKind.soltar),
      ]).toWorkout();
      expect(w.id, 'meu-teste');
      expect(w.name, 'Tiros de terça');
      expect(w.category, customWorkoutCategory);
      expect(w.seconds, 600 + 480 + 300);
      expect(w.steps.length, 10);
      expect(w.level, isNotEmpty);
      expect(w.stress, greaterThan(0));
      expect(w.rampTest, isFalse);
    });

    test('pedal livre conta como muito leve (50 %) na intensidade', () {
      final w = _treino([WorkoutBlock.novo(BlockKind.livre)]).toWorkout();
      expect(w.intensity, closeTo(0.5, 1e-9));
    });

    test('guarda e lê do banco sem perder nada', () {
      final original = _treino([
        WorkoutBlock.novo(BlockKind.aquecer).copyWith(cue: 'Aquecendo devagar'),
        WorkoutBlock.novo(BlockKind.serie).copyWith(reps: 6, seconds: 45, restSeconds: 75, restFraction: 0.45),
        WorkoutBlock.novo(BlockKind.subida).copyWith(grade: 0.08),
        WorkoutBlock.novo(BlockKind.livre),
      ]);
      final lido = CustomWorkout.fromRow(original.toRow());
      expect(lido.id, original.id);
      expect(lido.name, original.name);
      expect(lido.createdAt, original.createdAt);
      expect(lido.updatedAt, original.updatedAt);
      expect([for (final b in lido.blocks) b.toJson()], [for (final b in original.blocks) b.toJson()]);
      expect(lido.toWorkout().steps.map(_forma), original.toWorkout().steps.map(_forma));
    });

    test('id dos treinos do usuário', () {
      final id = newCustomWorkoutId(DateTime(2026, 10, 9), _SorteioFixo());
      expect(isCustomWorkoutId(id), isTrue);
      expect(isCustomWorkoutId('intervalos-5x1'), isFalse);
      expect(newCustomWorkoutId(DateTime(2026, 10, 9, 0, 0, 1), _SorteioFixo()), isNot(id));
    });
  });

  group('copiar um treino pronto', () {
    test('toda a biblioteca vira blocos com o mesmo desenho', () {
      for (final w in workoutLibrary.where((w) => !w.rampTest)) {
        final copia = _treino(blocksFromSteps(w.steps)).toWorkout();
        expect(copia.steps.map(_forma), w.steps.map(_forma), reason: w.id);
      }
    });

    test('reconhece aquecer, série, subida e soltar', () {
      final intervalos = blocksFromSteps(workoutById('intervalos-5x1')!.steps);
      expect(intervalos.map((b) => b.kind), [BlockKind.aquecer, BlockKind.serie, BlockKind.soltar]);
      expect(intervalos[1].reps, 5);
      expect(intervalos[1].cue, 'Forte!');
      final subida = blocksFromSteps(workoutById('subida-longa')!.steps);
      expect(subida.map((b) => b.kind), [
        BlockKind.aquecer,
        BlockKind.subida,
        BlockKind.subida,
        BlockKind.subida,
        BlockKind.subida,
        BlockKind.subida,
        BlockKind.soltar,
      ]);
      // O descanso com giro próprio (Cadência alta) não vira série: cada trecho fica um bloco.
      final cadencia = blocksFromSteps(workoutById('cadencia-alta')!.steps);
      expect(cadencia.where((b) => b.kind == BlockKind.serie), isEmpty);
    });
  });

  group('limites e ajudas do editor', () {
    test('tempo: passo de 15 s até 2 min, 30 s até 10 min e 1 min acima, dentro dos limites', () {
      expect(moreTime(60), 75);
      expect(moreTime(120), 150);
      expect(moreTime(600), 660);
      expect(lessTime(120), 105);
      expect(lessTime(600), 570);
      expect(lessTime(15), minBlockSeconds);
      expect(moreTime(maxBlockSeconds), maxBlockSeconds);
    });

    test('intensidade em 1 % e dentro de 30 % a 200 %', () {
      expect(clampFraction(1.104), 1.10);
      expect(clampFraction(0.1), minFraction);
      expect(clampFraction(2.5), maxFraction);
      expect(zoneTargets.length, 7);
    });

    test('o que impede salvar; nome padrão e limite do nome', () {
      expect(workoutProblem(const []), 'Coloque pelo menos um bloco.');
      expect(workoutProblem([WorkoutBlock.novo(BlockKind.ritmo)]), isNull);
      final longo = [for (var i = 0; i < 3; i++) WorkoutBlock.novo(BlockKind.ritmo).copyWith(seconds: maxBlockSeconds)];
      expect(workoutProblem(longo), 'O treino passou de 4 horas. Encurte algum bloco.');
      expect(workoutNameOrDefault('   '), 'Meu treino');
      expect(workoutNameOrDefault('  Tiros  '), 'Tiros');
      expect(workoutNameOrDefault('x' * 60).length, maxWorkoutName);
    });

    test('bloco novo entra antes do Soltar; mudar de lugar para a posição final', () {
      final a = WorkoutBlock.novo(BlockKind.aquecer);
      final s = WorkoutBlock.novo(BlockKind.soltar);
      final r = WorkoutBlock.novo(BlockKind.ritmo);
      expect(insertIndex([a, s]), 1);
      expect(insertIndex([a, r]), 2);
      expect(insertIndex(const []), 0);
      expect(moveBlock([a, r, s], 0, 1), [r, a, s]);
      expect(moveBlock([a, r, s], 2, 0), [s, a, r]);
    });

    test('resumo em palavras com os watts', () {
      int watts(double f) => (200 * f).round();
      expect(describeBlock(WorkoutBlock.novo(BlockKind.serie), watts), '1 min muito forte (220\u00a0W) + 1 min muito leve');
      expect(describeBlock(WorkoutBlock.novo(BlockKind.aquecer), watts), 'Muito leve subindo para leve (90\u00a0→\u00a0130\u00a0W)');
      expect(describeBlock(WorkoutBlock.novo(BlockKind.soltar), watts), 'Leve descendo para muito leve (110\u00a0→\u00a080\u00a0W)');
      expect(describeBlock(WorkoutBlock.novo(BlockKind.ritmo), watts), 'Leve (140\u00a0W)');
      expect(describeBlock(WorkoutBlock.novo(BlockKind.subida), watts), 'Moderado (170\u00a0W), 6\u00a0%, giro 70–85');
      expect(describeBlock(WorkoutBlock.novo(BlockKind.livre), watts), 'Sem meta, no seu ritmo');
      expect(
        describeBlock(WorkoutBlock.novo(BlockKind.serie).copyWith(seconds: 90), watts),
        startsWith('1 min 30 s muito forte'),
      );
      expect(blockHeading(WorkoutBlock.novo(BlockKind.serie)), 'Série de tiros · 4 ×');
      expect(blockHeading(WorkoutBlock.novo(BlockKind.subida)), 'Subida simulada');
    });
  });
}

/// Sorteio previsível para o id.
class _SorteioFixo implements Random {
  @override
  int nextInt(int max) => 7;
  @override
  double nextDouble() => 0.5;
  @override
  bool nextBool() => true;
}
