import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_controller.dart';
import '../../bike/sim_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import 'ride_controller.dart';
import 'ride_widgets.dart';

/// “Mais dados” do pedal: o que não cabe no relance (médias, calorias, subida, quanto falta) e o
/// controle da carga. Continua atualizando ao vivo enquanto está aberto.
Future<void> mostrarMaisDados(BuildContext context, RideTarget target) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.superficie,
      builder: (_) => MaisDados(target: target),
    );

class MaisDados extends ConsumerWidget {
  const MaisDados({super.key, required this.target});

  final RideTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(rideProvider(target));
    final ctrl = ref.read(rideProvider(target).notifier);
    final fonte = ref.watch(bikeControllerProvider).source;
    final falta = v.isRoute && !v.isLoop && v.total.isFinite
        ? v.total - v.distance
        : null;
    final media = v.avgSpeedKmh;
    final dados = <(String, String)>[
      (formatNumber(v.kcal), 'calorias'),
      (formatNumber(media, 1), 'km/h média'),
      (formatNumber(v.avgPower), 'watts média'),
      ('${formatNumber(v.climbed)} m', 'de subida'),
      (v.heartRate == null ? '—' : formatNumber(v.heartRate!), 'batimentos'),
      if (v.isRoute) ('${formatNumber(v.grade * 100, 1)}%', 'inclinação'),
      if (falta != null && falta > 0 && media > 1)
        (formatTime(falta / 1000 / media * 3600), 'para chegar'),
      if (v.isLoop)
        ('${v.lapsDone}', v.lapsDone == 1 ? 'volta feita' : 'voltas feitas'),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Mais dados', style: AppText.secao),
              const SizedBox(height: 12),
              // A carga em cima: é o que se mexe pedalando.
              CargaControle(
                rotulo: 'Carga ${v.level}',
                onLevel: ctrl.changeLevel,
              ),
              const SizedBox(height: 4),
              const Text(
                'Acompanhe o botão da bike: entra na conta quando o app estima os watts.',
                style: AppText.suave,
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, box) {
                  final largura = (box.maxWidth - 2 * 10) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (valor, rotulo) in dados)
                        Container(
                          width: largura,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neutro,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  valor,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rotulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.suave,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (v.ghostGapS != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const FantasmaPonto(tamanho: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        textoFantasma(v.ghostGapS!),
                        style: AppText.corpoForte,
                      ),
                    ),
                  ],
                ),
              ],
              if (fonte is SimSource) ...[
                const SizedBox(height: 10),
                SimControls(source: fonte),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
