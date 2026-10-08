import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/elevation_chart.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import '../../domain/route_profile.dart';
import '../../domain/route_variant.dart';
import 'ghost_options.dart';
import 'ride_controller.dart';
import 'ride_widgets.dart';

/// Endereço do pedal numa rota, com sentido e começo.
String pedalRotaPath(RideTarget t) {
  final q = [
    if (t.reversed) 'sentido=inverso',
    if (t.startIndex > 0) 'inicio=${t.startIndex}',
    if (t.ghost != null) 'fantasma=${t.ghost!.name}',
  ];
  return '/pedal-rota/${t.routeId}${q.isEmpty ? '' : '?${q.join('&')}'}';
}

/// Antes de pedalar: escolher o sentido e, na volta fechada, onde começar.
class PrepararPedalScreen extends ConsumerWidget {
  const PrepararPedalScreen({super.key, required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rota = ref.watch(routeByIdProvider(routeId));
    return rota.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Não consegui abrir a rota: $e')),
      ),
      data: (r) => r == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Essa rota não existe mais.')),
            )
          : _Preparar(rota: r),
    );
  }
}

class _Preparar extends ConsumerStatefulWidget {
  const _Preparar({required this.rota});

  final RouteRecord rota;

  @override
  ConsumerState<_Preparar> createState() => _PrepararState();
}

class _PrepararState extends ConsumerState<_Preparar> {
  final _map = MapController();
  bool _mapaPronto = false;
  double? _alturaMapa;
  bool _invertido = false;
  int _inicio = 0;

  /// Fantasma preferido; vale só se existir neste sentido (null = sem fantasma).
  GhostKind? _fantasma = GhostKind.recorde;

  List<ProfilePoint> get _original => widget.rota.points;
  bool get _volta => isLoop(_original);
  List<ProfilePoint> get _pontos => routeVariant(_original, reversed: _invertido, startIndex: _inicio);

