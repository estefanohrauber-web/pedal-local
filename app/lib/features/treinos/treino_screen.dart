import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/training.dart';
import '../../domain/workout.dart';
import '../pedal/ride_controller.dart';
import 'workout_chart.dart';

/// Antes de começar um treino: o desenho, os trechos com as metas e o controle da bike.
class TreinoScreen extends ConsumerWidget {
  const TreinoScreen({super.key, required this.workoutId});

  final String workoutId;

  Future<void> _controle(WidgetRef ref, bool ligado) async {
    final store = ref.read(settingsStoreProvider);
    await store.save((await store.load()).copyWith(controleBike: ligado));
    ref.invalidate(settingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workoutLookupProvider)(workoutId);
    if (w == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esse treino não existe.')));
    }
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final bike = ref.watch(bikeControllerProvider);
    final ftp = s.ftp ?? defaultFtp(s.pesoKg);
    final intensidade = w.rampTest ? 1.0 : s.intensidade;
    int watts(double f) => (ftp * f * intensidade).round();
    final ajuste = ((intensidade - 1) * 100).round();
    final controle = bike.source?.control;
    return Scaffold(
      appBar: AppBar(title: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          WorkoutChart(workout: w, height: 110),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Info(icone: Icons.schedule, texto: w.rampTest ? 'cerca de 20 min' : '${w.seconds ~/ 60} min'),
              if (!w.rampTest) _Info(icone: Icons.speed, texto: w.level),
              if (!w.rampTest) _Info(icone: Icons.local_fire_department_outlined, texto: 'carga ${w.stress.round()}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(w.summary, style: AppText.corpoForte.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            'Metas para o seu FTP de ${formatNumber(ftp)} W'
            '${s.ftp == null ? ' (estimado pelo peso)' : ''}'
            '${ajuste == 0 ? '' : ', com ${ajuste > 0 ? '+' : ''}$ajuste% pelas suas respostas'}.',
            style: AppText.suave,
          ),
          const SizedBox(height: 16),
          if (w.rampTest)
            const _ComoFuncionaRampa()
          else ...[
            const SectionTitle('Trechos'),
            for (final step in w.steps) _Trecho(step: step, watts: watts),
          ],
          const SizedBox(height: 16),
          if (bike.connected)
            if (controle != null && controle.features.power)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SwitchListTile(
                  title: const Text('A bike ajusta a carga sozinha', style: AppText.corpoForte),
                  subtitle: const Text(
                    'Modo ERG: a bike segura a meta e você só mantém o giro. Desligado, você ajusta no botão.',
                    style: AppText.suave,
                  ),
                  value: s.controleBike,
                  onChanged: (v) => _controle(ref, v),
                ),
              )
            else
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.tune, color: AppColors.textoSuave),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controle != null && controle.features.simulation
                            ? 'Sua bike endurece sozinha nos trechos de subida. No resto, ajuste no botão: a tela e a voz avisam.'
                            : 'Sua bike não aceita comando de carga: ajuste no botão. A tela e a voz avisam quando subir ou baixar.',
                        style: AppText.suave,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: () => context.push(bike.connected ? '/treino-pedal/${w.id}' : '/bike'),
            icon: Icon(bike.connected ? Icons.play_arrow : Icons.bluetooth),
            label: Text(bike.connected ? (w.rampTest ? 'Começar o teste' : 'Começar treino') : 'Conectar a bike para começar'),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.neutro, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: AppColors.textoSuave),
          const SizedBox(width: 6),
          Text(texto, style: AppText.suave.copyWith(color: AppColors.texto, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Uma linha por trecho: cor da zona, duração, esforço, meta e giro.
class _Trecho extends StatelessWidget {
  const _Trecho({required this.step, required this.watts});

  final WorkoutStep step;
  final int Function(double fraction) watts;

  @override
  Widget build(BuildContext context) {
    final zona = zoneFor(step.mid);
    final meta = step.isRamp ? '${watts(step.from)} → ${watts(step.to)} W' : '${watts(step.from)} W';
    final detalhes = [
      meta,
      if (step.hasCadence) '${step.cadenceMin}–${step.cadenceMax} rpm',
      if (step.grade != 0) 'subida de ${formatNumber(step.grade * 100)}%',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 6, height: 38, decoration: BoxDecoration(color: zoneColor(zona.number), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          SizedBox(width: 52, child: Text(formatTime(step.seconds.toDouble()), style: AppText.corpoForte)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.cue ?? zona.effort, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${zona.effort} · $detalhes', style: AppText.suave, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComoFuncionaRampa extends StatelessWidget {
  const _ComoFuncionaRampa();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Como funciona', style: AppText.corpoForte),
          SizedBox(height: 6),
          Text(
            '1. Cinco minutos leves para aquecer.\n'
            '2. Depois a meta sobe um pouco a cada minuto. Siga a meta subindo a carga ou o giro.\n'
            '3. Vá até não aguentar mais e toque em “Não aguento mais” (ou só pare de fazer força).\n'
            '4. O app calcula o FTP com o seu melhor minuto (75 % dele, como Zwift e TrainerRoad) e guarda.\n'
            '5. Mais cinco minutos leves para soltar as pernas.',
            style: AppText.suave,
          ),
          SizedBox(height: 6),
          Text('Faça descansado. O teste costuma durar de 15 a 25 minutos.', style: AppText.suave),
        ],
      ),
    );
  }
}
