import 'package:clock/clock.dart';
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
import '../../core/widgets/elevation_chart.dart';
import '../../domain/ride_session.dart';
import '../bike/selo_ao_vivo.dart';
import '../pedal_livre/pedal_livre_screen.dart';
import 'mais_dados_sheet.dart';
import 'ride_controller.dart';
import 'ride_widgets.dart';

const _alertaVisivel = Duration(seconds: 8);

/// Pedal numa rota: o mapa do bairro ocupa a tela inteira, como num GPS. Em cima, o caminho
/// (quanto já foi e quanto falta); embaixo, o esforço (tempo, velocidade, giro e watts).
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
    Future.microtask(
      () => ref.read(rideProvider(widget.target).notifier).start(),
    );
  }

  Future<void> _finalizar() async {
    if (_encerrando) return;
    setState(() => _encerrando = true);
    final id = await ref.read(rideProvider(widget.target).notifier).finish();
    if (!mounted) return;
    final gap = ref.read(rideProvider(widget.target)).ghostGapS;
    context.go(
      '/resumo/$id?novo=1${gap == null ? '' : '&fantasma=${gap.toStringAsFixed(1)}'}',
    );
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
      final chegou = proximo.state == RideState.concluido;
      if (chegou && anterior?.state != RideState.concluido) _finalizar();
      final pos = proximo.position;
      if (pos != null && _mapaPronto) {
        _map.move(toLatLng(pos), _map.camera.zoom);
      }
    });

    if (v.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Essa rota não existe mais.', style: AppText.corpoForte),
        ),
      );
    }

    final perfil = v.profile;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _encerrar();
      },
      child: Scaffold(
        body: perfil == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: _Mapa(
                      controller: _map,
                      v: v,
                      onReady: () => _mapaPronto = true,
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CartaoCaminho(
                            v: v,
                            onEncerrar: _encerrar,
                            onVoz: ref.read(provider.notifier).toggleVoice,
                          ),
                          const SizedBox(height: 8),
                          if (v.ghostGapS != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: FantasmaChip(gapS: v.ghostGapS!),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _Aviso(v: v),
                          ),
                          const Spacer(),
                          const MapAttribution(),
                          _CartaoEsforco(
                            v: v,
                            enabled: v.started && !_encerrando,
                            onPause: ref.read(provider.notifier).togglePause,
                            onMais: () =>
                                mostrarMaisDados(context, widget.target),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Mapa extends ConsumerWidget {
  const _Mapa({
    required this.controller,
    required this.v,
    required this.onReady,
  });

  final MapController controller;
  final RideView v;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = v.profile!;
    final pontos = [for (final p in perfil.points) toLatLng(p)];
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: toLatLng(v.position ?? perfil.positionAt(0)),
        initialZoom: 16,
        onMapReady: onReady,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        ...baseMapLayers(ref),
        PolylineLayer(
          polylines: [
            Polyline(
              points: pontos,
              strokeWidth: 8,
              color: AppColors.destaque.withValues(alpha: 0.3),
            ),
            Polyline(
              points: [
                for (final p in perfil.traveled(v.lapDistance)) toLatLng(p),
              ],
              strokeWidth: 8,
              color: AppColors.destaque,
            ),
          ],
        ),
        if (pontos.isNotEmpty)
          MarkerLayer(
            markers: [
              if (!v.isLoop)
                Marker(
                  point: pontos.first,
                  width: 18,
                  height: 18,
                  child: const PontoDeSaida(),
                ),
              // A bandeira fica com o pé do mastro no fim da rota (na volta fechada, na largada).
              Marker(
                point: v.isLoop ? pontos.first : pontos.last,
                width: 32,
                height: 36,
                alignment: const Alignment(0.75, -1),
                child: const BandeiraChegada(),
              ),
              if (v.ghostPosition != null)
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
      ],
    );
  }
}

/// Cartão de cima: a rota, se os dados chegam, a voz, encerrar e o progresso até a chegada.
class _CartaoCaminho extends StatelessWidget {
  const _CartaoCaminho({
    required this.v,
    required this.onEncerrar,
    required this.onVoz,
  });

  final RideView v;
  final VoidCallback onEncerrar;
  final VoidCallback onVoz;

  @override
  Widget build(BuildContext context) {
    final total = v.isLoop ? v.lapLength! : v.total;
    final feito = v.isLoop ? v.lapDistance : v.distance;
    final temTotal = total.isFinite && total > 0;
    final fracao = temTotal ? (feito / total).clamp(0.0, 1.0) : 0.0;
    final falta = temTotal ? (total - feito).clamp(0.0, total) : 0.0;
    return _Cartao(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.routeName ?? 'Rota',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SeloAoVivo(),
                  ],
                ),
              ),
              if (v.started) BotaoVoz(ligada: v.voiceOn, onTap: onVoz),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: onEncerrar,
                child: const Text('Encerrar'),
              ),
            ],
          ),
          if (temTotal) ...[
            const SizedBox(height: 8),
            // Encolhe (em vez de estourar) com a fonte do sistema grande.
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (v.isLoop)
                            TextSpan(
                              text: 'Volta ${v.lap} · ',
                              style: AppText.corpoForte,
                            ),
                          TextSpan(
                            text: formatNumber(feito / 1000, 2),
                            style: estiloNumero(26),
                          ),
                          TextSpan(
                            text: ' de ${formatKm(total)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'faltam ${formatKm(falta)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.destaqueTexto,
                    ),
                  ),
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
        ],
      ),
    );
  }
}

