import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';

class RouteTile extends ConsumerWidget {
  const RouteTile({super.key, required this.route, this.canDelete = true, this.selected = false, this.onSelect});

  final RouteRecord route;

  /// No Início o cartão é só um atalho; apagar fica no Explorar.
  final bool canDelete;

  /// Rota em destaque no mapa do Explorar (borda na cor dela).
  final bool selected;

  /// Tocar no cartão destaca (ou solta) a rota no mapa.
  final VoidCallback? onSelect;

  Future<void> _apagar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar a rota?'),
        content: Text('“${route.name}” some da sua lista. Os pedais já feitos continuam no histórico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(routesStoreProvider).delete(route.id);
    ref.invalidate(routesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(bikeControllerProvider.select((s) => s.connected));
    final cor = routeColor(route.colorIndex);
    return AppCard(
      onTap: onSelect,
      borderColor: selected ? cor : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: cor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.route, color: cor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.name, style: AppText.corpoForte, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${formatKm(route.distanceM)} · ↑ ${formatNumber(route.gainM)} m · ↓ ${formatNumber(route.lossM)} m',
                      style: AppText.suave,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Apagar rota',
                  onPressed: () => _apagar(context, ref),
                  icon: const Icon(Icons.delete_outline, color: AppColors.textoSuave),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () => context.push(connected ? '/pedal-rota/${route.id}' : '/bike'),
              icon: const Icon(Icons.directions_bike),
              label: const Text('Pedalar esta rota'),
            ),
          ),
        ],
      ),
    );
  }
}
