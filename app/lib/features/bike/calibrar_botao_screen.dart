import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_live.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice.dart';
import '../../core/wake_lock.dart';
import '../../data/providers.dart';
import '../../domain/botao_peso.dart';
import '../../domain/calibracao_botao.dart';
import '../../domain/power.dart';
import '../pedal/ride_widgets.dart';

/// Segundos pedalando em cada volta; na primeira (o mais leve), um pouco mais para embalar.
const segundosPorVolta = 10;
const segundosNaPrimeira = 15;

/// Os primeiros segundos de cada volta são de girar o botão: o giro só conta depois.
const _segundosGirando = 4;

/// Um botão não passa disso; se ninguém tocar no fim, a calibração termina sozinha.
const _maxVoltas = 30;

enum _Fase { antes, pedalando, pronto }

/// Calibrar o botão de peso, guiado pela voz: começando no mais leve, a pessoa pedala perto de
/// 60 rpm e gira uma volta a cada 10 segundos, quando a voz pede. O app conta as voltas, anota o
/// giro e os watts em cada uma e descobre quantas voltas o botão dá, até que volta dá para
/// pedalar e se a bike sente o botão nos watts.
class CalibrarBotaoScreen extends ConsumerStatefulWidget {
  const CalibrarBotaoScreen({super.key});

  @override
  ConsumerState<CalibrarBotaoScreen> createState() => _CalibrarBotaoScreenState();
}

class _CalibrarBotaoScreenState extends ConsumerState<CalibrarBotaoScreen> {
  _Fase _fase = _Fase.antes;
  int _volta = 0;
  int _segundos = 0;
  String _fala = '';
  Timer? _relogio;
  final _medidas = <int, VoltaMedida>{};
  final _amostras = <(double, double)>[];

  // O resultado, ajustável antes de salvar.
  int _total = 0;
  int? _limite;
  bool? _sente;

  late final WakeLock _telaAcesa = ref.read(wakeLockProvider);
  late final Voice _voz = ref.read(voiceProvider);

  int get _duracao => _volta == 0 ? segundosNaPrimeira : segundosPorVolta;

  void _falar(String frase) {
    _fala = frase;
    _voz.speak(frase);
  }

