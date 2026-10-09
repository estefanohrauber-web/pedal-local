import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Amarelo do “aqui”: a bolinha do pino na logo e o pingo do i no nome.
const logoAmarelo = Color(0xFFF6C445);

/// A rota da logo, num quadro de 200 × 200: passa por uma colina, sobe a segunda e, lá no
/// alto, vira o pino (“aqui”); depois segue em frente. Um traço só, sem trancos: sobe reto
/// pelo lado direito do pino, contorna a cabeça e desce reto pelo lado esquerdo, cruzando a
/// si mesmo na ponta do pino num X de linhas retas.
Path logoRoute() {
  // Os lados do pino são as retas que saem da ponta e tocam a cabeça (um círculo).
  const ponta = Offset(136, 96);
  final d = (ponta - logoPinCenter).distance;
  final abertura = math.asin(_raioDoPino / d); // ângulo de cada lado com a vertical
  final lado = math.sqrt(d * d - _raioDoPino * _raioDoPino);
  final paraDireita = Offset(math.sin(abertura), -math.cos(abertura)); // subindo
  final paraEsquerda = Offset(-math.sin(abertura), -math.cos(abertura));
  final toqueDireito = ponta + paraDireita * lado;
  final toqueEsquerdo = ponta + paraEsquerda * lado;
  // As retas continuam 16 abaixo da ponta, e as curvas chegam e saem na mesma direção.
  final chegada = ponta - paraDireita * 16;
  final saida = ponta - paraEsquerda * 16;
  final antesDaChegada = chegada - paraDireita * 10;
  final depoisDaSaida = saida - paraEsquerda * 10;
  return Path()
    ..moveTo(8, 150)
    ..cubicTo(30, 150, 40, 116, 62, 116)
    ..cubicTo(84, 116, 88, 136, 104, 136)
    ..cubicTo(114, 136, antesDaChegada.dx, antesDaChegada.dy, chegada.dx, chegada.dy)
    ..lineTo(toqueDireito.dx, toqueDireito.dy)
    ..arcToPoint(toqueEsquerdo, radius: const Radius.circular(_raioDoPino), largeArc: true, clockwise: false)
    ..lineTo(saida.dx, saida.dy)
    ..cubicTo(depoisDaSaida.dx, depoisDaSaida.dy, 170, 126, 192, 126);
}

/// Raio da cabeça do pino.
const _raioDoPino = 22.0;

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

/// Ponto mais à direita que a linha já alcançou, a cada 1 % do caminho.
final List<double> _maisADireita = () {
  final m = logoRoute().computeMetrics().first;
  var maior = 0.0;
  return [
    for (var i = 0; i <= 100; i++)
      maior = math.max(maior, m.getTangentForOffset(m.length * i / 100)!.position.dx),
  ];
}();

/// Quanto do nome aparece (0 a 1) com a rota desenhada até [progress]: acompanha o ponto
/// mais à direita que a ponta da linha já alcançou. No laço do pino, que volta para a
/// esquerda, o nome espera.
double logoRevealFraction(double progress) {
  final p = progress.clamp(0.0, 1.0) * 100;
  final i = p.floor();
  final j = math.min(i + 1, 100);
  final x = _maisADireita[i] + (_maisADireita[j] - _maisADireita[i]) * (p - i);
  return ((x - _maisADireita.first) / (_maisADireita.last - _maisADireita.first)).clamp(0.0, 1.0);
}

/// Desenha o símbolo centrado em [size]: a rota até [progress] e a bolinha do pino em
/// escala [dot] (0 a 1).
class LogoPainter extends CustomPainter {
  const LogoPainter({
    this.color = Colors.white,
    this.dotColor = logoAmarelo,
    this.progress = 1,
    this.dot = 1,
    this.ring = 0,
    this.strokeScale = 1,
  });

  final Color color;
  final Color dotColor;
  final double progress;
  final double dot;

  /// Anel que se espalha da bolinha (0 a 1), como o sinal de “você está aqui”; 0 = sem anel.
  final double ring;

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
    if (ring > 0 && ring < 1) {
      canvas.drawCircle(
        logoPinCenter,
        9 + 24 * ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - ring) + 0.5
          ..color = dotColor.withValues(alpha: 0.75 * (1 - ring)),
      );
    }
    if (dot > 0) {
      canvas.drawCircle(logoPinCenter, 9 * dot, Paint()..color = dotColor);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.progress != progress ||
      old.dot != dot ||
      old.ring != ring ||
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
    this.ring = 0,
  });

  final double size;
  final Color color;
  final double progress;
  final double dot;
  final double ring;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: LogoPainter(color: color, progress: progress, dot: dot, ring: ring),
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

/// “Pedalaqui” escrito, com o “aqui” na cor de destaque.
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
            text: 'aqui',
            style: TextStyle(color: accent),
          ),
        ],
      ),
      semanticsLabel: 'Pedalaqui',
    );
  }
}
