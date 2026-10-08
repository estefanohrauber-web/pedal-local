import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/sim_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/power_chart.dart';
import '../../domain/ride_session.dart';
import '../pedal/ride_controller.dart';
import '../pedal/ride_widgets.dart';

class PedalLivreScreen extends ConsumerStatefulWidget {
  const PedalLivreScreen({super.key});

  @override
  ConsumerState<PedalLivreScreen> createState() => _PedalLivreScreenState();
}

class _PedalLivreScreenState extends ConsumerState<PedalLivreScreen> {
  bool _encerrando = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rideProvider(RideTarget.livre).notifier).start());
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
    final ok = await confirmarEncerrar(context);
    if (!ok || !mounted) return;
    setState(() => _encerrando = true);
    final id = await ref.read(rideProvider(RideTarget.livre).notifier).finish();
    if (!mounted) return;
    context.go('/resumo/$id?novo=1');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(rideProvider(RideTarget.livre));
    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(rideProvider(RideTarget.livre).notifier);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _encerrar();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Pedal livre', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                    OutlinedButton(onPressed: _encerrar, child: const Text('Encerrar')),
                  ],
                ),
                const SizedBox(height: 12),
                if (v.pausedByBike)
                  AvisoFaixa(
                    texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                    acao: 'Reconectar',
                    onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                  )
                else if (v.state == RideState.pausado)
                  const AvisoFaixa(texto: 'Pedal pausado. Toque em Continuar para seguir.')
                else if (v.estimating)
                  const AvisoFaixa(texto: 'A bike não manda potência: estimando pela carga.'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      Text(
                        formatNumber(v.speedKmh, 1),
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: AppColors.destaque,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Text('km/h', style: AppText.suave),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: MetricTile(value: formatNumber(v.power), label: 'watts')),
                          Expanded(child: MetricTile(value: formatNumber(v.cadence), label: 'rpm')),
                          Expanded(child: MetricTile(value: formatTime(v.movingTime), label: 'tempo')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: MetricTile(value: formatNumber(v.distance / 1000, 2), label: 'km')),
                          Expanded(child: MetricTile(value: formatNumber(v.kcal), label: 'kcal')),
                          Expanded(
                            child: MetricTile(
                              value: v.heartRate == null ? '—' : formatNumber(v.heartRate!),
                              label: 'bpm',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Potência nos últimos minutos', style: AppText.suave),
                        const SizedBox(height: 8),
                        Expanded(child: PowerChart(values: v.powerHistory)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (source is SimSource) SimControls(source: source),
                RideControls(
                  level: v.level,
                  paused: v.state == RideState.pausado,
                  enabled: v.started,
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

/// Pergunta se a pessoa quer mesmo encerrar o pedal.
Future<bool> confirmarEncerrar(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Encerrar o pedal?'),
      content: const Text('O pedal vai ser salvo no seu histórico.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuar pedalando')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Encerrar')),
      ],
    ),
  );
  return ok == true;
}
