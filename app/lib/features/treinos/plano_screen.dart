import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/training_plans.dart';
import '../../domain/workout.dart';

/// Um plano: as semanas com os treinos, o que já foi feito, começar e parar.
class PlanoScreen extends ConsumerWidget {
  const PlanoScreen({super.key, required this.planId});

  final String planId;

  Future<void> _comecar(BuildContext context, WidgetRef ref, AppSettings s) async {
    if (s.planoId != null && s.planoId != planId) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Trocar de plano?'),
          content: Text('Você está no plano “${planById(s.planoId)?.name ?? ''}”. O novo começa do zero.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Trocar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final store = ref.read(settingsStoreProvider);
    await store.save((await store.load()).copyWith(planoId: planId, planoInicio: clock.now()));
    ref.invalidate(settingsProvider);
  }

  Future<void> _parar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Parar o plano?'),
        content: const Text('Os treinos feitos continuam no histórico. Dá para começar de novo quando quiser.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuar no plano')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Parar')),
        ],
      ),
    );
    if (ok != true) return;
    final store = ref.read(settingsStoreProvider);
    await store.save((await store.load()).copyWith(semPlano: true));
    ref.invalidate(settingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plano = planById(planId);
    if (plano == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esse plano não existe.')));
    }
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final feitos = ref.watch(doneWorkoutsProvider).value ?? const <DoneWorkout>[];
    final ativo = s.planoId == planId && s.planoInicio != null;
    final progresso = ativo ? planProgress(plano, s.planoInicio!, feitos) : null;
    var k = 0;
    return Scaffold(
      appBar: AppBar(title: Text(plano.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(plano.summary, style: AppText.corpoForte.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text(
            'Faça os treinos de cada semana nos dias que puder, com um dia de descanso entre eles. '
            'Depois de cada um, conte como foi: o app ajusta as metas dos próximos.',
            style: AppText.suave,
          ),
          if (progresso != null) ...[
            const SizedBox(height: 12),
            Text(
              progresso.finished
                  ? 'Plano concluído! Parabéns.'
                  : '${progresso.doneCount} de ${progresso.total} treinos feitos',
              style: AppText.corpoForte,
            ),
          ],
          for (var w = 0; w < plano.weeks.length; w++) ...[
            const SizedBox(height: 16),
            SectionTitle('Semana ${w + 1}'),
            for (final id in plano.weeks[w])
              Builder(builder: (context) {
                final i = k++;
                final treino = workoutById(id)!;
                final feito = progresso?.done[i] ?? false;
                final proximo = progresso?.nextIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    borderColor: proximo ? AppColors.destaque : null,
                    onTap: () => context.push('/treino/$id'),
                    child: Row(
                      children: [
                        Icon(
                          feito ? Icons.check_circle : (proximo ? Icons.play_circle : Icons.radio_button_unchecked),
                          color: feito || proximo ? AppColors.destaque : AppColors.textoSuave,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(treino.name, style: AppText.corpoForte),
                              Text(
                                treino.rampTest ? 'Teste de FTP · cerca de 20 min' : '${treino.seconds ~/ 60} min · ${treino.level}',
                                style: AppText.suave,
                              ),
                            ],
                          ),
                        ),
                        if (proximo) const Text('próximo', style: TextStyle(color: AppColors.destaqueTexto, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                );
              }),
          ],
          const SizedBox(height: 20),
          if (ativo)
            OutlinedButton(onPressed: () => _parar(context, ref), child: const Text('Parar este plano'))
          else
            FilledButton(onPressed: () => _comecar(context, ref, s), child: const Text('Começar este plano')),
        ],
      ),
    );
  }
}
