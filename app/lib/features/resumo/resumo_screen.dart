import 'dart:math' as math;

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
import '../../data/rides_store.dart';
import '../../domain/laps.dart';
import '../../domain/ride_analysis.dart';
import '../../domain/route_profile.dart';
import '../../domain/route_variant.dart';
import 'metric_chart.dart';

/// Resumo e análise de um pedal. [novo] = acabou de pedalar (mostra “Concluir”).
class ResumoScreen extends ConsumerWidget {
  const ResumoScreen({super.key, required this.rideId, this.novo = false});

  final String rideId;
  final bool novo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideByIdProvider(rideId));
    return Scaffold(
      appBar: novo ? null : AppBar(title: const Text('Pedal')),
      body: SafeArea(
        child: ride.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Não consegui abrir o pedal: $e')),
          data: (r) => r == null ? const Center(child: Text('Pedal não encontrado.')) : _Conteudo(ride: r, novo: novo),
        ),
      ),
    );
  }
}

class _Conteudo extends ConsumerStatefulWidget {
  const _Conteudo({required this.ride, required this.novo});

  final RideRecord ride;
  final bool novo;

  @override
  ConsumerState<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends ConsumerState<_Conteudo> {
  RideMetric _metrica = RideMetric.velocidade;
  int _volta = 0;
  double? _marca;

  RideRecord get ride => widget.ride;

  Future<void> _apagar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar este pedal?'),
        content: const Text('Ele some do histórico e dos totais.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(ridesStoreProvider).delete(ride.id);
    ref
      ..invalidate(recentRidesProvider)
      ..invalidate(rideStatsProvider)
      ..invalidate(rideByIdProvider(ride.id));
    if (!mounted) return;
    if (widget.novo || !context.canPop()) {
      context.go('/inicio');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeId = ride.routeId;
    final rota = routeId == null
        ? null
        : ref.watch(routeByIdProvider(routeId)).when(data: (r) => r, loading: () => null, error: (e, s) => null);
    final track = ride.track;
    final perfil = track == null || track.length < 2 ? null : RouteProfile(track);
    final volta = perfil == null ? double.infinity : (ride.loop ? perfil.distance : double.infinity);
    final fatias = lapSlices(ride.samples, volta);
    final fatia = fatias.isEmpty ? null : fatias[_volta.clamp(0, fatias.length - 1)];
    final cor = rota == null ? AppColors.destaque : routeColor(rota.colorIndex);

    double grau(double d) {
      final p = perfil!;
      return p.gradeAt(ride.loop ? d - (d / p.distance).floor() * p.distance : d);
    }

    final metricas = availableMetrics(ride.samples, hasTerrain: perfil != null);
    final metrica = metricas.contains(_metrica) ? _metrica : metricas.first;
    final todos = metricSeries(ride.samples, metrica, gradeAt: perfil == null ? null : grau);
    final (lo, hi) = colorRange(todos);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _Cabecalho(ride: ride, nomeRota: rota?.name, perfil: perfil),
        const SizedBox(height: 14),
        if (fatia != null && fatia.samples.length > 1)
          _Analise(
            ride: ride,
            perfil: perfil,
            fatia: fatia,
            metricas: metricas,
            metrica: metrica,
            valores: _recorte(todos, fatia),
            lo: lo,
            hi: hi,
            marca: _marca,
            onMetrica: (m) => setState(() {
              _metrica = m;
              _marca = null;
            }),
            onMarca: (d) => setState(() => _marca = d),
          ),
        if (fatias.length > 1) ...[
          const SizedBox(height: 10),
          _Voltas(
            tempos: lapTimes(ride.samples, volta),
            fatias: fatias,
            atual: _volta.clamp(0, fatias.length - 1),
            onVolta: (i) => setState(() {
              _volta = i;
              _marca = null;
            }),
          ),
        ],
        const SizedBox(height: 14),
        _Numeros(ride: ride),
        if (routeId != null && ride.laps >= 1) ...[
          const SizedBox(height: 14),
          _Comparacao(ride: ride, routeId: routeId, cor: cor),
        ],
        const SizedBox(height: 20),
        if (widget.novo)
          Row(
            children: [
              const Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text('Strava · em breve', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(onPressed: () => context.go('/inicio'), child: const Text('Concluir')),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _apagar,
            icon: const Icon(Icons.delete_outline, color: AppColors.avisoTexto),
            label: const Text('Apagar este pedal', style: TextStyle(color: AppColors.avisoTexto)),
          ),
        ),
      ],
    );
  }

  /// Valores da métrica só das amostras desta volta.
  List<double> _recorte(List<double> todos, LapSlice fatia) {
    final ini = ride.samples.indexOf(fatia.samples.first);
    return todos.sublist(ini, ini + fatia.samples.length);
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.ride, required this.nomeRota, required this.perfil});

