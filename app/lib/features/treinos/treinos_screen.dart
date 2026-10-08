import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/training.dart';
import '../../domain/training_plans.dart';
import '../../domain/workout.dart';
import '../pedal_livre/pedal_livre_card.dart';
import 'workout_chart.dart';

class TreinosScreen extends ConsumerWidget {
  const TreinosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final feitos = ref.watch(doneWorkoutsProvider).value ?? const <DoneWorkout>[];
    final plano = planById(s.planoId);
    final inicio = s.planoInicio;
    final progresso = plano == null || inicio == null ? null : planProgress(plano, inicio, feitos);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Text('Treinos', style: AppText.titulo),
            const SizedBox(height: 16),
            CondicionamentoCard(settings: s),
            const SizedBox(height: 20),
            const SectionTitle('Plano de treino'),
            if (progresso != null)
              PlanoAtivoCard(progresso: progresso)
            else
              for (final p in trainingPlans) ...[
                _PlanoTile(plano: p),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 20),
            const PedalLivreCard(),
            for (final categoria in workoutCategories) ...[
              const SizedBox(height: 20),
              SectionTitle(categoria),
              for (final w in workoutLibrary.where((w) => w.category == categoria)) ...[
                TreinoTile(workout: w),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// FTP, as zonas e o teste de rampa.
class CondicionamentoCard extends StatelessWidget {
  const CondicionamentoCard({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final testado = settings.ftp != null;
    final ftp = settings.ftp ?? defaultFtp(settings.pesoKg);
    final ajuste = ((settings.intensidade - 1) * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${formatNumber(ftp)} W', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  testado
                      ? 'seu FTP · ${formatNumber(ftp / settings.pesoKg, 1)} W/kg'
                      : 'FTP estimado pelo seu peso',
                  style: AppText.suave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final z in trainingZones)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: zoneColor(z.number), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            testado
                ? 'As metas dos treinos saem do seu FTP. Refaça o teste a cada 4 a 6 semanas.'
                : 'FTP é a força que você aguenta por uma hora. As metas dos treinos saem dele: faça o teste para acertar.',
            style: AppText.suave,
          ),
          if (ajuste != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ajuste pelas suas respostas: ${ajuste > 0 ? '+' : ''}$ajuste% nas metas.',
                style: AppText.suave.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/treino/${rampTestWorkout.id}'),
            icon: const Icon(Icons.trending_up),
            label: Text(testado ? 'Refazer o teste de rampa' : 'Fazer o teste de rampa · 20 min'),
          ),
        ],
      ),
    );
  }
}

/// Plano em andamento: semana, quantos feitos e o próximo treino.
class PlanoAtivoCard extends StatelessWidget {
  const PlanoAtivoCard({super.key, required this.progresso});

  final PlanProgress progresso;

  @override
  Widget build(BuildContext context) {
    final p = progresso.plan;
    final proximo = progresso.nextWorkoutId == null ? null : workoutById(progresso.nextWorkoutId!);
    return AppCard(
      onTap: () => context.push('/plano/${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: AppText.corpoForte),
          const SizedBox(height: 2),
          Text(
            progresso.finished
                ? 'Plano concluído! ${progresso.total} treinos feitos.'
                : 'Semana ${progresso.week + 1} de ${p.weeks.length} · ${progresso.doneCount} de ${progresso.total} treinos',
            style: AppText.suave,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progresso.total == 0 ? 0 : progresso.doneCount / progresso.total,
              minHeight: 8,
              backgroundColor: AppColors.neutro,
            ),
          ),
          if (proximo != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Próximo treino', style: AppText.suave),
                      Text(proximo.name, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${proximo.seconds ~/ 60} min · ${proximo.level}', style: AppText.suave),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.push('/treino/${proximo.id}'),
                  child: const Text('Ver e começar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanoTile extends StatelessWidget {
  const _PlanoTile({required this.plano});

  final TrainingPlan plano;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/plano/${plano.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.event_note_outlined, color: AppColors.destaque),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plano.name, style: AppText.corpoForte),
                Text(plano.summary, style: AppText.suave, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textoSuave),
        ],
      ),
    );
  }
}

/// Cartão de um treino da biblioteca: nome, duração, dificuldade e o desenho.
class TreinoTile extends StatelessWidget {
  const TreinoTile({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/treino/${workout.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(workout.name, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('${workout.seconds ~/ 60} min · ${workout.level}', style: AppText.suave),
            ],
          ),
          const SizedBox(height: 10),
          WorkoutChart(workout: workout, height: 36),
        ],
      ),
    );
  }
}
