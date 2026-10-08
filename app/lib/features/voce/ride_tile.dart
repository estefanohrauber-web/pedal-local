import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../domain/route_profile.dart';

class RideTile extends ConsumerWidget {
  const RideTile({super.key, required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = ride.routeId;
    // Pedal em rota mostra o nome e a cor da rota; se ela foi apagada, fica "Rota".
    final rota = routeId == null
        ? null
        : ref.watch(routeByIdProvider(routeId)).when(data: (r) => r, loading: () => null, error: (e, s) => null);
    final cor = rota == null ? AppColors.destaque : routeColor(rota.colorIndex);
    final base = rideName(ride, routeName: rota?.name);
    final titulo = ride.completed ? base : '$base · incompleto';
    final extras = [
      '${formatNumber(ride.avgPowerW)} W',
      if (ride.gainM >= 1) '↑ ${formatNumber(ride.gainM)} m',
      if (ride.loop && ride.laps >= 1) ride.laps == 1 ? '1 volta' : '${ride.laps} voltas',
    ];
    final track = ride.track;
    return AppCard(
      onTap: () => context.push('/resumo/${ride.id}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: track != null && track.length > 1
                ? Padding(
                    padding: const EdgeInsets.all(7),
                    child: CustomPaint(painter: TrackShapePainter(track, cor)),
                  )
                : Icon(
                    switch (ride.mode) {
                      RideMode.livre => Icons.bar_chart_rounded,
                      RideMode.treino => Icons.timer_outlined,
                      _ => Icons.map_outlined,
                    },
                    color: cor,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${formatDateTime(ride.startedAt)} · ${formatKm(ride.distanceM)} · ${formatTime(ride.movingTimeS)}',
                  style: AppText.suave,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(extras.join(' · '), style: AppText.suave, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textoSuave),
        ],
      ),
    );
  }
}

/// Desenho do caminho, do tamanho da caixa, mantendo a proporção.
class TrackShapePainter extends CustomPainter {
  TrackShapePainter(this.track, this.color);

  final List<ProfilePoint> track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = math.cos(track.first.lat * math.pi / 180);
    final xs = [for (final p in track) p.lon * escala];
    final ys = [for (final p in track) p.lat];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final largura = math.max(maxX - minX, 1e-9);
    final altura = math.max(maxY - minY, 1e-9);
    final k = math.min(size.width / largura, size.height / altura);
    final dx = (size.width - largura * k) / 2;
    final dy = (size.height - altura * k) / 2;
    Offset ponto(int i) => Offset(dx + (xs[i] - minX) * k, size.height - dy - (ys[i] - minY) * k);
    final caminho = Path()..moveTo(ponto(0).dx, ponto(0).dy);
    for (var i = 1; i < track.length; i++) {
      caminho.lineTo(ponto(i).dx, ponto(i).dy);
    }
    canvas.drawPath(
      caminho,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(ponto(0), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(TrackShapePainter old) => old.track != track || old.color != color;
}
