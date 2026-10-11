import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_live.dart';
import '../../core/theme/app_theme.dart';

/// Texto e cor de cada estado dos dados da bike.
(String, Color) textoAoVivo(BikeLive status, {bool simulada = false}) =>
    switch (status) {
      BikeLive.aoVivo => (
        simulada ? 'bike simulada' : 'ao vivo',
        AppColors.destaqueTexto,
      ),
      BikeLive.parada => ('parada: pedale', AppColors.avisoTexto),
      BikeLive.esperando => ('sem dados', AppColors.avisoTexto),
      BikeLive.conectando => ('reconectando…', AppColors.textoSuave),
      BikeLive.semBike => ('sem bike', AppColors.textoSuave),
    };

/// Bolinha e texto: se os dados da bike estão chegando agora.
class SeloAoVivo extends ConsumerWidget {
  const SeloAoVivo({super.key, this.nome = false});

  /// Mostra o nome da bike antes do estado (“WINNEK BT-151 · ao vivo”).
  final bool nome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(bikeLiveProvider);
    final fonte = ref.watch(bikeControllerProvider).source;
    final (texto, cor) = textoAoVivo(
      live.status,
      simulada: fonte?.simulated ?? false,
    );
    final rotulo = nome && fonte != null ? '${fonte.name} · $texto' : texto;
    return Semantics(
      label: 'Bike: $rotulo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: live.status == BikeLive.aoVivo
                  ? const Color(0xFF1FB866)
                  : cor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
