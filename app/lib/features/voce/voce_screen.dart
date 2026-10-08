import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/stats.dart';
import 'ride_tile.dart';

class VoceScreen extends ConsumerWidget {
  const VoceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).when(
          data: (s) => s,
          loading: () => const AppSettings(),
          error: (e, st) => const AppSettings(),
        );
    final bike = ref.watch(bikeControllerProvider);
    final stats = ref.watch(rideStatsProvider).when(
          data: (l) => l,
          loading: () => const <RideStat>[],
          error: (e, st) => const <RideStat>[],
        );
    final rides = ref.watch(recentRidesProvider);
    final agora = DateTime.now();
    final nome = settings.nome?.trim() ?? '';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/ajustes'),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.destaqueSuave, shape: BoxShape.circle),
                    child: nome.isEmpty
                        ? const Icon(Icons.person_outline, size: 30, color: AppColors.destaqueTexto)
                        : Text(
                            nome.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.destaqueTexto),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome.isEmpty ? 'Você' : 'Olá, $nome',
                          style: AppText.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          nome.isEmpty
                              ? 'Toque para pôr seu nome'
                              : '${formatNumber(settings.pesoKg)} kg · ${bike.connected ? bike.source!.name : 'sem bike conectada'}',
                          style: AppText.subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ajustes',
                    onPressed: () => context.push('/ajustes'),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Semana(resumo: summarize(stats, from: weekStart(agora)), metaKm: settings.metaSemanalKm),
            const SizedBox(height: 12),
            _Totais(resumo: summarize(stats)),
            const SizedBox(height: 20),
            ...rides.when(
              data: (lista) => lista.isEmpty
                  ? const [
                      SectionTitle('Histórico'),
                      Text('Nenhum pedal ainda. Que tal um pedal livre?', style: AppText.suave),
                    ]
                  : [
                      const SectionTitle('Histórico'),
                      for (final grupo in groupByWeek(lista, now: agora)) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(grupo.label, style: AppText.secao)),
                              Text(formatKm(grupo.distanceM), style: AppText.suave),
                            ],
                          ),
                        ),
                        for (final r in grupo.items) ...[RideTile(ride: r), const SizedBox(height: 10)],
                        const SizedBox(height: 6),
                      ],
                    ],
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (e, st) => [Text('Não consegui ler o histórico: $e', style: AppText.suave)],
            ),
          ],
        ),
      ),
    );
  }
}

class _Semana extends StatelessWidget {
  const _Semana({required this.resumo, required this.metaKm});

  final Summary resumo;
  final double metaKm;

  @override
  Widget build(BuildContext context) {
    final km = resumo.distanceM / 1000;
    final fracao = metaKm <= 0 ? 0.0 : (km / metaKm).clamp(0.0, 1.0);
    final bateu = metaKm > 0 && km >= metaKm;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Esta semana', style: AppText.secao)),
              Text(
                bateu ? 'Meta batida!' : '${(fracao * 100).round()}% da meta',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: bateu ? AppColors.destaque : AppColors.textoSuave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: formatNumber(km, 1),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.texto),
              ),
              TextSpan(text: ' de ${formatNumber(metaKm)} km', style: AppText.subtitulo),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fracao,
              minHeight: 10,
              backgroundColor: AppColors.neutro,
              color: AppColors.destaque,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: MetricTile(value: '${resumo.count}', label: resumo.count == 1 ? 'pedal' : 'pedais')),
              Expanded(child: MetricTile(value: formatTime(resumo.movingTimeS), label: 'tempo')),
              Expanded(child: MetricTile(value: '${formatNumber(resumo.gainM)} m', label: 'de subida')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Totais extends StatelessWidget {
  const _Totais({required this.resumo});

  final Summary resumo;

  @override
  Widget build(BuildContext context) {
    final montanha = mountainText(resumo.gainM);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Desde o começo', style: AppText.secao),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: MetricTile(value: formatNumber(resumo.distanceM / 1000, 1), label: 'km')),
              Expanded(child: MetricTile(value: formatTime(resumo.movingTimeS), label: 'tempo')),
              Expanded(child: MetricTile(value: '${resumo.count}', label: resumo.count == 1 ? 'pedal' : 'pedais')),
            ],
          ),
          if (montanha != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.terrain, color: AppColors.destaque),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Você já subiu ${formatNumber(resumo.gainM)} m: $montanha.',
                    style: AppText.suave,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
