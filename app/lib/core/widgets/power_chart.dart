import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Linha de potência ao longo do tempo (uma amostra por segundo).
class PowerChart extends StatelessWidget {
  const PowerChart({super.key, required this.values, this.color = AppColors.destaque});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gráfico de potência',
      child: CustomPaint(painter: _PowerPainter(values, color), child: const SizedBox.expand()),
    );
  }
}

class _PowerPainter extends CustomPainter {
  _PowerPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final maxV = math.max(100.0, values.reduce(math.max)) * 1.1;
    final dx = size.width / (values.length - 1);
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - (values[i] / maxV) * size.height;
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PowerPainter old) => old.values != values || old.color != color;
}
