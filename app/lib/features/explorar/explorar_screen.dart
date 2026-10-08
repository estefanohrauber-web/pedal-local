import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import 'route_tile.dart';

class ExplorarScreen extends ConsumerWidget {
  const ExplorarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Explorar', style: AppText.titulo)),
                FilledButton.icon(
                  onPressed: () => context.push('/criar-rota'),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar rota'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...routes.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (e, s) => [Text('Não consegui ler as rotas: $e', style: AppText.suave)],
              data: (lista) => lista.isEmpty
                  ? const [_SemRotas()]
                  : [
                      SizedBox(
                        height: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _MapaDasRotas(rotas: lista),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionTitle('Minhas rotas'),
                      for (final r in lista) ...[RouteTile(route: r), const SizedBox(height: 10)],
                    ],
            ),
            const SizedBox(height: 10),
            const EmBreveCard(
              icon: Icons.terrain_outlined,
              titulo: 'Subidas e desafios do bairro',
              texto: 'Ranking das ladeiras e desafio do mês.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SemRotas extends StatelessWidget {
  const _SemRotas();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.map_outlined, size: 48, color: AppColors.destaque),
          const SizedBox(height: 12),
          const Text('Nenhuma rota ainda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Marque um caminho no seu bairro tocando no mapa. O app traça pelas ruas e mostra as subidas.',
            textAlign: TextAlign.center,
            style: AppText.suave,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => context.push('/criar-rota'),
            child: const Text('Criar minha primeira rota'),
          ),
        ],
      ),
    );
  }
}

class _MapaDasRotas extends ConsumerWidget {
  const _MapaDasRotas({required this.rotas});

  final List<RouteRecord> rotas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = [
      for (final r in rotas)
        for (final p in r.points) LatLng(p.lat, p.lon),
    ];
    return FlutterMap(
      options: MapOptions(
        initialCenter: todos.isEmpty ? toLatLng(defaultMapCenter) : todos.first,
        initialZoom: 14,
        initialCameraFit: todos.length < 2
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(todos),
                padding: const EdgeInsets.all(28),
                maxZoom: 17,
              ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        ...baseMapLayers(ref),
        PolylineLayer(
          polylines: [
            for (final r in rotas)
              Polyline(
                points: [for (final p in r.points) LatLng(p.lat, p.lon)],
                strokeWidth: 5,
                color: AppColors.destaque,
              ),
          ],
        ),
        mapAttribution,
      ],
    );
  }
}
