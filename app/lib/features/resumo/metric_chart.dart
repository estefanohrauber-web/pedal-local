import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show Polyline;
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/theme/app_theme.dart';
import '../../domain/ride_analysis.dart';

/// Linha do caminho pintada pela métrica: cada trecho com a cor do seu valor.
/// Trechos vizinhos da mesma faixa de cor viram uma linha só.
List<Polyline> heatPolylines(List<LatLng> pontos, List<double> valores, double lo, double hi, {double largura = 5}) {
  const faixas = 24;
  final linhas = <Polyline>[];
  var atual = <LatLng>[];
  int? faixaAtual;
  void fecha() {
    if (atual.length >= 2 && faixaAtual != null) {
      linhas.add(Polyline(points: atual, strokeWidth: largura, color: heatColor(faixaAtual / (faixas - 1))));
    }
  }

  for (var i = 1; i < pontos.length && i < valores.length; i++) {
    final f = (normalize(valores[i], lo, hi) * (faixas - 1)).round();
    if (f != faixaAtual) {
      fecha();
      atual = [pontos[i - 1]];
      faixaAtual = f;
    }
    atual.add(pontos[i]);
  }
  fecha();
  return linhas;
}

/// Gráfico da métrica pela distância, com a mesma escala de cores do mapa.
/// Tocar ou arrastar marca um ponto ([onScrub] recebe a distância).
class MetricChart extends StatelessWidget {
  const MetricChart({
    super.key,
    required this.xs,
    required this.ys,
    required this.lo,
    required this.hi,
    required this.length,
    this.scrub,
    this.onScrub,
  });

  final List<double> xs;
  final List<double> ys;
  final double lo;
  final double hi;
  final double length;
  final double? scrub;
  final ValueChanged<double>? onScrub;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        void marca(double dx) => onScrub?.call((dx / box.maxWidth).clamp(0.0, 1.0) * length);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => marca(d.localPosition.dx),
          onHorizontalDragStart: (d) => marca(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => marca(d.localPosition.dx),
          child: CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: _Pintor(xs, ys, lo, hi, length, scrub),
          ),
        );
      },
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor(this.xs, this.ys, this.lo, this.hi, this.length, this.scrub);

  final List<double> xs;
  final List<double> ys;
  final double lo;
  final double hi;
  final double length;
  final double? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    if (xs.length < 2 || length <= 0) return;
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    if (maxY - minY < 1e-6) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;
    Offset p(int i) => Offset(
          xs[i] / length * size.width,
          size.height - (ys[i] - minY) / (maxY - minY) * size.height,
        );

    final area = Path()..moveTo(p(0).dx, size.height);
    for (var i = 0; i < xs.length; i++) {
      area.lineTo(p(i).dx, p(i).dy);
    }
    area
      ..lineTo(p(xs.length - 1).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = AppColors.neutro);

    final traco = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < xs.length; i++) {
      traco.color = heatColor(normalize(ys[i], lo, hi));
      canvas.drawLine(p(i - 1), p(i), traco);
    }

    final s = scrub;
    if (s != null) {
      final x = (s / length).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = AppColors.texto
          ..strokeWidth = 1.2,
      );
      var i = 0;
      while (i < xs.length - 1 && xs[i] < s) {
        i++;
      }
      canvas.drawCircle(p(i), 5, Paint()..color = Colors.white);
      canvas.drawCircle(p(i), 3.5, Paint()..color = AppColors.texto);
    }
  }

  @override
  bool shouldRepaint(_Pintor old) =>
      old.xs != xs || old.ys != ys || old.scrub != scrub || old.lo != lo || old.hi != hi || old.length != length;
}
