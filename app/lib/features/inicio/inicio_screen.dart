import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../bike/bike_chip.dart';
import '../pedal_livre/pedal_livre_card.dart';
import '../voce/ride_tile.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);
    final rides = ref.watch(recentRidesProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá!', style: AppText.subtitulo),
                      SizedBox(height: 2),
                      Text('Bora pedalar?', style: AppText.titulo),
                    ],
                  ),
                ),
                BikeChip(state: bike),
              ],
            ),
            const SizedBox(height: 16),
            if (!bike.connected) ...[
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth, color: AppColors.destaque),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Conecte sua bike para começar', style: AppText.corpoForte)),
                    FilledButton(onPressed: () => context.push('/bike'), child: const Text('Conectar')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const PedalLivreCard(),
            const SizedBox(height: 14),
            ...rides.when(
              data: (lista) => lista.isEmpty
                  ? const <Widget>[]
                  : [const SectionTitle('Último pedal'), RideTile(ride: lista.first), const SizedBox(height: 14)],
              loading: () => const <Widget>[],
              error: (e, s) => const <Widget>[],
            ),
            const EmBreveCard(
              icon: Icons.map_outlined,
              titulo: 'Rotas do seu bairro',
              texto: 'Criar, gerar e pedalar rotas chega na próxima etapa.',
            ),
            const SizedBox(height: 14),
            const EmBreveCard(
              icon: Icons.emoji_events_outlined,
              titulo: 'Comunidade',
              texto: 'Ranking do bairro e desafio do mês.',
            ),
          ],
        ),
      ),
    );
  }
}
