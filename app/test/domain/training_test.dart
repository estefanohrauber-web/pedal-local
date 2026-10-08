import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/training.dart';
import 'package:pedal_local/domain/workout.dart';

import '../support/geo_helpers.dart';

void main() {
  group('zonas e FTP', () {
    test('cada fração cai na sua zona', () {
      expect(zoneFor(0.3).number, 1);
      expect(zoneFor(0.55).number, 2);
      expect(zoneFor(0.62).number, 2);
      expect(zoneFor(0.9).number, 4);
      expect(zoneFor(1.05).number, 5);
      expect(zoneFor(1.7).number, 7);
      expect(zoneFor(1.05).effort, 'Muito forte');
    });

    test('FTP de partida é 2 W por kg', () {
      expect(defaultFtp(75), 150);
    });

    test('melhor média de 60 s e o FTP do teste de rampa', () {
      final potencias = [for (var i = 0; i < 300; i++) 100.0 + i]; // sobe 1 W por segundo
      expectNear(bestAverage(potencias, 60), 100 + (240 + 299) / 2, 1e-9);
      expect(rampTestFtp(potencias), ((100 + 269.5) * 0.75).roundToDouble());
      expect(bestAverage([1, 2], 60), 0);
    });
  });

  group('treinos', () {
    test('todos os treinos da biblioteca têm id único, trechos e categoria conhecida', () {
      final ids = workoutLibrary.map((w) => w.id).toSet();
      expect(ids.length, workoutLibrary.length);
      for (final w in workoutLibrary) {
        expect(w.steps, isNotEmpty, reason: w.id);
        expect(w.rampTest || workoutCategories.contains(w.category), isTrue, reason: w.id);
      }
    });

    test('as durações batem com o que a tela promete', () {
      int min(String id) => workoutById(id)!.seconds ~/ 60;
      expect(min('intervalos-5x1'), 20);
      expect(min('cadencia-alta'), 15);
      expect(min('subida-longa'), 30);
      expect(min('primeiro-giro'), 20);
      expect(min('resistencia-40'), 40);
      expect(min('tabata'), 16);
    });

    test('posição no treino: trecho, tempo dentro dele e quanto falta', () {
      final w = workoutById('intervalos-5x1')!;
      final p = w.at(330); // 5 min de aquecimento + 30 s do primeiro tiro
      expect(p.index, 1);
      expectNear(p.inStep, 30, 1e-9);
      expectNear(p.remaining, 30, 1e-9);
      expect(w.steps[p.index].from, 1.05);
      final fim = w.at(5000);
      expect(fim.index, w.steps.length - 1);
      expect(fim.remaining, 0);
    });

    test('rampa dentro do trecho e intensidade do treino', () {
      const aquecer = WorkoutStep(300, 0.4, to: 0.6);
      expectNear(aquecer.fractionAt(150), 0.5, 1e-9);
      expect(workoutById('recuperacao')!.level, 'Leve');
      expect(workoutById('tabata')!.peakZone.number, 7);
      expect(workoutById('sweet-spot-2x10')!.intensity, greaterThan(workoutById('resistencia-30')!.intensity));
    });

    test('teste de rampa sobe 6 % do FTP por minuto', () {
      final t = rampTestWorkout;
      expect(t.rampTest, isTrue);
      expectNear(t.steps[1].from, 0.5, 1e-9);
      expectNear(t.steps[2].from - t.steps[1].from, 0.06, 1e-9);
      expect(t.steps[1].seconds, 60);
    });
  });
}