  final RideRecord ride;
  final String? nomeRota;
  final RouteProfile? perfil;

  @override
  Widget build(BuildContext context) {
    final rota = ride.mode == RideMode.rota;
    final concluiu = rota ? ride.laps >= 1 : ride.completed;
    final titulo = !ride.completed
        ? 'Pedal salvo'
        : rota
            ? (ride.laps >= 1 ? 'Rota concluída!' : 'Pedal encerrado')
            : 'Pedal concluído!';
    final subtitulo = [nomeRota ?? rideModeLabel(ride.mode), formatDateTime(ride.startedAt)].join(' · ');
    final p = perfil;
    final detalhes = <String>[];
    if (rota && p != null) {
      if (ride.loop) {
        final extra = ride.distanceM - ride.laps * p.distance;
        final voltas = ride.laps == 1 ? '1 volta' : '${ride.laps} voltas';
        detalhes.add(extra > 1 ? '$voltas + ${formatKm(extra)}' : voltas);
        detalhes.add(isClockwise(ride.track!) ? 'sentido horário' : 'sentido anti-horário');
      } else {
        if (ride.reversed) detalhes.add('sentido invertido');
        if (ride.laps == 0) detalhes.add('faltaram ${formatKm(math.max(0, p.distance - ride.distanceM))}');
      }
    }
    if (ride.trimmedM > 0) detalhes.add('volta fechada: ${formatNumber(ride.trimmedM)} m a mais descartados');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: concluiu ? AppColors.destaque : AppColors.neutro,
            shape: BoxShape.circle,
          ),
          child: Icon(concluiu ? Icons.check : Icons.flag_outlined, color: concluiu ? Colors.white : AppColors.texto, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppText.titulo.copyWith(fontSize: 24)),
              Text(subtitulo, style: AppText.subtitulo, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (detalhes.isNotEmpty) Text(detalhes.join(' · '), style: AppText.suave),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mapa pintado + gráfico da métrica escolhida.
class _Analise extends StatelessWidget {
  const _Analise({
    required this.ride,
    required this.perfil,
    required this.fatia,
    required this.metricas,
    required this.metrica,
    required this.valores,
    required this.lo,
    required this.hi,
    required this.marca,
    required this.onMetrica,
    required this.onMarca,
  });

  final RideRecord ride;
  final RouteProfile? perfil;
  final LapSlice fatia;
  final List<RideMetric> metricas;
  final RideMetric metrica;
  final List<double> valores;
  final double lo;
  final double hi;
  final double? marca;
  final ValueChanged<RideMetric> onMetrica;
  final ValueChanged<double> onMarca;

  int get _casas => metrica == RideMetric.velocidade || metrica == RideMetric.inclinacao ? 1 : 0;

  String _valor(double v) => '${formatNumber(v, _casas)} ${metrica.unit}'.replaceAll(' %', '%');

  @override
  Widget build(BuildContext context) {
    final p = perfil;
    final xs = [for (final s in fatia.samples) s.distance - fatia.start];
    final comprimento = math.max(1.0, fatia.complete ? fatia.length : xs.last);
    final m = marca;
    int? indiceMarca;
    if (m != null) {
      var i = 0;
      while (i < xs.length - 1 && xs[i] < m) {
        i++;
      }
      indiceMarca = i;
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opcao in metricas)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(opcao.label),
                      selected: opcao == metrica,
                      onSelected: (_) => onMetrica(opcao),
                    ),
                  ),
              ],
            ),
          ),
          if (p != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(height: 230, child: _MapaPintado(perfil: p, fatia: fatia, valores: valores, lo: lo, hi: hi, marca: m)),
            ),
          ],
          const SizedBox(height: 10),
          _Legenda(lo: _valor(lo), hi: _valor(hi)),
          const SizedBox(height: 10),
          Text(
            indiceMarca == null
                ? 'Toque ou arraste no gráfico para ver cada ponto.'
                : '${formatKm(xs[indiceMarca])} · ${_valor(valores[indiceMarca])}',
            style: indiceMarca == null ? AppText.suave : AppText.corpoForte,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: MetricChart(
              key: const Key('grafico-metrica'),
              xs: xs,
              ys: valores,
              lo: lo,
              hi: hi,
              length: comprimento,
              scrub: m,
              onScrub: onMarca,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0 km', style: AppText.suave),
              Text(formatKm(comprimento), style: AppText.suave),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapaPintado extends ConsumerWidget {
  const _MapaPintado({
    required this.perfil,
    required this.fatia,
    required this.valores,
    required this.lo,
    required this.hi,
    required this.marca,
  });

  final RouteProfile perfil;
  final LapSlice fatia;
  final List<double> valores;
  final double lo;
  final double hi;
  final double? marca;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LatLng em(double d) {
      final g = perfil.positionAt(d);
      return LatLng(g.lat, g.lon);
    }

    final pontos = [em(0), for (final s in fatia.samples) em(s.distance - fatia.start)];
    final linha = [for (final p in perfil.points) LatLng(p.lat, p.lon)];
    final m = marca;
    return FlutterMap(
      key: const Key('mapa-pedal'),
      options: MapOptions(
        initialCenter: linha.first,
        initialZoom: 15,
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(linha),
          padding: const EdgeInsets.all(24),
          maxZoom: 17,
        ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        ...baseMapLayers(ref),
        PolylineLayer(polylines: [
          Polyline(points: linha, strokeWidth: 9, color: Colors.white),
          ...heatPolylines(pontos, [valores.first, ...valores], lo, hi, largura: 6),
        ]),
        CircleLayer(circles: [
          // Chegada só aparece se ficar longe do começo (na volta fechada, os dois coincidem).
          if (const Distance().as(LengthUnit.Meter, pontos.first, pontos.last) > 30)
            CircleMarker(point: pontos.last, radius: 7, color: AppColors.escuro, borderColor: Colors.white, borderStrokeWidth: 2.5),
          CircleMarker(point: pontos.first, radius: 7, color: AppColors.destaque, borderColor: Colors.white, borderStrokeWidth: 2.5),
          if (m != null)
            CircleMarker(point: em(m), radius: 9, color: Colors.white, borderColor: AppColors.texto, borderStrokeWidth: 3),
        ]),
        mapAttribution,
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.lo, required this.hi});

  final String lo;
  final String hi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(lo, style: AppText.suave),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(colors: heatStops),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(hi, style: AppText.suave),
      ],
    );
  }
}