  void _comecar() {
    _telaAcesa.enable();
    setState(() {
      _fase = _Fase.pedalando;
      _volta = 0;
      _segundos = 0;
      _medidas.clear();
      _amostras.clear();
      _falar('Pedale no mais leve, num giro perto de $metaRpm.');
    });
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) => _tique());
  }

  void _tique() {
    if (!mounted) return;
    setState(() {
      _segundos++;
      if (_segundos < _duracao) return;
      _fecharVolta();
      if (_volta >= _maxVoltas) {
        _terminar(_volta);
        return;
      }
      _volta++;
      _segundos = 0;
      HapticFeedback.mediumImpact();
      _falar('Gire mais uma volta.');
    });
  }

  /// Guarda a média do giro e dos watts desta volta (se a bike mandou algo).
  void _fecharVolta() {
    if (_amostras.isNotEmpty) {
      double media(double Function((double, double)) f) => _amostras.map(f).reduce((a, b) => a + b) / _amostras.length;
      _medidas[_volta] = VoltaMedida(_volta, media((a) => a.$1), media((a) => a.$2));
    }
    _amostras.clear();
  }

  void _desfazer() => setState(() {
    _volta = math.max(0, _volta - 1);
    _segundos = 0;
    _amostras.clear();
    _falar(_volta == 0 ? 'Tudo bem, fique no mais leve.' : 'Tudo bem, fique na volta $_volta.');
  });

  /// [total]: voltas que o botão deu (a pedida agora, que travou, não conta).
  void _terminar(int total) {
    _relogio?.cancel();
    _telaAcesa.disable();
    final medidas = [
      for (final m in _medidas.values)
        if (m.volta <= total) m,
    ];
    _total = math.max(1, total);
    _limite = limitePedalavel(medidas);
    _sente = bikeSenteOBotao(medidas);
    _fase = _Fase.pronto;
    _falar('Pronto! Pode parar de pedalar.');
  }

  Future<void> _salvar() async {
    final store = ref.read(settingsStoreProvider);
    final atual = await store.load();
    final limite = _limite;
    await store.save(
      atual.copyWith(
        voltasBotao: _total,
        limiteBotao: limite?.clamp(1, _total),
        semLimite: limite == null,
        modoPotencia: _sente == true ? PowerMode.bike : null,
      ),
    );
    ref.invalidate(settingsProvider);
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _relogio?.cancel();
    if (_fase == _Fase.pedalando) {
      _telaAcesa.disable();
      _voz.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // O giro e os watts só contam depois dos segundos de girar o botão.
    ref.listen(bikeLiveProvider, (antes, agora) {
      final r = agora.last;
      if (_fase != _Fase.pedalando || r == null || identical(r, antes?.last) || _segundos < _segundosGirando) return;
      final giro = r.cadence ?? 0;
      if (giro > 0) _amostras.add((giro, (r.power ?? 0).toDouble()));
    });
    return Scaffold(
      appBar: AppBar(leading: const CloseButton(), title: const Text('Calibrar o botão')),
      body: SafeArea(
        child: switch (_fase) {
          _Fase.antes => _Antes(onComecar: _comecar),
          _Fase.pedalando => _Pedalando(
            fala: _fala,
            volta: _volta,
            faltam: _duracao - _segundos,
            fracao: _segundos / _duracao,
            medidas: _medidas,
            onDesfazer: _volta > 0 ? _desfazer : null,
            onTravou: _volta > 0 ? () => setState(() => _terminar(_volta - 1)) : null,
          ),
          _Fase.pronto => _Pronto(
            total: _total,
            limite: _limite,
            sente: _sente,
            medidas: [
              for (final m in _medidas.values)
                if (m.volta <= _total) m,
            ],
            onMudar: (delta) => setState(() => _total = (_total + delta).clamp(1, _maxVoltas)),
            onDeNovo: _comecar,
            onSalvar: _salvar,
          ),
        },
      ),
    );
  }
}

/// Antes de começar: para que serve e o que vai acontecer.
class _Antes extends ConsumerWidget {
  const _Antes({required this.onComecar});

  final VoidCallback onComecar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectada = ref.watch(bikeControllerProvider.select((b) => b.connected));
    final anterior = ref.watch(settingsProvider).value?.voltasBotao;
    const passos = [
      (Icons.restart_alt, 'Gire o botão de peso todo para o mais leve.'),
      (Icons.speed, 'Pedale num giro perto de $metaRpm por minuto.'),
      (Icons.record_voice_over_outlined, 'A cada 10 segundos a voz pede: gire mais uma volta.'),
      (Icons.pan_tool_outlined, 'Quando o botão travar, toque em "O botão não gira mais".'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              const Text(
                'Ensine o botão ao app',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                'A bike não sabe em que posição está o botão. Pedalando uns 3 minutos, o app aprende '
                'quantas voltas ele dá e até onde dá para pedalar. Depois, nas subidas, a voz diz quantas '
                'voltas girar.${anterior == null ? '' : ' Da última vez foram $anterior voltas.'}',
                style: AppText.subtitulo.copyWith(height: 1.45),
              ),
              if (!conectada) ...[
                const SizedBox(height: 14),
                AvisoFaixa(
                  icone: Icons.bluetooth_disabled,
                  texto: 'A bike não está conectada: o app só vai contar as voltas, sem medir o giro.',
                  acao: 'Conectar',
                  onAcao: () => context.push('/bike'),
                ),
              ],
              const SizedBox(height: 16),
              for (final (i, (icone, texto)) in passos.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.destaqueSuave,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icone, color: AppColors.destaqueTexto, semanticLabel: 'Passo ${i + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(texto, style: AppText.corpoForte),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FilledButton(onPressed: onComecar, child: const Text('Começar')),
        ),
      ],
    );
  }
}

