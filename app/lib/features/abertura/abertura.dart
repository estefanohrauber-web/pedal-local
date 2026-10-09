import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pedalaqui_logo.dart';

/// Chave da camada da abertura (para os testes).
const aberturaKey = ValueKey('abertura');

const _duracao = Duration(milliseconds: 2100);

/// Abertura do app, por cima dele, no fundo verde (o mesmo da tela de carregamento do
/// Android): a rota da logo se desenha da esquerda para a direita e dá a volta no pino,
/// com o nome se revelando junto; com o caminho pronto, a bolinha amarela aparece no pino
/// e o pininho cai no i; depois tudo some. Um toque pula.
class Abertura extends StatefulWidget {
  const Abertura({super.key, required this.child, this.nameStyle});

  final Widget child;

  /// Fonte do nome (veja brandTextStyleProvider).
  final TextStyle? nameStyle;

  @override
  State<Abertura> createState() => _AberturaState();
}

class _AberturaState extends State<Abertura> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _duracao);
  bool _acabou = false;

  // Fases, em fração dos 2,1 s: a linha (e o nome) de 0,08 s a 1,13 s; a bolinha de 1,15 s
  // a 1,43 s; o pininho do i logo atrás; tudo inteiro até 1,83 s; some até 2,1 s.
  static const _linha = Interval(0.04, 0.54, curve: Curves.easeInOutSine);
  static const _bolinha = Interval(0.55, 0.68, curve: Curves.easeOutBack);
  static const _pininho = Interval(0.57, 0.72, curve: Curves.easeOutBack);
  static const _some = Interval(0.87, 1, curve: Curves.easeIn);

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _acabou = true);
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pular() {
    if (_c.value < _some.begin) _c.forward(from: _some.begin);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final linha = _linha.transform(t);
        return Stack(
          children: [
            // O app por baixo só é montado com o caminho pronto: montar as telas pesa, e
            // a linha se desenharia aos trancos.
            if (t >= _linha.end || _acabou) widget.child,
            if (!_acabou)
              Positioned.fill(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
                  child: GestureDetector(
                    key: aberturaKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: _pular,
                    child: Opacity(
                      opacity: 1 - _some.transform(t),
                      // Material (e não só uma cor): a abertura fica acima das telas, e o
                      // texto precisa dele para ter estilo (sem ele, sai sublinhado de amarelo).
                      child: Material(
                        color: AppColors.destaque,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PedalaquiMark(size: 168, progress: linha, dot: _bolinha.transform(t)),
                              const SizedBox(height: 6),
                              RevealMask(
                                fraction: logoRevealFraction(linha),
                                // Folga em volta: a perninha do q e o pininho do i saem da
                                // caixa do texto, e o que fica fora da máscara aparece antes.
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: PedalaquiWordmark(
                                    fontSize: 40,
                                    color: Colors.white,
                                    accent: Colors.white,
                                    style: widget.nameStyle,
                                    pin: _pininho.transform(t),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Mostra o [child] da esquerda até a [fraction] da largura, com a borda esfumada (como se
/// a linha da logo fosse escrevendo o nome).
class RevealMask extends StatelessWidget {
  const RevealMask({super.key, required this.fraction, required this.child});

  final double fraction;
  final Widget child;

  /// Largura da borda esfumada, em fração da largura.
  static const _borda = 0.12;

  @override
  Widget build(BuildContext context) {
    if (fraction >= 1) return child;
    // A borda anda junto: some inteira no começo e chega ao fim com o nome todo à mostra.
    final fim = fraction * (1 + _borda);
    final inicio = (fim - _borda).clamp(0.0, 1.0);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
        stops: [0, inicio, fim.clamp(0.0, 1.0), 1],
      ).createShader(rect),
      child: child,
    );
  }
}