/// O aviso da vez, flutuando sobre o mapa: queda da bike, volta concluída, subida ou pausa.
class _Aviso extends ConsumerWidget {
  const _Aviso({required this.v});

  final RideView v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = clock.now();
    final volta = v.lapAlert;
    final alerta = v.alert;
    final quando = v.alertAt;
    if (v.pausedByBike) {
      return AvisoFaixa(
        texto:
            ref.watch(bikeControllerProvider).message ??
            'A bike desconectou. Tentando reconectar…',
        acao: 'Reconectar',
        onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
      );
    }
    if (volta != null && agora.difference(volta.at) < _alertaVisivel) {
      return AvisoFaixa(
        icone: Icons.flag,
        texto:
            'Volta ${volta.number} concluída em ${formatTime(volta.time)}! Seguindo para a volta ${volta.number + 1}.',
      );
    }
    if (alerta != null &&
        quando != null &&
        agora.difference(quando) < _alertaVisivel) {
      return AvisoFaixa(
        icone: alerta.kind == AlertKind.subida
            ? Icons.trending_up
            : Icons.trending_down,
        texto: alerta.kind == AlertKind.subida
            ? 'Subida de ${formatNumber(alerta.grade * 100)}% chegando: aumente a carga'
            : 'Descida chegando: pode aliviar',
      );
    }
    if (v.state == RideState.pausado) {
      return const AvisoFaixa(
        texto: 'Pedal pausado. Toque em Continuar para seguir.',
      );
    }
    return const SizedBox.shrink();
  }
}

/// Cartão de baixo: o relevo pintado até onde você foi, tempo e velocidade grandes, giro, watts e
/// inclinação; “Mais dados” e Pausar.
class _CartaoEsforco extends StatelessWidget {
  const _CartaoEsforco({
    required this.v,
    required this.enabled,
    required this.onPause,
    required this.onMais,
  });

  final RideView v;
  final bool enabled;
  final VoidCallback onPause;
  final VoidCallback onMais;

  @override
  Widget build(BuildContext context) {
    final perfil = v.profile!;
    const pequeno = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textoSuave,
    );
    return _Cartao(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: ElevationChart(profile: perfil, progress: v.lapDistance),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TEMPO', style: pequeno),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatTime(v.movingTime),
                        style: estiloNumero(40),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('km/h', style: pequeno),
                  Text(
                    formatNumber(v.speedKmh, 1),
                    style: estiloNumero(40, cor: AppColors.destaque),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            children: [
              _Par(valor: formatNumber(v.cadence), rotulo: 'rpm'),
              _Par(
                valor: formatNumber(v.power),
                rotulo: v.estimating ? 'watts (estimado)' : 'watts',
              ),
              _Par(valor: '${formatNumber(v.grade * 100)}%', rotulo: 'agora'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMais,
                  icon: const Icon(Icons.expand_less),
                  label: const Text('Mais dados'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.escuro,
                  minimumSize: const Size(116, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: enabled ? onPause : null,
                child: Text(
                  v.state == RideState.pausado ? 'Continuar' : 'Pausar',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Par extends StatelessWidget {
  const _Par({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: valor, style: estiloNumero(17)),
        TextSpan(
          text: ' $rotulo',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textoSuave,
          ),
        ),
      ],
    ),
  );
}

/// Cartão branco sobre o mapa.
class _Cartao extends StatelessWidget {
  const _Cartao({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.superficie,
    elevation: 2,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.borda),
    ),
    child: Padding(padding: padding, child: child),
  );
}
