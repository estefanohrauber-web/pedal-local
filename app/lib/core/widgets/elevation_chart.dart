import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/route_profile.dart';
import '../theme/app_theme.dart';

/// Perfil de relevo da rota, com marcador opcional na distância percorrida.
class ElevationChart extends StatelessWidget {
  const ElevationChart({super.key, required this.profile, this.marker});

  final RouteProfile profile;
  final double? marker;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Perfil de relevo da rota',
      child: CustomPaint(painter: _ElevationPainter(profile, marker), child: const SizedBox.expand()),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.profile, this.marker);

  final RouteProfile profile;
  final double? marker;

  @override
  void paint(Canvas canvas, Size size) {
    final alts = profile.alts;
    final cum = profile.cum;
    final distance = profile.distance;
    if (alts.length < 2 || distance <= 0 || size.isEmpty) return;

    final altMin = alts.reduce(math.min);
    final altMax = alts.reduce(math.max);
    // Pelo menos 10 m de escala, para não exagerar ruas quase planas.
    final meio = (altMin + altMax) / 2;
    final minimo = math.min(altMin, meio - 5);
    final maximo = math.max(altMax, meio + 5);
    const topo = 6.0;
    final base = size.height - 16;
    double x(double d) => d / distance * size.width;
    double y(double a) => topo + (1 - (a - minimo) / (maximo - minimo)) * (base - topo);

    final linha = Path()..moveTo(x(cum[0]), y(alts[0]));
    for (var i = 1; i < alts.length; i++) {
      linha.lineTo(x(cum[i]), y(alts[i]));
    }
    final area = Path.from(linha)
      ..lineTo(size.width, base)
      ..lineTo(0, base)
      ..close();
    canvas.drawPath(area, Paint()..color = AppColors.destaque.withValues(alpha: 0.18));
    canvas.drawPath(
      linha,
      Paint()
        ..color = AppColors.destaque
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final rotulo = TextPainter(
      text: TextSpan(
        text: '${altMin.round()}–${altMax.round()} m',
        style: const TextStyle(fontSize: 11, color: AppColors.textoSuave),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rotulo.paint(canvas, Offset(2, size.height - rotulo.height));

    final m = marker;
    if (m != null) {
      final d = m.clamp(0, distance).toDouble();
      final mx = x(d);
      canvas.drawLine(Offset(mx, topo), Offset(mx, base), Paint()..color = AppColors.texto..strokeWidth = 1);
      canvas.drawCircle(Offset(mx, y(profile.elevationAt(d))), 6, Paint()..color = AppColors.posicao);
      canvas.drawCircle(
        Offset(mx, y(profile.elevationAt(d))),
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.profile != profile || old.marker != marker;
}
