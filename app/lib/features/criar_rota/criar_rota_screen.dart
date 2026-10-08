import 'dart:async';

import 'package:flutter/gestures.dart';
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
import '../../data/route_builder.dart';
import '../../data/routes_store.dart';
import '../../data/services/geocoding_service.dart';
import '../../data/services/routing_service.dart';
import '../../domain/geo.dart';
import '../../domain/route_profile.dart';
import '../../domain/waypoint_editor.dart';
import '../pedal/ride_widgets.dart';
import 'gerar_volta_sheet.dart';

/// Espera depois da última mudança antes de traçar de novo (o serviço aceita 1 pedido por segundo).
const recalcDelay = Duration(milliseconds: 800);

class CriarRotaScreen extends ConsumerStatefulWidget {
  const CriarRotaScreen({super.key});

  @override
  ConsumerState<CriarRotaScreen> createState() => _CriarRotaScreenState();
}

class _CriarRotaScreenState extends ConsumerState<CriarRotaScreen> {
  final _map = MapController();
  final _mapaKey = GlobalKey();
  final _nome = TextEditingController();
  final _busca = TextEditingController();
  final _editor = WaypointEditor();
  RouteRecord? _rota;
  RouteProfile? _perfil;
  bool _plana = false;
  bool _calculando = false;
  bool _desatualizada = false;
  bool _mapaPronto = false;
  bool _enquadrou = false;
  bool _semLocalizacao = false;
  int? _arrastando;
  int _versao = 0;
  Timer? _espera;
  Timer? _esperaBusca;
  GeoPoint? _centroPendente;
  String? _erro;
  List<Place> _resultados = const [];
  String? _erroBusca;
  Place? _achado;

  @override
  void initState() {
    super.initState();
    _localizar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _esperaBusca?.cancel();
    _nome.dispose();
    _busca.dispose();
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

  /// Os pontos mudaram: a rota mostrada fica desatualizada e é traçada de novo daqui a pouco.
  void _mudou(void Function() alteracao) {
    setState(() {
      alteracao();
      _erro = null;
      _desatualizada = _rota != null;
      if (_editor.points.length < 2) {
        _rota = null;
        _perfil = null;
      }
    });
    _espera?.cancel();
    if (_editor.points.length >= 2) _espera = Timer(recalcDelay, _calcular);
  }

  void _tocar(LatLng p) {
    if (_arrastando != null) return;
    FocusScope.of(context).unfocus();
    _mudou(() => _editor.add(toGeo(p)));
  }

  Future<void> _calcular() async {
    final versao = ++_versao;
    setState(() {
      _calculando = true;
      _erro = null;
    });
    try {
      final built = await ref.read(routeBuilderProvider).build(_editor.points);
      if (!mounted || versao != _versao) return;
      setState(() {
        _rota = built.route;
        _perfil = RouteProfile(built.route.points);
        _plana = built.flat;
        _desatualizada = false;
      });
      if (!_enquadrou) _enquadrar();
    } on RouteException catch (e) {
      if (mounted && versao == _versao) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted && versao == _versao) setState(() => _erro = 'Erro ao calcular a rota: $e');
    } finally {
      if (mounted && versao == _versao) setState(() => _calculando = false);
    }
  }

