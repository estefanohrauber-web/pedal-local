import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pedalaqui_logo.dart';

/// Chave da camada da abertura (para os testes).
const aberturaKey = ValueKey('abertura');

/// Canal pelo qual a tela de carregamento do Android passa a abertura para o app (MainActivity).
const aberturaCanal = MethodChannel('pedalaqui/abertura');

/// No Android 12+, a tela de carregamento desenha o começo da abertura (splash_logo.xml) e a
/// passa para o app pelo [aberturaCanal]. Sobrescrito no main() pelo argumento do Android.
final aberturaDoAndroidProvider = Provider<bool>((ref) => false);

/// Tamanho do símbolo, igual ao da tela de carregamento (splash_logo.xml: escala 0,8).
const _simbolo = 160.0;

// Começo da abertura, em ms desde o começo da animação, igual à tela de carregamento: a rota se
// desenha; a bolinha pinga; e um anel sai dela a cada 1,2 s enquanto o app carrega.
const _desenhoMs = 750.0;
const _bolinhaMs = (750.0, 1270.0);
const _primeiroAnelMs = 810.0;
const _anelMs = 700.0;
const _cicloDoAnelMs = 1200.0;

// Depois que o app assume (e não antes de a rota estar desenhada), em ms: o nome aparece; o
// pininho cai no i; o app é montado por baixo; a logo fica parada um instante; e a bolinha vira
// uma janela que cresce e mostra o app.
const _nomeMs = (0.0, 380.0);
const _pininhoMs = (200.0, 700.0);
const _montaAppMs = 700.0;
const _revelaMs = (1080.0, 1520.0);

/// Quanto o app espera a tela de carregamento passar a abertura antes de fazê-la sozinho: um
/// tempo e um tanto de quadros (na versão de teste, o app trava o Android por mais de 1 s ao
/// começar, e o aviso fica na fila; os quadros não andam nesse tempo).
const _esperaMaximaMs = 1000.0;
const _esperaMaximaQuadros = 60;

/// Abertura do app, por cima dele, no verde da tela de carregamento: a rota da logo se desenha,
/// a bolinha amarela pinga e solta anéis enquanto o app carrega; então o nome aparece e o
/// pininho cai no i; um instante depois, a bolinha se abre e mostra o app. No Android 12+, o
/// começo é desenhado pela tela de carregamento, e a abertura continua do mesmo ponto.
/// Um toque pula para a abertura final.
class Abertura extends StatefulWidget {
  const Abertura({super.key, required this.child, this.nameStyle, this.doAndroid = false});

  final Widget child;

  /// Fonte do nome (veja brandTextStyleProvider).
  final TextStyle? nameStyle;

  /// A tela de carregamento do Android vai passar a abertura (veja [aberturaDoAndroidProvider]).
  final bool doAndroid;

  @override
  State<Abertura> createState() => _AberturaState();
}

