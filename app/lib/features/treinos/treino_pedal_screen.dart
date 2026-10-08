import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/sim_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/ride_session.dart';
import '../../domain/training.dart';
import '../../domain/workout_runner.dart';
import '../pedal/ride_controller.dart';
import '../pedal/ride_widgets.dart';
import '../pedal_livre/pedal_livre_screen.dart';
import 'workout_chart.dart';

/// O treino em andamento: a meta do trecho, se está na meta, o que vem depois.
class TreinoPedalScreen extends ConsumerStatefulWidget {
  const TreinoPedalScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<TreinoPedalScreen> createState() => _TreinoPedalScreenState();
}

class _TreinoPedalScreenState extends ConsumerState<TreinoPedalScreen> {
  bool _encerrando = false;

  RideTarget get _alvo => RideTarget.treino(widget.workoutId);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rideProvider(_alvo).notifier).start());
  }

  Future<void> _finalizar() async {
    if (_encerrando) return;
    setState(() => _encerrando = true);
    final id = await ref.read(rideProvider(_alvo).notifier).finish();
    if (!mounted) return;
    context.go('/resumo/$id?novo=1');
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
    if (await confirmarEncerrar(context)) await _finalizar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = rideProvider(_alvo);
    final v = ref.watch(provider);
    ref.listen(provider, (anterior, proximo) {
      if (proximo.state == RideState.concluido && anterior?.state != RideState.concluido) _finalizar();
    });
    if (v.notFound) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esse treino não existe.', style: AppText.corpoForte)));
    }
    final w = v.workout;
    final f = v.frame;
    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(provider.notifier);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _encerrar();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w?.name ?? 'Treino',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            f == null ? '' : '${formatTime(f.elapsed)} de ${formatTime(f.total.toDouble())}',
                            style: AppText.suave,
                          ),
                        ],
                      ),
                    ),
                    if (v.started) BotaoVoz(ligada: v.voiceOn, onTap: ctrl.toggleVoice),
                    OutlinedButton(onPressed: _encerrar, child: const Text('Encerrar')),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: f == null || w == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (v.pausedByBike)
                                AvisoFaixa(
                                  texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                                  acao: 'Reconectar',
                                  onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                                )
                              else if (v.state == RideState.pausado)
                                const AvisoFaixa(texto: 'Treino pausado. Toque em Continuar para seguir.')
                              else if (f.rampEnded)
                                AvisoFaixa(
                                  icone: Icons.emoji_events_outlined,
                                  texto: f.rampFtp == null
                                      ? 'Teste curto demais para calcular. Agora, pedal leve.'
                                      : 'Seu FTP: ${formatNumber(f.rampFtp!)} W. Agora, pedal leve para soltar.',
                                ),
                              _MetaDoTrecho(frame: f),
                              const SizedBox(height: 10),
                              _Agora(view: v, frame: f),
                              const SizedBox(height: 10),
                              Text(
                                f.next == null
                                    ? 'Último trecho'
                                    : 'Depois: ${formatTime(f.next!.seconds.toDouble())} '
                                        '${zoneFor(f.next!.mid).effort.toLowerCase()} · '
                                        '${f.nextWatts} W',
                                style: AppText.suave,
                              ),
                              const SizedBox(height: 8),
                              WorkoutChart(workout: w, elapsed: f.elapsed, height: 64),
                              if (w.rampTest && !f.rampEnded && f.index >= 1) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.avisoTexto,
                                    side: const BorderSide(color: AppColors.avisoTexto, width: 1.5),
                                    minimumSize: const Size.fromHeight(54),
                                  ),
                                  onPressed: ctrl.endRamp,
                                  icon: const Icon(Icons.front_hand_outlined),
                                  label: const Text('Não aguento mais'),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                if (source is SimSource) SimControls(source: source),
                RideControls(
                  level: v.level,
                  paused: v.state == RideState.pausado,
                  enabled: v.started && !_encerrando,
                  onLevel: ctrl.changeLevel,
                  onPause: ctrl.togglePause,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O trecho de agora: esforço na cor da zona, meta, giro e quanto falta.
class _MetaDoTrecho extends StatelessWidget {
  const _MetaDoTrecho({required this.frame});

  final WorkoutFrame frame;

  @override
  Widget build(BuildContext context) {
    final cor = zoneColor(frame.zone.number);
    final step = frame.step;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cor, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  frame.zone.effort,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color.lerp(cor, Colors.black, 0.25)),
                ),
                if (step.cue != null) Text(step.cue!, style: AppText.corpoForte, maxLines: 2),
                const SizedBox(height: 6),
                Text(
                  '${frame.targetWatts} W${step.hasCadence ? ' · ${step.cadenceMin}–${step.cadenceMax} rpm' : ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                ),
                Text('zona ${frame.zone.number} · ${frame.zone.name}', style: AppText.suave),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTime(frame.remaining),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const Text('neste trecho', style: AppText.suave),
            ],
          ),
        ],
      ),
    );
  }
}

/// O que você está fazendo agora, comparado com a meta.
class _Agora extends StatelessWidget {
  const _Agora({required this.view, required this.frame});

  final RideView view;
  final WorkoutFrame frame;

  @override
  Widget build(BuildContext context) {
    final (cor, texto) = switch (frame.compliance) {
      Compliance.naMeta => (AppColors.destaque, view.bikeAdjusts ? 'A bike está segurando a meta' : 'Na meta'),
      Compliance.abaixo => (AppColors.avisoTexto, view.bikeAdjusts ? 'Mantenha o giro' : 'Abaixo: aumente a carga ou o giro'),
      Compliance.acima => (AppColors.avisoTexto, 'Acima: alivie um pouco'),
      Compliance.semAlvo => (AppColors.textoSuave, 'Ajuste para a meta…'),
    };
    final sugerida = view.suggestedLevel;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: MetricTile(value: formatNumber(view.power), label: 'watts')),
              Expanded(child: MetricTile(value: formatNumber(view.cadence), label: 'rpm')),
              Expanded(child: MetricTile(value: formatNumber(view.speedKmh, 1), label: 'km/h')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(frame.compliance == Compliance.naMeta ? Icons.check_circle : Icons.info_outline, color: cor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w800))),
            ],
          ),
          if (frame.cadenceHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(frame.cadenceHint!, style: const TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w700)),
            ),
          if (sugerida != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                sugerida == view.level ? 'Carga certa para a meta: $sugerida' : 'Carga sugerida para a meta: $sugerida (agora ${view.level})',
                style: AppText.suave.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