  /// Mostra a rota inteira. Depois do quadro: o painel de baixo cresce com os números da
  /// rota e o mapa encolhe.
  void _enquadrar() {
    final pts = [
      for (final p in _rota?.points ?? const <ProfilePoint>[]) LatLng(p.lat, p.lon),
      for (final p in _editor.points) toLatLng(p),
    ];
    if (pts.length < 2) return;
    _enquadrou = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapaPronto) return;
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.fromLTRB(40, 96, 40, 84),
          maxZoom: 17,
        ),
      );
    });
  }

  /// Volta automática: sai do primeiro ponto marcado ou do centro do mapa.
  Future<void> _gerarVolta() async {
    FocusScope.of(context).unfocus();
    final pontos = _editor.points;
    final saida = pontos.isNotEmpty ? pontos.first : (_mapaPronto ? toGeo(_map.camera.center) : null);
    if (saida == null) return;
    final escolhida = await showModalBottomSheet<BuiltRoute>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GerarVoltaSheet(
        saida: saida,
        doPrimeiroPonto: pontos.isNotEmpty,
        trocaPontos: pontos.length >= 2,
      ),
    );
    if (escolhida == null || !mounted) return;
    _espera?.cancel();
    _versao++; // descarta um traçado que ainda esteja a caminho
    setState(() {
      _editor.replaceAll(escolhida.route.waypoints);
      _rota = escolhida.route;
      _perfil = RouteProfile(escolhida.route.points);
      _plana = escolhida.flat;
      _desatualizada = false;
      _calculando = false;
      _erro = null;
      _achado = null;
    });
    _enquadrar();
  }

  Future<void> _salvar() async {
    final rota = _rota;
    if (rota == null) return;
    final digitado = _nome.text.trim();
    final nome = digitado.isEmpty ? 'Rota de ${formatDate(DateTime.now())}' : digitado;
    final store = ref.read(routesStoreProvider);
    final cor = nextRouteColor(await store.all());
    await store.upsert(rota.copyWith(name: nome, colorIndex: cor));
    ref.invalidate(routesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rota “$nome” salva')));
    context.pop();
  }

  // --- arrastar e apagar pontos ---

  GeoPoint? _noMapa(Offset global) {
    final caixa = _mapaKey.currentContext?.findRenderObject() as RenderBox?;
    if (caixa == null) return null;
    return toGeo(_map.camera.screenOffsetToLatLng(caixa.globalToLocal(global)));
  }

  void _comecaArrasto(int i) {
    _editor.beginDrag();
    setState(() => _arrastando = i);
  }

  void _arrasta(int i, Offset global) {
    final p = _noMapa(global);
    if (p == null) return;
    setState(() => _editor.dragTo(i, p));
  }

  void _soltaArrasto() {
    setState(() => _arrastando = null);
    _mudou(() {});
  }

  void _apagar(int i) {
    _mudou(() => _editor.remove(i));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Ponto apagado'),
          action: SnackBarAction(label: 'Desfazer', onPressed: () => _mudou(() => _editor.undo())),
        ),
      );
  }

  // --- busca de endereço ---

  void _digitou(String texto) {
    _esperaBusca?.cancel();
    if (texto.trim().length < 3) {
      setState(() {
        _resultados = const [];
        _erroBusca = null;
      });
      return;
    }
    _esperaBusca = Timer(const Duration(milliseconds: 600), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    final perto = _mapaPronto ? toGeo(_map.camera.center) : null;
    try {
      final lugares = await ref.read(geocodingServiceProvider).search(texto, near: perto);
      if (!mounted || _busca.text != texto) return;
      setState(() {
        _resultados = lugares;
        _erroBusca = lugares.isEmpty ? 'Nada encontrado.' : null;
      });
    } on GeocodingException catch (e) {
      if (mounted) setState(() => _erroBusca = e.message);
    }
  }

  void _escolher(Place p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _achado = p;
      _resultados = const [];
      _erroBusca = null;
    });
    _map.move(toLatLng(p.point), 16);
  }

  void _adicionarAchado() {
    final p = _achado;
    if (p == null) return;
    _mudou(() {
      _editor.add(p.point);
      _achado = null;
    });
  }

  void _limparBusca() {
    _busca.clear();
    setState(() {
      _resultados = const [];
      _erroBusca = null;
      _achado = null;
    });
  }

  String get _dica {
    final n = _editor.points.length;
    if (n == 0) return 'Toque no mapa para marcar o início, busque um endereço ou gere uma volta.';
    if (n == 1) return 'Agora toque nos próximos pontos do caminho.';
    return 'Arraste um ponto para mudar o caminho; segure o dedo nele para apagar.';
  }

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    final perfil = _perfil;
    final pontos = _editor.points;
    final alcas = _editor.handles;
    return Scaffold(
      appBar: AppBar(title: const Text('Nova rota')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                KeyedSubtree(
                  key: _mapaKey,
                  child: FlutterMap(
                    key: const Key('mapa-criar-rota'),
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: toLatLng(defaultMapCenter),
                      initialZoom: 13,
                      onTap: (_, p) => _tocar(p),
                      onMapReady: _quandoMapaPronto,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      ...baseMapLayers(ref),
                      if (rota != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [for (final p in rota.points) LatLng(p.lat, p.lon)],
                              strokeWidth: 6,
                              color: AppColors.destaque.withValues(alpha: _desatualizada ? 0.35 : 1),
                            ),
                          ],
                        ),
                      if (pontos.length >= 2 && (rota == null || _desatualizada))
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [for (final p in pontos) toLatLng(p)],
                              strokeWidth: 3,
                              color: AppColors.destaque.withValues(alpha: 0.7),
                              pattern: StrokePattern.dashed(segments: const [10, 8]),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (var i = 0; i < alcas.length; i++)
                            Marker(
                              point: toLatLng(alcas[i]),
                              width: 40,
                              height: 40,
                              child: _PontoArrastavel(
                                key: Key('ponto-$i'),
                                onComeca: () => _comecaArrasto(i),
                                onMove: (global) => _arrasta(i, global),
                                onSolta: _soltaArrasto,
                                onApaga: () => _apagar(i),
                                child: Center(
                                  child: Container(
                                    width: _arrastando == i ? 26 : (i == 0 ? 20 : 16),
                                    height: _arrastando == i ? 26 : (i == 0 ? 20 : 16),
                                    decoration: BoxDecoration(
                                      color: i == 0 ? AppColors.destaque : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.destaque, width: 3),
                                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_achado != null)
                            Marker(
                              point: toLatLng(_achado!.point),
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(Icons.place, size: 40, color: AppColors.avisoTexto),
                            ),
                        ],
                      ),
                      mapAttribution,
                    ],
                  ),
                ),
                if (_achado != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 84,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _adicionarAchado,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Adicionar ponto aqui'),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _Ferramenta(
                                icone: Icons.auto_awesome,
                                rotulo: 'Gerar volta',
                                onTap: _calculando ? null : _gerarVolta,
                              ),
                              _Ferramenta(
                                icone: Icons.undo,
                                dica: 'Desfazer',
                                onTap: _editor.canUndo ? () => _mudou(() => _editor.undo()) : null,
                              ),
                              _Ferramenta(
                                icone: Icons.loop,
                                rotulo: 'Fechar volta',
                                onTap: _editor.canClose ? () => _mudou(_editor.close) : null,
                              ),
                              _Ferramenta(
                                icone: Icons.swap_horiz,
                                rotulo: 'Ida e volta',
                                onTap: _editor.canOutAndBack ? () => _mudou(_editor.outAndBack) : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.superficie,
                        elevation: 3,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Onde estou',
                          onPressed: _localizar,
                          icon: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
                // Por último: a lista da busca fica por cima das ferramentas e rola se for comprida.
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: 12,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _Busca(
                      controller: _busca,
                      resultados: _resultados,
                      erro: _erroBusca,
                      onChanged: _digitou,
                      onEscolher: _escolher,
                      onLimpar: _limparBusca,
                    ),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_erro != null) AvisoFaixa(texto: _erro!, acao: 'Tentar de novo', onAcao: _calcular),
                      Text(_dica, style: AppText.suave),
                      if (_semLocalizacao && pontos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Sem localização: arraste o mapa até o seu bairro.', style: AppText.suave),
                        ),
                      if (_calculando && rota == null) ...[
                        const SizedBox(height: 10),
                        const Text('Traçando o caminho pelas ruas…', style: AppText.corpoForte),
                        const SizedBox(height: 6),
                        const LinearProgressIndicator(),
                      ],
                      if (rota != null && perfil != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatKm(rota.distanceM),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _calculando || _desatualizada
                                    ? 'atualizando…'
                                    : '↑ ${formatNumber(rota.gainM)} m · ↓ ${formatNumber(rota.lossM)} m',
                                textAlign: TextAlign.end,
                                style: AppText.suave,
                              ),
                            ),
                          ],
                        ),
                        if (_plana)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: AvisoFaixa(
                              texto: 'Não consegui as subidas e descidas agora: a rota ficou plana.',
                              acao: 'Tentar de novo',
                              onAcao: _calculando ? null : _calcular,
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(height: 64, child: ElevationChart(profile: perfil)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nome,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Nome da rota', hintText: 'Volta do bairro'),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _calculando || _desatualizada ? null : _salvar,
                          child: const Text('Salvar rota'),
                        ),
                      ],
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