  /// O painel de baixo cresce quando chegam os pedais do fantasma: o mapa encolhe e
  /// precisa enquadrar a rota de novo.
  void _reenquadrar(double altura, List<LatLng> linha) {
    if (_alturaMapa == altura) return;
    final antes = _alturaMapa;
    _alturaMapa = altura;
    if (antes == null || !_mapaPronto || linha.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _map.fitCamera(
        CameraFit.bounds(bounds: LatLngBounds.fromPoints(linha), padding: const EdgeInsets.all(36), maxZoom: 17),
      );
    });
  }

  void _comecar(GhostKind? fantasma) {
    final conectada = ref.read(bikeControllerProvider).connected;
    if (!conectada) {
      context.push('/bike');
      return;
    }
    context.pushReplacement(
      pedalRotaPath(RideTarget(routeId: widget.rota.id, reversed: _invertido, startIndex: _inicio, ghost: fantasma)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pontos = _pontos;
    final perfil = RouteProfile(pontos);
    final cor = routeColor(widget.rota.colorIndex);
    final linha = [for (final p in pontos) LatLng(p.lat, p.lon)];
    final horarioOriginal = _volta && isClockwise(_original);
    final horario = _invertido ? !horarioOriginal : horarioOriginal;
    final conectada = ref.watch(bikeControllerProvider.select((s) => s.connected));
    final pedais = ref.watch(ghostRidesProvider(widget.rota.id)).value ?? const [];
    final opcoes = ghostOptions(pedais, reversed: _invertido, lapLength: _volta ? perfil.distance : null);
    final fantasma = opcoes.any((o) => o.kind == _fantasma) ? _fantasma : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.rota.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, caixa) {
                _reenquadrar(caixa.maxHeight, linha);
                return FlutterMap(
                  key: const Key('mapa-preparar'),
                  mapController: _map,
                  options: MapOptions(
                    onMapReady: () => _mapaPronto = true,
                    initialCenter: linha.first,
                    initialZoom: 15,
                    initialCameraFit: linha.length < 2
                        ? null
                        : CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(linha),
                            padding: const EdgeInsets.all(36),
                            maxZoom: 17,
                          ),
                    onTap: _volta ? (_, p) => setState(() => _inicio = nearestIndex(_original, toGeo(p))) : null,
                  ),
                  children: [
                    ...baseMapLayers(ref),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: linha,
                          strokeWidth: 6,
                          color: cor,
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: _setas(pontos, perfil, cor)),
                    MarkerLayer(
                      markers: [
                        if (!_volta)
                          Marker(
                            point: linha.last,
                            width: 34,
                            height: 34,
                            child: const _Pino(icone: Icons.sports_score, cor: AppColors.escuro),
                          ),
                        Marker(
                          point: linha.first,
                          width: 34,
                          height: 34,
                          child: _Pino(icone: Icons.flag, cor: cor),
                        ),
                      ],
                    ),
                    mapAttribution,
                  ],
                );
              },
            ),
          ),
          Material(
            color: AppColors.superficie,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(_volta ? Icons.loop : Icons.trending_flat, size: 20, color: cor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _volta ? 'Volta fechada' : 'Ida (de um ponto a outro)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.corpoForte,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${formatKm(perfil.distance)} · ↑ ${formatNumber(perfil.gain)} m · ↓ ${formatNumber(perfil.loss)} m',
                                style: AppText.suave,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(height: 64, child: ElevationChart(profile: perfil)),
                              const SizedBox(height: 10),
                              if (_volta) ...[
                                SegmentedButton<bool>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(value: true, icon: Icon(Icons.rotate_right), label: Text('Horário')),
                                    ButtonSegment(
                                      value: false,
                                      icon: Icon(Icons.rotate_left),
                                      label: Text('Anti-horário'),
                                    ),
                                  ],
                                  selected: {horario},
                                  onSelectionChanged: (v) => setState(() => _invertido = v.first != horarioOriginal),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text('Toque no mapa para escolher onde começar.', style: AppText.suave),
                                    ),
                                    if (_inicio != 0)
                                      TextButton(
                                        onPressed: () => setState(() => _inicio = 0),
                                        child: const Text('Começo original'),
                                      ),
                                  ],
                                ),
                                const Text(
                                  'Ao fechar a volta, o pedal segue para a próxima. Encerre quando quiser.',
                                  style: AppText.suave,
                                ),
                              ] else
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _invertido = !_invertido),
                                  icon: const Icon(Icons.swap_horiz),
                                  label: Text(
                                    _invertido ? 'Sentido invertido · voltar ao original' : 'Inverter sentido',
                                  ),
                                ),
                              if (opcoes.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Row(
                                  children: [
                                    FantasmaPonto(tamanho: 14),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Correr contra o fantasma', style: AppText.corpoForte)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    ChoiceChip(
                                      showCheckmark: false,
                                      label: const Text('Sem fantasma'),
                                      selected: fantasma == null,
                                      onSelected: (_) => setState(() => _fantasma = null),
                                    ),
                                    for (final o in opcoes)
                                      ChoiceChip(
                                        key: Key('fantasma-${o.kind.name}'),
                                        showCheckmark: false,
                                        label: Text('${o.label} · ${formatTime(o.time)}'),
                                        selected: fantasma == o.kind,
                                        onSelected: (_) => setState(() => _fantasma = o.kind),
                                      ),
                                  ],
                                ),
                                Text(
                                  _volta
                                      ? 'A bolinha roxa refaz essa volta, de novo a cada volta.'
                                      : 'A bolinha roxa refaz aquele pedal, no mesmo ritmo.',
                                  style: AppText.suave,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _comecar(fantasma),
                        icon: Icon(conectada ? Icons.play_arrow : Icons.bluetooth),
                        label: Text(conectada ? 'Começar pedal' : 'Conectar a bike para começar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Setinhas do sentido, espalhadas pela rota.
List<Marker> _setas(List<ProfilePoint> pontos, RouteProfile perfil, Color cor) {
  if (pontos.length < 3 || perfil.distance <= 0) return const [];
  const quantas = 7;
  final marcas = <Marker>[];
  for (var k = 1; k <= quantas; k++) {
    final d = perfil.distance * k / (quantas + 1);
    final a = perfil.positionAt(math.max(0, d - 10));
    final b = perfil.positionAt(math.min(perfil.distance, d + 10));
    final rumo = math.atan2((b.lon - a.lon) * math.cos(a.lat * math.pi / 180), b.lat - a.lat);
    final aqui = perfil.positionAt(d);
    marcas.add(
      Marker(
        point: LatLng(aqui.lat, aqui.lon),
        width: 22,
        height: 22,
        child: Transform.rotate(
          angle: rumo,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: cor, width: 2),
            ),
            child: Icon(Icons.arrow_upward, size: 14, color: cor),
          ),
        ),
      ),
    );
  }
  return marcas;
}

class _Pino extends StatelessWidget {
  const _Pino({required this.icone, required this.cor});

  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: cor, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Icon(icone, size: 18, color: cor),
    );
  }
}