/// Durante: a voz, o giro ao vivo, a volta e o giro anotado em cada uma.
class _Pedalando extends ConsumerWidget {
  const _Pedalando({
    required this.fala,
    required this.volta,
    required this.faltam,
    required this.fracao,
    required this.medidas,
    required this.onDesfazer,
    required this.onTravou,
  });

  final String fala;
  final int volta;
  final int faltam;
  final double fracao;
  final Map<int, VoltaMedida> medidas;
  final VoidCallback? onDesfazer;
  final VoidCallback? onTravou;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(bikeLiveProvider);
    final giro = live.status == BikeLive.semBike ? null : live.last?.cadence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.destaqueSuave,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_outlined, size: 20, color: AppColors.destaqueTexto),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '"$fala"',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.destaqueTexto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(child: _MedidorDeGiro(giro: giro)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: AppText.subtitulo,
                  children: [
                    if (volta == 0)
                      const TextSpan(text: 'No mais leve')
                    else ...[
                      const TextSpan(text: 'Volta '),
                      TextSpan(text: '$volta', style: estiloNumero(34)),
                    ],
                    TextSpan(text: ' · próxima em $faltam s'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fracao,
                    minHeight: 6,
                    backgroundColor: AppColors.destaqueSuave,
                    color: AppColors.destaque,
                  ),
                ),
              ),
              if (giro != null) ...[
                const SizedBox(height: 18),
                _GiroPorVolta(medidas: medidas, atual: volta),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: onDesfazer,
                icon: const Icon(Icons.undo),
                label: const Text('Desfazer uma volta'),
              ),
              const SizedBox(height: 4),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.escuro),
                onPressed: onTravou,
                child: const Text('O botão não gira mais'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Arco de 0 a 100 rpm com a faixa da meta (55 a 65) e o giro de agora.
class _MedidorDeGiro extends StatelessWidget {
  const _MedidorDeGiro({required this.giro});

  final double? giro;

  @override
  Widget build(BuildContext context) {
    final g = giro;
    return Semantics(
      label: g == null ? 'Giro: sem a bike' : 'Giro: ${g.round()} por minuto, meta $metaRpm',
      excludeSemantics: true,
      child: SizedBox(
        width: 220,
        height: 140,
        child: CustomPaint(
          painter: _Arco(g),
          child: Align(
            alignment: const Alignment(0, 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g == null ? '—' : '${g.round()}', style: estiloNumero(56)),
                Text(
                  g == null ? 'sem a bike, só contando' : 'rpm · meta $metaRpm',
                  style: estiloRotulo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arco extends CustomPainter {
  _Arco(this.giro);

  final double? giro;

  static const _max = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    const largura = 16.0;
    final raio = size.width / 2 - largura / 2;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height - largura / 2), radius: raio);
    Paint traco(Color cor, {StrokeCap ponta = StrokeCap.round}) => Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura
      ..strokeCap = ponta;
    double angulo(double rpm) => math.pi * (rpm.clamp(0, _max) / _max);
    canvas.drawArc(rect, math.pi, math.pi, false, traco(AppColors.neutro));
    canvas.drawArc(
      rect,
      math.pi + angulo(metaRpm - 5),
      angulo(10),
      false,
      traco(const Color(0xFFB9E3CB), ponta: StrokeCap.butt),
    );
    final g = giro;
    if (g != null && g > 0) {
      canvas.drawArc(rect, math.pi, angulo(g), false, traco(g < rpmMinimo ? AppColors.avisoTexto : AppColors.destaque));
    }
  }

  @override
  bool shouldRepaint(_Arco old) => old.giro != giro;
}

/// Uma barra por volta, da altura do giro médio nela: verde quando manteve, âmbar quando caiu.
class _GiroPorVolta extends StatelessWidget {
  const _GiroPorVolta({required this.medidas, required this.atual});

  final Map<int, VoltaMedida> medidas;

  /// A volta em andamento (null = já terminou).
  final int? atual;

  @override
  Widget build(BuildContext context) {
    final ultima = math.max(atual ?? 0, medidas.keys.fold(0, math.max));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        border: Border.all(color: AppColors.borda),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Giro em cada volta', style: AppText.corpoForte)),
              if (atual != null)
                const Flexible(
                  child: Text('o app está anotando', style: AppText.suave, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Da volta 1 em diante: a 0 (o mais leve) é só para embalar.
                for (var v = 1; v <= math.max(ultima, 10); v++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _Barra(medida: medidas[v], atual: v == atual),
                    ),
                  ),
              ],
            ),
          ),
          if (atual == null) ...[
            const SizedBox(height: 8),
            const Text('Verde: manteve o giro · marrom: o giro caiu', style: AppText.suave),
          ],
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.medida, required this.atual});

  final VoltaMedida? medida;
  final bool atual;

  @override
  Widget build(BuildContext context) {
    final m = medida;
    final altura = m == null ? 10.0 : (m.rpm / 80).clamp(0.12, 1.0) * 56;
    final cor = m == null
        ? (atual ? const Color(0xFFB9E3CB) : AppColors.neutro)
        : m.rpm < rpmMinimo
            ? AppColors.avisoTexto
            : AppColors.destaque;
    return Container(
      height: altura,
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3)),
    );
  }
}