class _Busca extends StatelessWidget {
  const _Busca({
    required this.controller,
    required this.resultados,
    required this.erro,
    required this.onChanged,
    required this.onEscolher,
    required this.onLimpar,
  });

  final TextEditingController controller;
  final List<Place> resultados;
  final String? erro;
  final ValueChanged<String> onChanged;
  final ValueChanged<Place> onEscolher;
  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('busca-endereco'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar endereço ou lugar',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, valor, _) => valor.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(tooltip: 'Limpar busca', onPressed: onLimpar, icon: const Icon(Icons.close)),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (erro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(erro!, style: AppText.suave),
              ),
            ),
          if (resultados.isNotEmpty)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final p in resultados)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: p.detail.isEmpty ? null : Text(p.detail, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => onEscolher(p),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Ferramenta extends StatelessWidget {
  const _Ferramenta({required this.icone, this.rotulo, this.dica, required this.onTap});

  final IconData icone;

  /// Texto ao lado do ícone; sem ele, só o ícone (com [dica] ao segurar).
  final String? rotulo;
  final String? dica;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: AppColors.superficie,
          elevation: 3,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Tooltip(
              message: dica ?? rotulo ?? '',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: rotulo == null ? 10 : 12, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 18, color: AppColors.texto),
                    if (rotulo != null) ...[
                      const SizedBox(width: 6),
                      Text(rotulo!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ponto da rota que pega o gesto assim que o dedo encosta (senão o mapa, que reage a um
/// movimento menor, arrasta o mapa em vez do ponto). Segurar apaga; um toque não cria ponto em cima.
class _PontoArrastavel extends StatelessWidget {
  const _PontoArrastavel({
    super.key,
    required this.onComeca,
    required this.onMove,
    required this.onSolta,
    required this.onApaga,
    required this.child,
  });

  final VoidCallback onComeca;
  final ValueChanged<Offset> onMove;
  final VoidCallback onSolta;
  final VoidCallback onApaga;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        ImmediateMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
          ImmediateMultiDragGestureRecognizer.new,
          (r) => r.onStart = (_) {
            onComeca();
            return _Arrasto(this);
          },
        ),
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          LongPressGestureRecognizer.new,
          (r) => r.onLongPress = onApaga,
        ),
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (r) => r.onTap = () {},
        ),
      },
      child: child,
    );
  }
}

class _Arrasto extends Drag {
  _Arrasto(this._ponto);

  final _PontoArrastavel _ponto;

  @override
  void update(DragUpdateDetails details) => _ponto.onMove(details.globalPosition);

  @override
  void end(DragEndDetails details) => _ponto.onSolta();

  @override
  void cancel() => _ponto.onSolta();
}
