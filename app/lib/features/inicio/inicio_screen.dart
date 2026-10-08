import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../bike/bike_chip.dart';
import '../explorar/route_tile.dart';
import '../pedal_livre/pedal_livre_card.dart';
import '../voce/ride_tile.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);
    final rides = ref.watch(recentRidesProvider);
    final nome = ref.watch(settingsProvider).when(data: (s) => s.nome?.trim() ?? '', loading: () => '', error: (e, s) => '');
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome.isEmpty ? 'Olá!' : 'Olá, $nome!',
                        style: AppText.subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text('Bora pedalar?', style: AppText.titulo),
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
            const _RotaCard(),
            const SizedBox(height: 14),
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

/// A rota mais recente com atalho para pedalar, ou o convite para criar a primeira.
class _RotaCard extends ConsumerWidget {
  const _RotaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    return routes.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (lista) {
        if (lista.isEmpty) {
          return AppCard(
            onTap: () => context.push('/criar-rota'),
            child: const Row(
              children: [
                Icon(Icons.map_outlined, color: AppColors.destaque, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crie sua primeira rota', style: AppText.corpoForte),
                      Text('Marque um caminho no seu bairro e pedale nele.', style: AppText.suave),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textoSuave),
              ],
            ),
          );
        }
        return RouteTile(route: lista.first, canDelete: false);
      },
    );
  }
}