/// No fim: quantas voltas (ajustável), até onde deu para pedalar e o que a bike fez com os watts.
class _Pronto extends StatelessWidget {
  const _Pronto({
    required this.total,
    required this.limite,
    required this.sente,
    required this.medidas,
    required this.onMudar,
    required this.onDeNovo,
    required this.onSalvar,
  });

  final int total;
  final int? limite;
  final bool? sente;
  final List<VoltaMedida> medidas;
  final ValueChanged<int> onMudar;
  final VoidCallback onDeNovo;
  final VoidCallback onSalvar;

  @override
  Widget build(BuildContext context) {
    final l = limite?.clamp(1, total);
    final usado = l ?? BotaoPeso(total).limite;
    final achados = [
      if (l != null)
        (Icons.trending_up, 'Você manteve $metaRpm rpm até a volta $l. Nas subidas fortes, a voz pede até $usado voltas.')
      else
        (
          Icons.trending_up,
          'Sem o giro da bike, o app supõe que dá para pedalar até a volta $usado. Calibre com a bike '
              'conectada para ele medir.',
        ),
      if (sente == false)
        (Icons.bolt, 'Os watts não mudaram com o botão: a sua bike conta só o giro. O app calcula o peso pelas voltas.'),
      if (sente == true) (Icons.bolt, 'Os watts subiram com o botão: a sua bike sente o peso. O app vai usar os watts dela.'),
      (Icons.restart_alt, 'Comece cada pedal com o botão no mais leve.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              const Text(
                'Seu botão dá',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Uma volta a menos',
                    onPressed: total > 1 ? () => onMudar(-1) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text('$total', style: estiloNumero(64)),
                      Text(total == 1 ? 'volta' : 'voltas', style: estiloRotulo),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    tooltip: 'Uma volta a mais',
                    onPressed: () => onMudar(1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Contou diferente do que você girou? Corrija aqui.',
                textAlign: TextAlign.center,
                style: AppText.suave,
              ),
              const SizedBox(height: 20),
              for (final (icone, texto) in achados)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icone, color: AppColors.destaque),
                      const SizedBox(width: 12),
                      Expanded(child: Text(texto, style: AppText.corpoForte)),
                    ],
                  ),
                ),
              if (medidas.isNotEmpty) ...[
                const SizedBox(height: 4),
                _GiroPorVolta(medidas: {for (final m in medidas) m.volta: m}, atual: null),
              ],
              Center(
                child: TextButton(onPressed: onDeNovo, child: const Text('Calibrar de novo')),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.escuro),
            onPressed: onSalvar,
            child: const Text('Salvar'),
          ),
        ),
      ],
    );
  }
}