class _Voltas extends StatelessWidget {
  const _Voltas({required this.tempos, required this.fatias, required this.atual, required this.onVolta});

  final List<double> tempos;
  final List<LapSlice> fatias;
  final int atual;
  final ValueChanged<int> onVolta;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final f in fatias)
          ChoiceChip(
            showCheckmark: false,
            label: Text(
              'Volta ${f.index + 1}'
              '${f.index < tempos.length ? ' · ${formatTime(tempos[f.index])}' : ''}'
              '${f.complete ? '' : ' (parcial)'}',
            ),
            selected: f.index == atual,
            onSelected: (_) => onVolta(f.index),
          ),
      ],
    );
  }
}

class _Numeros extends StatelessWidget {
  const _Numeros({required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context) {
    final amostras = ride.samples;
    final velMax = amostras.isEmpty ? 0.0 : amostras.map((s) => s.speedKmh).reduce(math.max);
    final potMax = amostras.isEmpty ? 0.0 : amostras.map((s) => s.power).reduce(math.max);
    final girando = [for (final s in amostras) if (s.cadence > 0) s.cadence];
    final cadMedia = girando.isEmpty ? 0.0 : girando.reduce((a, b) => a + b) / girando.length;
    Widget linha(List<(String, String)> itens) => Row(
          children: [for (final (v, l) in itens) Expanded(child: MetricTile(value: v, label: l))],
        );
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          linha([
            (formatNumber(ride.distanceM / 1000, 2), 'km'),
            (formatTime(ride.movingTimeS), 'tempo'),
            (formatNumber(ride.avgSpeedKmh, 1), 'km/h média'),
          ]),
          const SizedBox(height: 16),
          linha([
            (formatNumber(ride.avgPowerW), 'watts média'),
            ('${formatNumber(ride.gainM)} m', 'de subida'),
            (formatNumber(ride.kcal), 'kcal'),
          ]),
          const SizedBox(height: 16),
          linha([
            (formatNumber(velMax, 1), 'km/h máx.'),
            (formatNumber(potMax), 'watts máx.'),
            (formatNumber(cadMedia), 'rpm média'),
          ]),
        ],
      ),
    );
  }
}

