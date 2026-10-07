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
import 'free_ride_controller.dart';

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
    Future.microtask(() => ref.read(freeRideProvider.notifier).start());
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
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
    if (ok != true || !mounted) return;
    setState(() => _encerrando = true);
    final id = await ref.read(freeRideProvider.notifier).finish();
    if (!mounted) return;
    context.go('/resumo/$id');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(freeRideProvider);
    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(freeRideProvider.notifier);
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
                  _Faixa(
                    texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                    acao: 'Reconectar',
                    onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                  )
                else if (v.estimating)
                  const _Faixa(texto: 'A bike não manda potência: estimando pela carga.'),
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
                if (source is SimSource) ...[
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: source.easier, child: const Text('Simular: mais fraco'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: source.harder, child: const Text('Simular: mais forte'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borda),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Diminuir carga',
                              onPressed: () => ctrl.changeLevel(-1),
                              icon: const Icon(Icons.remove),
                            ),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Carga ${v.level}', style: AppText.corpoForte),
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Aumentar carga',
                              onPressed: () => ctrl.changeLevel(1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.escuro,
                        minimumSize: const Size(104, 60),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: v.started ? ctrl.togglePause : null,
                      child: Text(v.state == RideState.pausado ? 'Continuar' : 'Pausar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.texto, this.acao, this.onAcao});

  final String texto;
  final String? acao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(texto, style: const TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w700)),
            ),
            if (acao != null) TextButton(onPressed: onAcao, child: Text(acao!)),
          ],
        ),
      ),
    );
  }
}
