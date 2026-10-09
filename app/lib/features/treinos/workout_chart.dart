import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/training.dart';
import '../../domain/workout.dart';

/// O desenho do treino: um bloco por trecho, a altura é o esforço e a cor é a zona (o pedal
/// livre é cinza claro). Com [elapsed], o que já passou fica apagado e uma linha marca o agora.
class WorkoutChart extends StatelessWidget {
  const WorkoutChart({super.key, required this.workout, this.elapsed, this.height = 64});

  final Workout workout;
  final double? elapsed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WorkoutPainter(workout, elapsed)),
    );
  }
}

class _WorkoutPainter extends CustomPainter {
  _WorkoutPainter(this.workout, this.elapsed);

  final Workout workout;
  final double? elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final total = workout.seconds.toDouble();
    if (total <= 0) return;
    final topo = math.max(1.2, workout.steps.map((s) => math.max(s.from, s.to)).reduce(math.max));
    double x(double t) => t / total * size.width;
    double y(double f) => size.height - (f / topo).clamp(0.04, 1.0) * size.height;
    var t = 0.0;
    for (final s in workout.steps) {
      final cor = zoneColor(s.free ? 1 : zoneFor(s.mid).number);
      final forca = s.free ? 0.4 : 0.9;
      final passou = elapsed != null && t + s.seconds <= elapsed!;
      final caminho = Path()
        ..moveTo(x(t), size.height)
        ..lineTo(x(t), y(s.from))
        ..lineTo(x(t + s.seconds), y(s.to))
        ..lineTo(x(t + s.seconds), size.height)
        ..close();
      canvas.drawPath(caminho, Paint()..color = cor.withValues(alpha: passou ? forca * 0.4 : forca));
      t += s.seconds;
    }
    final agora = elapsed;
    if (agora != null) {
      final px = x(agora.clamp(0, total).toDouble());
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = AppColors.texto
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_WorkoutPainter old) => old.workout != workout || old.elapsed != elapsed;
}
