import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';

class RideTile extends ConsumerWidget {
  const RideTile({super.key, required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = ride.routeId;
    // Pedal em rota mostra o nome da rota; se ela foi apagada, fica "Rota".
    final nomeRota = routeId == null
        ? null
        : ref.watch(routeByIdProvider(routeId)).when(
              data: (r) => r?.name,
              loading: () => null,
              error: (e, s) => null,
            );
    final base = nomeRota ?? rideModeLabel(ride.mode);
    final titulo = ride.completed ? base : '$base · incompleto';
    return AppCard(
      onTap: () => context.push('/resumo/${ride.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
            child: Icon(
              ride.mode == RideMode.livre ? Icons.bar_chart_rounded : Icons.map_outlined,
              color: AppColors.destaqueTexto,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${formatDateTime(ride.startedAt)} · ${formatKm(ride.distanceM)} · ${formatTime(ride.movingTimeS)}',
                  style: AppText.suave,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textoSuave),
        ],
      ),
    );
  }
}
