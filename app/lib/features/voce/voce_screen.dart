import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../data/settings_store.dart';
import '../../domain/stats.dart';
import 'historico_calendario.dart';

/// Aba Você: os recordes, o calendário do mês e todos os pedais (tocar num dia filtra a lista;
/// tocar de novo, no X ou fora mostra todos).
class VoceScreen extends ConsumerStatefulWidget {
  const VoceScreen({super.key});

  @override
  ConsumerState<VoceScreen> createState() => _VoceScreenState();
}

class _VoceScreenState extends ConsumerState<VoceScreen> {
  DateTime? _dia;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final bike = ref.watch(bikeControllerProvider);
    final pedais = ref.watch(allRidesProvider);
    final agora = DateTime.now();
    final nome = settings.nome?.trim() ?? '';
    return Scaffold(
      // Tocar fora dos dias e dos pedais solta o filtro (os toques neles ganham deste).
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dia == null ? null : () => setState(() => _dia = null),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/ajustes/voce'),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.destaqueSuave, shape: BoxShape.circle),
                      child: nome.isEmpty
                          ? const Icon(Icons.person_outline, size: 28, color: AppColors.destaqueTexto)
                          : Text(
                              nome.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.destaqueTexto,
                              ),
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
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ...pedais.when(
                loading: () => const [Center(child: CircularProgressIndicator())],
                error: (e, s) => [Text('Não consegui ler os pedais: $e', style: AppText.suave)],
                data: (lista) => lista.isEmpty
                    ? const [
                        SectionTitle('Histórico'),
                        Text('Nenhum pedal ainda. Que tal um pedal livre?', style: AppText.suave),
                      ]
                    : [
                        _Recordes(pedais: lista, agora: agora),
                        const SizedBox(height: 20),
                        const SectionTitle('Histórico'),
                        HistoricoCalendario(
                          pedais: lista,
                          hoje: agora,
                          dia: _dia,
                          onDia: (d) => setState(() => _dia = d),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Os totais numa linha e os melhores pedais; tocar num recorde abre o pedal.
class _Recordes extends StatelessWidget {
  const _Recordes({required this.pedais, required this.agora});

  final List<RideRecord> pedais;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final total = summarize(pedais);
    final r = recordes(pedais, now: agora)!;
    final primeiro = pedais.map((p) => p.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final semana = r.melhorSemana;
    return AppCard(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Expanded(child: Text('Seus recordes', style: AppText.secao)),
                Text('desde ${_data(primeiro)}', style: AppText.suave),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: MetricTile(value: formatNumber(total.distanceM / 1000, 1), label: 'km')),
                Expanded(child: MetricTile(value: '${total.count}', label: total.count == 1 ? 'pedal' : 'pedais')),
                Expanded(child: MetricTile(value: _horas(total.movingTimeS), label: 'tempo')),
                Expanded(child: MetricTile(value: formatNumber(total.gainM), label: 'm de subida')),
              ],
            ),
          ),
          _LinhaRecorde(icone: Icons.route, titulo: 'Mais longe', pedal: r.maisLonge, valor: formatKm(r.maisLonge.distanceM)),
          _LinhaRecorde(
            icone: Icons.terrain,
            titulo: 'Mais subida',
            pedal: r.maisSubida,
            valor: '${formatNumber(r.maisSubida.gainM)} m',
          ),
          _LinhaRecorde(
            icone: Icons.timer_outlined,
            titulo: 'Mais tempo',
            pedal: r.maisTempo,
            valor: formatTime(r.maisTempo.movingTimeS),
          ),
          _LinhaRecorde(
            icone: Icons.calendar_view_week,
            titulo: 'Melhor semana',
            de: semana.label == 'Esta semana' || semana.label == 'Semana passada'
                ? semana.label.toLowerCase()
                : semana.label,
            valor: formatKm(semana.distanceM, 1),
          ),
        ],
      ),
    );
  }
}

String _data(DateTime d) => '${d.day}/${d.month}';

/// “1h24” (ou “42 min”): o tempo total, curto para caber na coluna.
String _horas(double segundos) {
  final min = segundos ~/ 60;
  return min < 60 ? '$min min' : '${min ~/ 60}h${(min % 60).toString().padLeft(2, '0')}';
}

/// Um recorde: ícone, o que é, de onde veio e o número; com [pedal], toca para abrir.
class _LinhaRecorde extends ConsumerWidget {
  const _LinhaRecorde({required this.icone, required this.titulo, required this.valor, this.pedal, this.de});

  final IconData icone;
  final String titulo;
  final String valor;
  final RideRecord? pedal;

  /// De onde veio, quando não é um pedal (a melhor semana).
  final String? de;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pedal;
    final routeId = p?.routeId;
    final rota = routeId == null ? null : ref.watch(routeByIdProvider(routeId)).value;
    final origem = p == null ? de ?? '' : '${rideName(p, routeName: rota?.name)} · ${_data(p.startedAt)}';
    return InkWell(
      onTap: p == null ? null : () => context.push('/resumo/${p.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF1EF)))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(12)),
              child: Icon(icone, size: 22, color: AppColors.destaqueTexto),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppText.corpoForte),
                  Text(origem, style: AppText.suave, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
