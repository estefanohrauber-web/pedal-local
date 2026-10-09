import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pedalaqui_logo.dart';

/// Chave da camada da abertura (para os testes).
const aberturaKey = ValueKey('abertura');

/// A tela de carregamento do Android (12+) já desenhou a rota (veja MainActivity): a
/// abertura continua da linha pronta. Sobrescrito no main() pelo argumento do Android.
final aberturaLinhaProntaProvider = Provider<bool>((ref) => false);

/// Tamanho do símbolo, igual ao da tela de carregamento (splash_logo.xml: escala 0,8).
const _simbolo = 160.0;

/// Duração do desenho da rota (igual à tela de carregamento).
const _desenhoMs = 750.0;

// Depois da linha pronta, em ms: a bolinha pinga com um anel e o nome aparece; o pininho
// cai no i; o app é montado por baixo; a logo fica parada um instante; e a bolinha vira uma
// janela que cresce e mostra o app.
const _nomeMs = (0.0, 380.0);
const _bolinhaMs = (0.0, 520.0);
const _anelMs = (60.0, 760.0);
const _pininhoMs = (200.0, 700.0);
const _montaAppMs = 700.0;
const _revelaMs = (1080.0, 1520.0);

/// Abertura do app, por cima dele, no verde da tela de carregamento: a rota da logo se
/// desenha (ou já veio desenhada pelo Android), a bolinha amarela pinga com um anel, o nome
/// aparece e o pininho cai no i; um instante depois, a bolinha se abre e mostra o app.
/// Um toque pula para a abertura final.
class Abertura extends StatefulWidget {
  const Abertura({super.key, required this.child, this.nameStyle, this.linhaPronta = false});

  final Widget child;

  /// Fonte do nome (veja brandTextStyleProvider).
  final TextStyle? nameStyle;

  /// A linha já foi desenhada pela tela de carregamento do Android.
  final bool linhaPronta;

  @override
  State<Abertura> createState() => _AberturaState();
}

class _AberturaState extends State<Abertura> with SingleTickerProviderStateMixin {
  late final double _depois = widget.linhaPronta ? 0 : _desenhoMs;
  late final double _totalMs = _depois + _revelaMs.$2;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs.round()),
  );
  bool _acabou = false;

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
    final inicio = (_depois + _revelaMs.$1) / _totalMs;
    if (_c.value < inicio) _c.forward(from: inicio);
  }

  /// Andamento (0 a 1) de uma fase que vai de [fase].$1 a [fase].$2 ms depois da linha pronta.
  double _fase(double ms, (double, double) fase, [Curve curva = Curves.linear]) =>
      curva.transform(((ms - _depois - fase.$1) / (fase.$2 - fase.$1)).clamp(0.0, 1.0));

  /// Altura do centro da tela de carregamento, na régua da tela do app: ela centraliza na tela
  /// inteira, e a do app pode não ir até embaixo (barra de navegação).
  double _centroY(BuildContext context, double altura) {
    final view = View.of(context);
    final tela = view.display.size.height / view.devicePixelRatio;
    return tela >= altura && tela - altura < 80 ? tela / 2 : altura / 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _c.value * _totalMs;
        final linha = widget.linhaPronta ? 1.0 : (ms / _desenhoMs).clamp(0.0, 1.0);
        final revela = _fase(ms, _revelaMs, Curves.easeInCubic);
        return Stack(
          children: [
            // O app por baixo só é montado com a logo quase pronta: montar as telas pesa, e
            // a animação andaria aos trancos.
            if (ms >= _depois + _montaAppMs || _acabou) widget.child,
            if (!_acabou)
              Positioned.fill(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
                  child: GestureDetector(
                    key: aberturaKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: _pular,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final largura = box.maxWidth;
                        final cy = _centroY(context, box.maxHeight);
                        final topo = cy - _simbolo / 2;
                        // A bolinha, na tela: o centro do pino no desenho (136, 58 + 7) × 0,8.
                        final bolinha = Offset(largura / 2 - _simbolo / 2 + 136 * 0.8, topo + 65 * 0.8);
                        final cantoMaisLonge = [
                          Offset.zero,
                          Offset(largura, 0),
                          Offset(0, box.maxHeight),
                          Offset(largura, box.maxHeight),
                        ].map((c) => (c - bolinha).distance).reduce(math.max);
                        return ClipPath(
                          clipper: _Buraco(bolinha, revela * (cantoMaisLonge + 8)),
                          // Material (e não só uma cor): a abertura fica acima das telas, e o
                          // texto precisa dele para ter estilo (sem ele, sai sublinhado de amarelo).
                          child: Material(
                            color: AppColors.destaque,
                            child: Opacity(
                              opacity: 1 - revela,
                              child: Transform.scale(
                                scale: 1 + 0.18 * revela,
                                origin: bolinha - Offset(largura / 2, box.maxHeight / 2),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: largura / 2 - _simbolo / 2,
                                      top: topo,
                                      child: PedalaquiMark(
                                        size: _simbolo,
                                        progress: Curves.easeInOutSine.transform(linha),
                                        dot: _fase(ms, _bolinhaMs, const ElasticOutCurve(0.5)),
                                        ring: _fase(ms, _anelMs, Curves.easeOut),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: topo + _simbolo - 6,
                                      child: Center(
                                        child: RevealMask(
                                          fraction: _fase(ms, _nomeMs, Curves.easeOutCubic),
                                          // Folga em volta: a perninha do q e o pininho do i saem
                                          // da caixa do texto, e o que fica fora da máscara aparece antes.
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: PedalaquiWordmark(
                                              fontSize: 40,
                                              color: Colors.white,
                                              accent: Colors.white,
                                              style: widget.nameStyle,
                                              pin: _fase(ms, _pininhoMs, Curves.bounceOut),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

/// A tela toda menos um círculo: a janela que se abre a partir da bolinha.
class _Buraco extends CustomClipper<Path> {
  _Buraco(this.centro, this.raio);

  final Offset centro;
  final double raio;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: centro, radius: raio));

  @override
  bool shouldReclip(_Buraco old) => old.raio != raio || old.centro != centro;
}

/// Mostra o [child] da esquerda até a [fraction] da largura, com a borda esfumada (como se
/// o nome fosse sendo escrito).
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
