import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/rides_store.dart';

class RideTile extends StatelessWidget {
  const RideTile({super.key, required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context) {
    final titulo = ride.completed ? rideModeLabel(ride.mode) : '${rideModeLabel(ride.mode)} · incompleto';
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
                Text(titulo, style: AppText.corpoForte),
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
