import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/bandeira.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import '../../data/settings_store.dart';
import '../../domain/stats.dart';
import '../pedal/ride_widgets.dart';

/// Início: o pedal de hoje. A última rota pedalada com o recorde para bater, a meta da semana e o
/// pedal livre; a bike e os Ajustes ficam na barra fixa do topo.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final nome = settings.nome?.trim() ?? '';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Text(nome.isEmpty ? 'Olá!' : 'Olá, $nome!', style: AppText.subtitulo),
            const Text('Bora pedalar?', style: AppText.titulo),
            const SizedBox(height: 16),
            const _PedalarDeNovo(),
            const SizedBox(height: 12),
            _MetaDaSemana(metaKm: settings.metaSemanalKm),
            const SizedBox(height: 12),
            const _PedalLivre(),
          ],
        ),
      ),
    );
  }
}

/// A rota do último pedal (ou a mais nova), com o mapa e o recorde; sem rota, o convite.
class _PedalarDeNovo extends ConsumerWidget {
  const _PedalarDeNovo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rotas = ref.watch(routesProvider).value;
    final pedais = ref.watch(recentRidesProvider).value;
    if (rotas == null || pedais == null) return const SizedBox(height: 280);
    if (rotas.isEmpty) {
      return AppCard(
        onTap: () => context.push('/criar-rota'),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.map_outlined, color: AppColors.destaqueTexto),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crie sua primeira rota', style: AppText.corpoForte),
                  Text('Marque um caminho no seu bairro e pedale nele.', style: AppText.suave),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textoSuave),
          ],
        ),
      );
    }
    final ultima = pedais.where((p) => p.routeId != null).firstOrNull?.routeId;
    final rota = rotas.where((r) => r.id == ultima).firstOrNull ?? rotas.first;
    final idas = ref.watch(ridesForRouteProvider(rota.id)).value ?? const [];
    final tempos = [
      for (final p in idas)
        if (p.completed && !p.loop && !p.reversed) p.movingTimeS,
    ];
    final recorde = tempos.isEmpty ? null : tempos.reduce((a, b) => a < b ? a : b);
    final cor = routeColor(rota.colorIndex);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.superficie,
        border: Border.all(color: AppColors.borda),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 150, child: _MapaDaRota(rota: rota, cor: cor)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(rota.name, style: AppText.secao, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('${formatKm(rota.distanceM)} · ${formatNumber(rota.gainM)} m', style: AppText.suave),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const FantasmaPonto(tamanho: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recorde == null
                            ? 'Pedale uma vez e o fantasma corre junto na próxima.'
                            : 'Seu recorde: ${formatTime(recorde)}. Bora bater?',
                        style: AppText.suave,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/rota/${rota.id}/preparar'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(recorde == null ? 'Pedalar esta rota' : 'Pedalar de novo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapaDaRota extends ConsumerWidget {
  const _MapaDaRota({required this.rota, required this.cor});

  final RouteRecord rota;
  final Color cor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linha = [for (final p in rota.points) LatLng(p.lat, p.lon)];
    if (linha.length < 2) return const ColoredBox(color: AppColors.neutro);
    return FlutterMap(
      key: const Key('mapa-inicio'),
      options: MapOptions(
        initialCenter: linha.first,
        initialZoom: 15,
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(linha),
          padding: const EdgeInsets.all(22),
          maxZoom: 17,
        ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        ...baseMapLayers(ref),
        PolylineLayer(
          polylines: [
            Polyline(points: linha, strokeWidth: 9, color: Colors.white),
            Polyline(points: linha, strokeWidth: 5, color: cor),
          ],
        ),
        MarkerLayer(markers: [Marker(point: linha.first, width: 18, height: 18, child: const PontoDeSaida())]),
        mapAttribution,
      ],
    );
  }
}

/// Os km da semana contra a meta, numa barra.
class _MetaDaSemana extends ConsumerWidget {
  const _MetaDaSemana({required this.metaKm});

  final double metaKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(rideStatsProvider).value ?? const <RideStat>[];
    final km = summarize(stats, from: weekStart(DateTime.now())).distanceM / 1000;
    final fracao = metaKm <= 0 ? 0.0 : (km / metaKm).clamp(0.0, 1.0);
    return AppCard(
      onTap: () => context.go('/voce'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Esta semana', style: AppText.corpoForte)),
              Text(
                metaKm > 0 && km >= metaKm
                    ? 'Meta batida!'
                    : '${formatNumber(km, 1)} de ${formatNumber(metaKm)} km',
                style: AppText.suave,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fracao,
              minHeight: 8,
              backgroundColor: AppColors.destaqueSuave,
              color: AppColors.destaque,
            ),
          ),
        ],
      ),
    );
  }
}

class _PedalLivre extends ConsumerWidget {
  const _PedalLivre();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectada = ref.watch(bikeControllerProvider.select((s) => s.connected));
    return AppCard(
      onTap: () => context.push(conectada ? '/pedal-livre' : '/bike'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.neutro, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.speed, color: AppColors.textoSuave),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pedal livre', style: AppText.corpoForte),
                Text('Só os dados da bike, sem mapa', style: AppText.suave),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textoSuave),
        ],
      ),
    );
  }
}
