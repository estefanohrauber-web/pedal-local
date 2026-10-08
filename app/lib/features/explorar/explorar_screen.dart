import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import 'route_tile.dart';

class ExplorarScreen extends ConsumerStatefulWidget {
  const ExplorarScreen({super.key});

  @override
  ConsumerState<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends ConsumerState<ExplorarScreen> {
  final _scroll = ScrollController();

  /// Rota em destaque no mapa (null = todas iguais).
  String? _foco;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _focar(String? id) => setState(() => _foco = id);

  /// Pelo cartão: alterna o destaque e sobe a lista para o mapa aparecer.
  void _focarPeloCartao(String id) {
    _focar(_foco == id ? null : id);
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _scroll,
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
                        height: 240,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _MapaDasRotas(rotas: lista, foco: _foco, onFoco: _focar),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionTitle('Minhas rotas'),
                      for (final r in lista) ...[
                        RouteTile(route: r, selected: r.id == _foco, onSelect: () => _focarPeloCartao(r.id)),
                        const SizedBox(height: 10),
                      ],
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

/// Todas as rotas, cada uma na sua cor. Tocar numa linha (ou no cartão dela) põe a rota
/// em destaque: por cima, mais grossa, e as outras apagadas.
class _MapaDasRotas extends ConsumerStatefulWidget {
  const _MapaDasRotas({required this.rotas, required this.foco, required this.onFoco});

  final List<RouteRecord> rotas;
  final String? foco;
  final ValueChanged<String?> onFoco;

  @override
  ConsumerState<_MapaDasRotas> createState() => _MapaDasRotasState();
}

class _MapaDasRotasState extends ConsumerState<_MapaDasRotas> {
  final _map = MapController();
  final LayerHitNotifier<String> _toque = ValueNotifier(null);
  bool _pronto = false;

  @override
  void dispose() {
    _toque.dispose();
    super.dispose();
  }

  RouteRecord? get _focada {
    for (final r in widget.rotas) {
      if (r.id == widget.foco) return r;
    }
    return null;
  }

  List<LatLng> _pontosVisiveis() {
    final focada = _focada;
    return [
      for (final r in focada == null ? widget.rotas : [focada])
        for (final p in r.points) LatLng(p.lat, p.lon),
    ];
  }

  CameraFit? _enquadramento() {
    final pts = _pontosVisiveis();
    if (pts.length < 2) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
      maxZoom: 17,
    );
  }

  @override
  void didUpdateWidget(covariant _MapaDasRotas old) {
    super.didUpdateWidget(old);
    final mudou = old.foco != widget.foco || old.rotas.length != widget.rotas.length;
    final fit = _enquadramento();
    if (mudou && _pronto && fit != null) _map.fitCamera(fit);
  }

  /// Toque numa linha: destaca a de cima; tocando de novo onde rotas se cruzam, passa para a de baixo.
  void _tocouLinha() {
    final ids = _toque.value?.hitValues ?? const <String>[];
    if (ids.isEmpty) return;
    final atual = ids.indexOf(widget.foco ?? '');
    widget.onFoco(atual < 0 ? ids.first : ids[(atual + 1) % ids.length]);
  }

  @override
  Widget build(BuildContext context) {
    final focada = _focada;
    final pts = _pontosVisiveis();
    // Maiores embaixo, para as curtas não sumirem; a destacada sempre por cima.
    final ordem = [...widget.rotas]..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    if (focada != null) {
      ordem
        ..remove(focada)
        ..add(focada);
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: pts.isEmpty ? toLatLng(defaultMapCenter) : pts.first,
            initialZoom: 14,
            initialCameraFit: _enquadramento(),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            onMapReady: () => _pronto = true,
            onTap: (_, _) => widget.onFoco(null),
          ),
          children: [
            ...baseMapLayers(ref),
            GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: _tocouLinha,
              child: PolylineLayer<String>(
                hitNotifier: _toque,
                polylines: [
                  for (final r in ordem) _linha(r, destaque: r == focada, apagada: focada != null && r != focada),
                ],
              ),
            ),
            if (focada != null && focada.points.isNotEmpty)
              CircleLayer(circles: [
                CircleMarker(
                  point: LatLng(focada.points.first.lat, focada.points.first.lon),
                  radius: 7,
                  color: routeColor(focada.colorIndex),
                  borderColor: Colors.white,
                  borderStrokeWidth: 2.5,
                ),
              ]),
            mapAttribution,
          ],
        ),
        Positioned(
          left: 10,
          top: 10,
          right: 10,
          child: Align(
            alignment: Alignment.centerLeft,
            child: focada != null
                ? _EtiquetaDestaque(rota: focada, onFechar: () => widget.onFoco(null))
                : widget.rotas.length > 1
                    ? const _Dica('Toque numa rota para destacar')
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Polyline<String> _linha(RouteRecord r, {required bool destaque, required bool apagada}) {
    final cor = routeColor(r.colorIndex);
    return Polyline<String>(
      points: [for (final p in r.points) LatLng(p.lat, p.lon)],
      hitValue: r.id,
      strokeWidth: destaque ? 6 : (apagada ? 3 : 4),
      color: apagada ? cor.withValues(alpha: 0.5) : cor,
      borderStrokeWidth: apagada ? 0 : (destaque ? 2 : 1.5),
      borderColor: Colors.white,
    );
  }
}

/// Nome da rota em destaque, com ✕ para voltar a ver todas.
class _EtiquetaDestaque extends StatelessWidget {
  const _EtiquetaDestaque({required this.rota, required this.onFechar});

  final RouteRecord rota;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: routeColor(rota.colorIndex), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${rota.name} · ${formatKm(rota.distanceM)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.corpoForte,
              ),
            ),
            IconButton(
              tooltip: 'Mostrar todas',
              visualDensity: VisualDensity.compact,
              onPressed: onFechar,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dica extends StatelessWidget {
  const _Dica(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(999)),
      child: Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textoSuave)),
    );
  }
}