/// Tempo por volta comparado com os pedais anteriores na mesma rota e no mesmo sentido.
class _Comparacao extends ConsumerWidget {
  const _Comparacao({required this.ride, required this.routeId, required this.cor});

  final RideRecord ride;
  final String routeId;
  final Color cor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(ridesForRouteProvider(routeId));
    return lista.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (pedais) {
        double porVolta(RideRecord r) => r.movingTimeS / math.max(1, r.laps);
        final anteriores = [
          for (final r in pedais)
            if (r.id != ride.id && r.laps >= 1 && r.reversed == ride.reversed && r.startedAt.isBefore(ride.startedAt)) r,
        ];
        final hoje = porVolta(ride);
        final linhas = <Widget>[];
        if (anteriores.isEmpty) {
          linhas.add(const Text('Primeira vez nesta rota neste sentido.', style: AppText.corpoForte));
          final tempo = ride.loop ? '${formatTime(hoje)} por volta' : formatTime(hoje);
          linhas.add(Text('Seu tempo de hoje, $tempo, é a marca a bater.', style: AppText.suave));
        } else {
          final recorde = anteriores.map(porVolta).reduce(math.min);
          final ultima = porVolta(anteriores.first);
          if (hoje < recorde) {
            linhas.add(const Text('Seu melhor tempo nesta rota!', style: AppText.corpoForte));
            linhas.add(Text('${formatTime(recorde - hoje)} mais rápido que o recorde anterior.', style: AppText.suave));
          } else {
            linhas.add(Text('Recorde: ${formatTime(recorde)}${ride.loop ? ' por volta' : ''}', style: AppText.corpoForte));
            linhas.add(Text('Faltaram ${formatTime(hoje - recorde)} para bater.', style: AppText.suave));
          }
          final dif = hoje - ultima;
          linhas.add(Text(
            dif.abs() < 0.5
                ? 'Igual à última vez.'
                : 'Da última vez: ${formatTime(ultima)} · hoje ${formatTime(dif.abs())} ${dif < 0 ? 'mais rápido' : 'mais devagar'}.',
            style: AppText.suave,
          ));
        }
        return AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.emoji_events_outlined, color: cor),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: linhas)),
            ],
          ),
        );
      },
    );
  }
}