class _AberturaState extends State<Abertura> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_quadro);

  /// Hora do quadro atual, em ms: o tempo desde que o celular ligou, o mesmo relógio da
  /// animação da tela de carregamento.
  double _agora = 0;
  double? _primeiroQuadro;
  int _quadros = 0;

  /// Começo da animação, nesse relógio; null enquanto a tela de carregamento não passa a abertura.
  double? _inicio;

  /// O que a tela de carregamento contou ao passar a abertura (usado no quadro seguinte).
  ({double inicio, double decorrido})? _entrega;

  /// Ponto da animação em que o app assumiu; null enquanto ela está com a tela de carregamento.
  double? _assumiu;

  /// Começo da parte do app (nome, pininho, transição), no tempo da animação.
  double _sequencia = double.infinity;

  bool _pulou = false;
  bool _acabou = false;

  /// Tempo da animação, em ms.
  double get _t => _inicio == null ? 0 : _agora - _inicio!;

  @override
  void initState() {
    super.initState();
    if (widget.doAndroid) aberturaCanal.setMethodCallHandler(_doAndroid);
    _ticker.start();
  }

  @override
  void dispose() {
    if (widget.doAndroid) aberturaCanal.setMethodCallHandler(null);
    _ticker.dispose();
    super.dispose();
  }

  void _quadro(Duration _) {
    final agora = SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds / 1000;
    _primeiroQuadro ??= agora;
    _quadros++;
    final entrega = _entrega;
    if (entrega != null) {
      _entrega = null;
      _inicio = _comecoDaTelaDeCarregamento(entrega, agora);
    }
    final esperouDemais = agora - _primeiroQuadro! > _esperaMaximaMs && _quadros > _esperaMaximaQuadros;
    if (_inicio == null && (!widget.doAndroid || esperouDemais)) {
      // Sem a tela de carregamento animada: o app desenha a abertura toda.
      _inicio = agora;
      _assumir(0);
    }
    setState(() {
      _agora = agora;
      if (_t >= _sequencia + _revelaMs.$2) _acabou = true;
    });
    if (_acabou) _ticker.stop();
  }

  /// A tela de carregamento passa a abertura: o app desenha a logo no mesmo ponto da animação
  /// e responde depois de dois quadros, quando ela pode sair de cima.
  Future<Object?> _doAndroid(MethodCall call) async {
    if (call.method != 'abrir') throw MissingPluginException();
    final dados = call.arguments as Map<Object?, Object?>;
    if (_assumiu == null) {
      _entrega = (
        inicio: (dados['inicio']! as num).toDouble(),
        decorrido: (dados['decorrido']! as num).toDouble(),
      );
      await SchedulerBinding.instance.endOfFrame;
      await SchedulerBinding.instance.endOfFrame;
      if (mounted) _assumir(_t);
    }
    return true;
  }

  /// Começo da animação da tela de carregamento, no relógio dos quadros. O relógio do Android é
  /// o mesmo; se não bater, vale o tempo que a animação tinha quando o Android avisou.
  double _comecoDaTelaDeCarregamento(({double inicio, double decorrido}) e, double agora) {
    if (e.decorrido < 0) return agora; // ela não tinha animação: o app desenha tudo
    final t = agora - e.inicio;
    return t >= e.decorrido && t < e.decorrido + 500 ? e.inicio : agora - e.decorrido;
  }

  void _assumir(double t) {
    _assumiu = t;
    _sequencia = math.max(t, _desenhoMs);
  }

  void _pular() {
    if (_assumiu == null) return;
    _pulou = true;
    _sequencia = math.min(_sequencia, _t - _revelaMs.$1);
  }

  /// Andamento (0 a 1) de uma fase que vai de [fase].$1 a [fase].$2 ms depois de [desde].
  double _fase(double desde, (double, double) fase, [Curve curva = Curves.linear]) =>
      curva.transform(((_t - desde - fase.$1) / (fase.$2 - fase.$1)).clamp(0.0, 1.0));

  /// O anel que sai da bolinha (0 a 1; 0 = nenhum): um a cada 1,2 s enquanto a abertura está com
  /// a tela de carregamento; depois que o app assume, só termina o que já tinha saído (e o
  /// primeiro sai sempre).
  double _anel() {
    final desde = _t - _primeiroAnelMs;
    if (desde < 0 || _pulou) return 0;
    final ciclo = (desde / _cicloDoAnelMs).floor();
    final assumiu = _assumiu;
    if (ciclo > 0 && assumiu != null && _primeiroAnelMs + ciclo * _cicloDoAnelMs > assumiu) return 0;
    final fase = desde - ciclo * _cicloDoAnelMs;
    return fase >= _anelMs ? 0 : Curves.easeOut.transform(fase / _anelMs);
  }

  /// Altura do centro da tela de carregamento, na régua da tela do app: ela centraliza na tela
  /// inteira, e a do app pode não ir até embaixo (barra de navegação).
  double _centroY(BuildContext context, double altura) {
    final view = View.of(context);
    final tela = view.display.size.height / view.devicePixelRatio;
    return tela >= altura && tela - altura < 80 ? tela / 2 : altura / 2;
  }

  @override
  Widget build(BuildContext context) {
    final linha = _pulou ? 1.0 : (_t / _desenhoMs).clamp(0.0, 1.0);
    final revela = _fase(_sequencia, _revelaMs, Curves.easeInCubic);
    return Stack(
      children: [
        // O app por baixo só é montado com a logo quase pronta: montar as telas pesa, e a
        // animação andaria aos trancos.
        if (_t >= _sequencia + _montaAppMs || _acabou) widget.child,
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
                                    dot: _pulou ? 1 : _fase(0, _bolinhaMs, const ElasticOutCurve(0.5)),
                                    ring: _anel(),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: topo + _simbolo - 6,
                                  child: Center(
                                    child: RevealMask(
                                      fraction: _fase(_sequencia, _nomeMs, Curves.easeOutCubic),
                                      // Folga em volta: a perninha do q e o pininho do i saem
                                      // da caixa do texto, e o que fica fora da máscara aparece antes.
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: PedalaquiWordmark(
                                          fontSize: 40,
                                          color: Colors.white,
                                          accent: Colors.white,
                                          style: widget.nameStyle,
                                          pin: _fase(_sequencia, _pininhoMs, Curves.bounceOut),
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
