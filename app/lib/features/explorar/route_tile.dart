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
  const RouteTile({super.key, required this.route});

  final RouteRecord route;

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
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.route, color: AppColors.destaqueTexto),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.name, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${formatKm(route.distanceM)} · ↑ ${formatNumber(route.gainM)} m', style: AppText.suave),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Apagar rota',
            onPressed: () => _apagar(context, ref),
            icon: const Icon(Icons.delete_outline, color: AppColors.textoSuave),
          ),
          FilledButton(
            onPressed: () => context.push(connected ? '/pedal-rota/${route.id}' : '/bike'),
            child: const Text('Pedalar'),
          ),
        ],
      ),
    );
  }
}
