import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/power_chart.dart';
import '../../domain/ride_session.dart';
import '../bike/selo_ao_vivo.dart';
import '../pedal/mais_dados_sheet.dart';
import '../pedal/ride_controller.dart';
import '../pedal/ride_widgets.dart';

/// Pedal livre (sem rota): tempo e distância grandes, a velocidade em destaque, giro e watts, a
/// potência dos últimos minutos; o resto em “Mais dados”.
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
    Future.microtask(
      () => ref.read(rideProvider(RideTarget.livre).notifier).start(),
    );
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedal livre',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SeloAoVivo(),
                        ],
                      ),
                    ),
                    if (v.started)
                      BotaoVoz(ligada: v.voiceOn, onTap: ctrl.toggleVoice),
                    OutlinedButton(
                      onPressed: _encerrar,
                      child: const Text('Encerrar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (v.pausedByBike)
                  AvisoFaixa(
                    texto:
                        bike.message ??
                        'A bike desconectou. Tentando reconectar…',
                    acao: 'Reconectar',
                    onAcao: () => ref
                        .read(bikeControllerProvider.notifier)
                        .reconnectNow(),
                  )
                else if (v.state == RideState.pausado)
                  const AvisoFaixa(
                    texto: 'Pedal pausado. Toque em Continuar para seguir.',
                  )
                else if (v.estimating)
                  const AvisoFaixa(
                    texto: 'A bike não manda potência: estimando pela carga.',
                  ),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TEMPO', style: estiloRotulo),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatTime(v.movingTime),
                                style: estiloNumero(40),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('DISTÂNCIA', style: estiloRotulo),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: formatNumber(v.distance / 1000, 2),
                                  style: estiloNumero(40),
                                ),
                                const TextSpan(
                                  text: ' km',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textoSuave,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatNumber(v.speedKmh, 1),
                                style: estiloNumero(
                                  56,
                                  cor: AppColors.destaque,
                                ),
                              ),
                            ),
                            const Text('km/h', style: estiloRotulo),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: MetricTile(
                          value: formatNumber(v.cadence),
                          label: 'rpm',
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: MetricTile(
                          value: formatNumber(v.power),
                          label: v.estimating ? 'watts (est.)' : 'watts',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Potência nos últimos minutos',
                          style: AppText.suave,
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: PowerChart(values: v.powerHistory)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            mostrarMaisDados(context, RideTarget.livre),
                        icon: const Icon(Icons.expand_less),
                        label: const Text('Mais dados'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.escuro,
                        minimumSize: const Size(116, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: v.started && !_encerrando
                          ? ctrl.togglePause
                          : null,
                      child: Text(
                        v.state == RideState.pausado ? 'Continuar' : 'Pausar',
                      ),
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

/// Pergunta se a pessoa quer mesmo encerrar o pedal.
Future<bool> confirmarEncerrar(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Encerrar o pedal?'),
      content: const Text('O pedal vai ser salvo no seu histórico.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Continuar pedalando'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Encerrar'),
        ),
      ],
    ),
  );
  return ok == true;
}
