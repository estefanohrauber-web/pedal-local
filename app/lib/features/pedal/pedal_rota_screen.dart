import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../bike/bike_controller.dart';
import '../../bike/sim_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/elevation_chart.dart';
import '../../domain/ride_session.dart';
import '../pedal_livre/pedal_livre_screen.dart';
import 'ride_controller.dart';
import 'ride_widgets.dart';

const _alertaVisivel = Duration(seconds: 8);

class PedalRotaScreen extends ConsumerStatefulWidget {
  const PedalRotaScreen({super.key, required this.target});

  final RideTarget target;

  @override
  ConsumerState<PedalRotaScreen> createState() => _PedalRotaScreenState();
}

class _PedalRotaScreenState extends ConsumerState<PedalRotaScreen> {
  final _map = MapController();
  bool _mapaPronto = false;
  bool _encerrando = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rideProvider(widget.target).notifier).start());
  }

  Future<void> _finalizar() async {
    if (_encerrando) return;
    setState(() => _encerrando = true);
    final id = await ref.read(rideProvider(widget.target).notifier).finish();
    if (!mounted) return;
    final gap = ref.read(rideProvider(widget.target)).ghostGapS;
    context.go('/resumo/$id?novo=1${gap == null ? '' : '&fantasma=${gap.toStringAsFixed(1)}'}');
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
    if (await confirmarEncerrar(context)) await _finalizar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = rideProvider(widget.target);
    final v = ref.watch(provider);
    ref.listen(provider, (anterior, proximo) {
      if (proximo.state == RideState.concluido && anterior?.state != RideState.concluido) _finalizar();
      final pos = proximo.position;
      if (pos != null && _mapaPronto) _map.move(toLatLng(pos), _map.camera.zoom);
    });

    if (v.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Essa rota não existe mais.', style: AppText.corpoForte)),
      );
    }

    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(provider.notifier);
    final perfil = v.profile;
    String? textoAlerta;
    final volta = v.lapAlert;
    final textoVolta = volta != null && clock.now().difference(volta.at) < _alertaVisivel
        ? 'Volta ${volta.number} concluída em ${formatTime(volta.time)}! Seguindo para a volta ${volta.number + 1}.'
        : null;
    final alerta = v.alert;
    final quando = v.alertAt;
    if (alerta != null && quando != null && clock.now().difference(quando) < _alertaVisivel) {
      textoAlerta = alerta.kind == AlertKind.subida
          ? 'Subida de ${formatNumber(alerta.grade * 100)}% chegando: aumente a carga'
          : 'Descida chegando: pode aliviar';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _encerrar();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.routeName ?? 'Rota',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            v.isLoop
                                ? 'Volta ${v.lap} · ${formatKm(v.lapDistance)} de ${formatKm(v.lapLength!)}'
                                : v.total.isFinite
                                ? '${formatKm(v.distance)} de ${formatKm(v.total)}'
                                : '',
                            style: AppText.suave,
                          ),
                        ],
                      ),
                    ),
                    if (v.started) BotaoVoz(ligada: v.voiceOn, onTap: ctrl.toggleVoice),
                    OutlinedButton(onPressed: _encerrar, child: const Text('Encerrar')),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: perfil == null
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                            children: [
                              FlutterMap(
                                mapController: _map,
                                options: MapOptions(
                                  initialCenter: toLatLng(perfil.positionAt(0)),
                                  initialZoom: 16,
                                  onMapReady: () => _mapaPronto = true,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                                  ),
                                ),
                                children: [
                                  ...baseMapLayers(ref),
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: [for (final p in perfil.points) toLatLng(p)],
                                        strokeWidth: 7,
                                        color: AppColors.destaque.withValues(alpha: 0.3),
                                      ),
                                      Polyline(
                                        points: [for (final p in perfil.traveled(v.lapDistance)) toLatLng(p)],
                                        strokeWidth: 7,
                                        color: AppColors.destaque,
                                      ),
                                    ],
                                  ),
                                  if (v.ghostPosition != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: toLatLng(v.ghostPosition!),
                                          width: 26,
                                          height: 26,
                                          child: const FantasmaPonto(key: Key('fantasma-no-mapa')),
                                        ),
                                      ],
                                    ),
                                  if (v.position != null)
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: LatLng(v.position!.lat, v.position!.lon),
                                          radius: 10,
                                          color: AppColors.posicao,
                                          borderColor: Colors.white,
                                          borderStrokeWidth: 3,
                                        ),
                                      ],
                                    ),
                                  mapAttribution,
                                ],
                              ),
                              if (v.ghostGapS != null)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  right: 10,
                                  child: Center(child: FantasmaChip(gapS: v.ghostGapS!)),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (v.pausedByBike)
                      AvisoFaixa(
                        texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                        acao: 'Reconectar',
                        onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                      )
                    else if (textoVolta != null)
                      AvisoFaixa(icone: Icons.flag, texto: textoVolta)
                    else if (textoAlerta != null)
                      AvisoFaixa(icone: Icons.terrain, texto: textoAlerta)
                    else if (v.state == RideState.pausado)
                      const AvisoFaixa(texto: 'Pedal pausado. Toque em Continuar para seguir.'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatNumber(v.speedKmh, 1),
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.destaque,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const Text('km/h', style: AppText.suave),
                              ],
                            ),
                          ),
                          MetricTile(value: '${formatNumber(v.grade * 100, 1)}%', label: 'inclinação'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: MetricTile(value: formatNumber(v.power), label: 'watts'),
                          ),
                          Expanded(
                            child: MetricTile(value: formatNumber(v.cadence), label: 'rpm'),
                          ),
                          Expanded(
                            child: MetricTile(value: formatTime(v.movingTime), label: 'tempo'),
                          ),
                        ],
                      ),
                    ),
                    if (perfil != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 70,
                        child: ElevationChart(profile: perfil, marker: v.lapDistance),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (source is SimSource) SimControls(source: source),
                    RideControls(
                      level: v.level,
                      paused: v.state == RideState.pausado,
                      enabled: v.started && !_encerrando,
                      onLevel: ctrl.changeLevel,
                      onPause: ctrl.togglePause,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
