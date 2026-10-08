import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/power_chart.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';

class ResumoScreen extends ConsumerWidget {
  const ResumoScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideByIdProvider(rideId));
    return Scaffold(
      body: SafeArea(
        child: ride.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Não consegui abrir o pedal: $e')),
          data: (r) => r == null ? const Center(child: Text('Pedal não encontrado.')) : _Conteudo(ride: r),
        ),
      ),
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = ride.routeId;
    final nomeRota = routeId == null
        ? null
        : ref.watch(routeByIdProvider(routeId)).when(
              data: (r) => r?.name,
              loading: () => null,
              error: (e, s) => null,
            );
    final titulo = !ride.completed
        ? 'Pedal salvo'
        : ride.mode == RideMode.rota
            ? 'Rota concluída!'
            : 'Pedal concluído!';
    final subtitulo = [nomeRota ?? rideModeLabel(ride.mode), formatDateTime(ride.startedAt)].join(' · ');
    final potencias = ride.samples.map((s) => s.power).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.destaque, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppText.titulo.copyWith(fontSize: 24)),
                  Text(subtitulo, style: AppText.subtitulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: MetricTile(value: formatNumber(ride.distanceM / 1000, 2), label: 'km')),
                  Expanded(child: MetricTile(value: formatTime(ride.movingTimeS), label: 'tempo')),
                  Expanded(child: MetricTile(value: formatNumber(ride.avgSpeedKmh, 1), label: 'km/h média')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: MetricTile(value: formatNumber(ride.avgPowerW), label: 'watts média')),
                  Expanded(child: MetricTile(value: '${formatNumber(ride.gainM)} m', label: 'de subida')),
                  Expanded(child: MetricTile(value: formatNumber(ride.kcal), label: 'kcal')),
                ],
              ),
            ],
          ),
        ),
        if (potencias.length > 1) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Potência ao longo do pedal', style: AppText.suave),
                const SizedBox(height: 8),
                SizedBox(height: 120, child: PowerChart(values: potencias)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: OutlinedButton(
                onPressed: null,
                child: FittedBox(fit: BoxFit.scaleDown, child: Text('Strava · em breve', maxLines: 1)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(onPressed: () => context.go('/inicio'), child: const Text('Concluir')),
            ),
          ],
        ),
      ],
    );
  }
}
