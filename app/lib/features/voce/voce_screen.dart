import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import 'ride_tile.dart';

class VoceScreen extends ConsumerWidget {
  const VoceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bike = ref.watch(bikeControllerProvider);
    final rides = ref.watch(recentRidesProvider);
    final detalhe = settings.when(
      data: (s) => '${formatNumber(s.pesoKg)} kg · ${bike.connected ? bike.source!.name : 'sem bike conectada'}',
      loading: () => '',
      error: (e, st) => '',
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(color: AppColors.destaqueSuave, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, size: 30, color: AppColors.destaqueTexto),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Você', style: AppText.titulo),
                      Text(detalhe, style: AppText.subtitulo),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/ajustes'),
              icon: const Icon(Icons.tune),
              label: const Text('Ajustes'),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Histórico'),
            ...rides.when(
              data: (lista) => lista.isEmpty
                  ? const [Text('Nenhum pedal ainda. Que tal um pedal livre?', style: AppText.suave)]
                  : [
                      for (final r in lista) ...[RideTile(ride: r), const SizedBox(height: 10)],
                    ],
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (e, st) => [Text('Não consegui ler o histórico: $e', style: AppText.suave)],
            ),
          ],
        ),
      ),
    );
  }
}
