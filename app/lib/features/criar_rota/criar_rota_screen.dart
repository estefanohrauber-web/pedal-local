import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/elevation_chart.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import '../../data/services/routing_service.dart';
import '../../domain/geo.dart';
import '../../domain/route_profile.dart';
import '../pedal/ride_widgets.dart';

class CriarRotaScreen extends ConsumerStatefulWidget {
  const CriarRotaScreen({super.key});

  @override
  ConsumerState<CriarRotaScreen> createState() => _CriarRotaScreenState();
}

class _CriarRotaScreenState extends ConsumerState<CriarRotaScreen> {
  final _map = MapController();
  final _nome = TextEditingController();
  final List<GeoPoint> _pontos = [];
  RouteRecord? _rota;
  RouteProfile? _perfil;
  bool _plana = false;
  bool _calculando = false;
  bool _mapaPronto = false;
  bool _semLocalizacao = false;
  GeoPoint? _centroPendente;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _localizar();
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _localizar() async {
    final aqui = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    if (aqui == null) {
      setState(() => _semLocalizacao = true);
      return;
    }
    setState(() => _semLocalizacao = false);
    if (_mapaPronto) {
      _map.move(toLatLng(aqui), 16);
    } else {
      _centroPendente = aqui;
    }
  }

  void _quandoMapaPronto() {
    _mapaPronto = true;
    final p = _centroPendente;
    if (p != null) _map.move(toLatLng(p), 16);
  }

  void _mudou(void Function() alteracao) {
    setState(() {
      alteracao();
      _rota = null;
      _perfil = null;
      _erro = null;
    });
  }

  void _tocar(LatLng p) => _mudou(() => _pontos.add(toGeo(p)));

  void _desfazer() => _mudou(_pontos.removeLast);

  void _fecharVolta() => _mudou(() => _pontos.add(_pontos.first));

  Future<void> _calcular() async {
    setState(() {
      _calculando = true;
      _erro = null;
    });
    try {
      final built = await ref.read(routeBuilderProvider).build(List.of(_pontos));
      if (!mounted) return;
      setState(() {
        _rota = built.route;
        _perfil = RouteProfile(built.route.points);
        _plana = built.flat;
      });
      final pts = [for (final p in built.route.points) LatLng(p.lat, p.lon)];
      if (pts.length >= 2) {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(40),
          maxZoom: 17,
        ));
      }
    } on RouteException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro ao calcular a rota: $e');
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  Future<void> _salvar() async {
    final rota = _rota;
    if (rota == null) return;
    final digitado = _nome.text.trim();
    final nome = digitado.isEmpty ? 'Rota de ${formatDate(DateTime.now())}' : digitado;
    await ref.read(routesStoreProvider).upsert(rota.copyWith(name: nome));
    ref.invalidate(routesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rota “$nome” salva')));
    context.pop();
  }

  String get _dica {
    if (_pontos.isEmpty) return 'Toque no mapa para marcar o início.';
    if (_pontos.length == 1) return 'Agora toque nos próximos pontos do caminho.';
    return '${_pontos.length} pontos. Quando terminar, toque em Calcular rota.';
  }

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    final perfil = _perfil;
    final podeFechar = _pontos.length >= 2 && _pontos.first != _pontos.last;
    return Scaffold(
      appBar: AppBar(title: const Text('Nova rota')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  key: const Key('mapa-criar-rota'),
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: toLatLng(defaultMapCenter),
                    initialZoom: 13,
                    onTap: (_, p) => _tocar(p),
                    onMapReady: _quandoMapaPronto,
                  ),
                  children: [
                    ...baseMapLayers(ref),
                    if (rota != null)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [for (final p in rota.points) LatLng(p.lat, p.lon)],
                          strokeWidth: 6,
                          color: AppColors.destaque,
                        ),
                      ])
                    else if (_pontos.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [for (final p in _pontos) toLatLng(p)],
                          strokeWidth: 3,
                          color: AppColors.destaque.withValues(alpha: 0.7),
                          pattern: StrokePattern.dashed(segments: const [10, 8]),
                        ),
                      ]),
                    CircleLayer(circles: [
                      for (var i = 0; i < _pontos.length; i++)
                        CircleMarker(
                          point: toLatLng(_pontos[i]),
                          radius: i == 0 ? 9 : 7,
                          color: i == 0 ? AppColors.destaque : Colors.white,
                          borderColor: AppColors.destaque,
                          borderStrokeWidth: 3,
                        ),
                    ]),
                    mapAttribution,
                  ],
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _Ferramenta(icone: Icons.undo, rotulo: 'Desfazer', onTap: _pontos.isEmpty ? null : _desfazer),
                      const SizedBox(height: 8),
                      _Ferramenta(icone: Icons.loop, rotulo: 'Fechar volta', onTap: podeFechar ? _fecharVolta : null),
                      const SizedBox(height: 8),
                      _Ferramenta(icone: Icons.my_location, rotulo: 'Onde estou', onTap: _localizar),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.superficie,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_erro != null) AvisoFaixa(texto: _erro!),
                    if (rota == null || perfil == null) ...[
                      Text(_dica, style: AppText.corpoForte),
                      if (_semLocalizacao)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Sem localização: arraste o mapa até o seu bairro.',
                            style: AppText.suave,
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _pontos.length >= 2 && !_calculando ? _calcular : null,
                        child: Text(_calculando ? 'Calculando…' : 'Calcular rota'),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(formatKm(rota.distanceM), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '↑ ${formatNumber(rota.gainM)} m · ↓ ${formatNumber(rota.lossM)} m',
                              textAlign: TextAlign.end,
                              style: AppText.suave,
                            ),
                          ),
                        ],
                      ),
                      if (_plana)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: AvisoFaixa(texto: 'Não consegui a altimetria: a rota ficou plana.'),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(height: 70, child: ElevationChart(profile: perfil)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nome,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Nome da rota', hintText: 'Volta do bairro'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(onPressed: _salvar, child: const Text('Salvar rota')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ferramenta extends StatelessWidget {
  const _Ferramenta({required this.icone, required this.rotulo, required this.onTap});

  final IconData icone;
  final String rotulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: AppColors.superficie,
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 72,
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: AppColors.texto),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(rotulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
