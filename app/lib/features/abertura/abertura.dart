import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pedalaqui_logo.dart';

/// Chave da camada da abertura (para os testes).
const aberturaKey = ValueKey('abertura');

const _duracao = Duration(milliseconds: 1900);

/// Abertura do app, por cima dele: no fundo verde (o mesmo da tela de carregamento do
/// Android), a rota da logo se desenha e vira o pino, o nome aparece e tudo some. Um toque pula.
class Abertura extends StatefulWidget {
  const Abertura({super.key, required this.child, this.nameStyle});

  final Widget child;

  /// Fonte do nome (veja brandTextStyleProvider).
  final TextStyle? nameStyle;

  @override
  State<Abertura> createState() => _AberturaState();
}

class _AberturaState extends State<Abertura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duracao,
  );
  bool _acabou = false;

  // Fases, em fração dos 1,9 s: a linha até 0,74 s, a bolinha, o nome (inteiro de 1,2 s
  // a 1,6 s) e o sumiço.
  static const _linha = Interval(0, 0.39, curve: Curves.easeInOutCubic);
  static const _bolinha = Interval(0.37, 0.5, curve: Curves.easeOutBack);
  static const _nome = Interval(0.45, 0.63, curve: Curves.easeOut);
  static const _some = Interval(0.84, 1, curve: Curves.easeIn);

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
    return Stack(
      children: [
        widget.child,
        if (!_acabou)
          Positioned.fill(
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: GestureDetector(
                key: aberturaKey,
                behavior: HitTestBehavior.opaque,
                onTap: _pular,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = _c.value;
                    final nome = _nome.transform(t);
                    return Opacity(
                      opacity: 1 - _some.transform(t),
                      // Material (e não só uma cor): a abertura fica acima das telas, e o texto
                      // precisa dele para ter estilo (sem ele, sai sublinhado de amarelo).
                      child: Material(
                        color: AppColors.destaque,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PedalaquiMark(
                                size: 168,
                                progress: _linha.transform(t),
                                dot: _bolinha.transform(t),
                              ),
                              const SizedBox(height: 20),
                              Opacity(
                                opacity: nome,
                                child: Transform.translate(
                                  offset: Offset(0, 12 * (1 - nome)),
                                  child: PedalaquiWordmark(
                                    fontSize: 40,
                                    color: Colors.white,
                                    accent: Colors.white,
                                    style: widget.nameStyle,
                                  ),
                                ),
                              ),
                            ],
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
