import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Amarelo do “aqui”: a bolinha do pino na logo e o pingo do i no nome.
const logoAmarelo = Color(0xFFF6C445);

/// A rota da logo, num quadro de 200 × 200: passa por uma colina, sobe a segunda e, lá no
/// alto, se enrola e vira o pino (“aqui”); depois segue em frente.
Path logoRoute() => Path()
  ..moveTo(8, 150)
  ..cubicTo(30, 150, 40, 116, 62, 116)
  ..cubicTo(84, 116, 88, 136, 104, 136)
  ..cubicTo(118, 136, 126, 110, 136, 96)
  ..cubicTo(128, 86, 114, 74, 114, 58)
  ..arcToPoint(
    const Offset(158, 58),
    radius: const Radius.circular(22),
    largeArc: true,
  )
  ..cubicTo(158, 74, 144, 86, 136, 96)
  ..cubicTo(146, 110, 160, 124, 192, 126);

/// Centro do pino, onde fica a bolinha amarela.
const logoPinCenter = Offset(136, 58);

/// Espessura da linha no quadro de 200.
const logoStroke = 12.0;

/// O começo do caminho, até a fração [t] do comprimento (para desenhar a rota aos poucos).
Path partialPath(Path path, double t) {
  final out = Path();
  final metrics = path.computeMetrics().toList();
  var falta =
      metrics.fold(0.0, (soma, m) => soma + m.length) * t.clamp(0.0, 1.0);
  for (final m in metrics) {
    if (falta <= 0) break;
    out.addPath(m.extractPath(0, math.min(falta, m.length)), Offset.zero);
    falta -= m.length;
  }
  return out;
}

/// Desenha o símbolo centrado em [size]: a rota até [progress] e a bolinha do pino em
/// escala [dot] (0 a 1).
class LogoPainter extends CustomPainter {
  const LogoPainter({
    this.color = Colors.white,
    this.dotColor = logoAmarelo,
    this.progress = 1,
    this.dot = 1,
    this.strokeScale = 1,
  });

  final Color color;
  final Color dotColor;
  final double progress;
  final double dot;

  /// Linha mais grossa em tamanhos pequenos (1 = a do desenho).
  final double strokeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 200;
    canvas.save();
    // O desenho fica um pouco acima do meio do quadro: desce 7 para centralizar.
    canvas.translate(
      (size.width - 200 * s) / 2,
      (size.height - 200 * s) / 2 + 7 * s,
    );
    canvas.scale(s);
    final linha = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = logoStroke * strokeScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      progress >= 1 ? logoRoute() : partialPath(logoRoute(), progress),
      linha,
    );
    if (dot > 0) {
      canvas.drawCircle(logoPinCenter, 9 * dot, Paint()..color = dotColor);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.progress != progress ||
      old.dot != dot ||
      old.color != color ||
      old.dotColor != dotColor;
}

/// O ícone do app: o símbolo num quadrado verde de cantos redondos ([size] de lado).
void paintAppIcon(
  Canvas canvas,
  double size, {
  bool rounded = true,
  double markFraction = 0.83,
}) {
  final fundo = Paint()..color = AppColors.destaque;
  final rect = Offset.zero & Size.square(size);
  if (rounded) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size * 0.227)),
      fundo,
    );
  } else {
    canvas.drawRect(rect, fundo);
  }
  final lado = size * markFraction;
  canvas.save();
  canvas.translate((size - lado) / 2, (size - lado) / 2);
  LogoPainter(strokeScale: size < 100 ? 1.25 : 1)
      .paint(canvas, Size.square(lado));
  canvas.restore();
}

/// O símbolo do Pedalaqui (a rota que vira o pino).
class PedalaquiMark extends StatelessWidget {
  const PedalaquiMark({
    super.key,
    required this.size,
    this.color = Colors.white,
    this.progress = 1,
    this.dot = 1,
  });

  final double size;
  final Color color;
  final double progress;
  final double dot;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: LogoPainter(color: color, progress: progress, dot: dot),
  );
}

/// O ícone do app, como aparece na tela do celular.
class PedalaquiIcon extends StatelessWidget {
  const PedalaquiIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.destaque,
      borderRadius: BorderRadius.circular(size * 0.227),
    ),
    child: PedalaquiMark(size: size * 0.83),
  );
}

/// “Pedalaqui” escrito, com um pininho amarelo no lugar do pingo do i.
class PedalaquiWordmark extends StatelessWidget {
  const PedalaquiWordmark({
    super.key,
    required this.fontSize,
    this.color = AppColors.texto,
    this.accent = AppColors.destaque,
    this.style,
  });

  final double fontSize;
  final Color color;

  /// Fonte do nome (brandTextStyleProvider); null = a do tema.
  final TextStyle? style;

  /// Cor do “aqui”.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final estilo =
        (style ??
                Theme.of(context).textTheme.headlineMedium ??
                const TextStyle())
            .copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.02 * fontSize,
              height: 1,
              color: color,
            );
    return Text.rich(
      TextSpan(
        style: estilo,
        children: [
          const TextSpan(text: 'Pedal'),
          TextSpan(
            text: 'aqu',
            style: TextStyle(color: accent),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Text('ı', style: estilo.copyWith(color: accent)), // i sem pingo
                Positioned(
                  top: -0.16 * fontSize,
                  child: CustomPaint(
                    size: Size(0.3 * fontSize, 0.39 * fontSize),
                    painter: const _PinoPainter(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      semanticsLabel: 'Pedalaqui',
    );
  }
}

/// O pininho do pingo do i.
class _PinoPainter extends CustomPainter {
  const _PinoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    final pino = Path()
      ..moveTo(r, h)
      ..cubicTo(r * 0.7, h * 0.85, 0, h * 0.62, 0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r), largeArc: true)
      ..cubicTo(w, h * 0.62, r * 1.3, h * 0.85, r, h)
      ..close();
    canvas.drawPath(pino, Paint()..color = logoAmarelo);
  }

  @override
  bool shouldRepaint(_PinoPainter old) => false;
}
