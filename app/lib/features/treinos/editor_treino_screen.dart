import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/training.dart';
import '../../domain/workout.dart';
import '../../domain/workout_blocks.dart';
import '../pedal/ride_controller.dart';
import 'bloco_sheet.dart';
import 'workout_chart.dart';

/// Monta um treino com blocos prontos. Com [editId], edita um treino do usuário; com [fromId],
/// começa de uma cópia (de um treino da biblioteca ou do usuário); sem nenhum, de um treino novo
/// com Aquecer e Soltar.
class EditorTreinoScreen extends ConsumerStatefulWidget {
  const EditorTreinoScreen({super.key, this.editId, this.fromId});

  final String? editId;
  final String? fromId;

  @override
  ConsumerState<EditorTreinoScreen> createState() => _EditorTreinoScreenState();
}

class _EditorTreinoScreenState extends ConsumerState<EditorTreinoScreen> {
  final _nome = TextEditingController();

  /// Os blocos, cada um com uma chave fixa para a lista arrastável; null enquanto carrega.
  List<(int, WorkoutBlock)>? _itens;
  int _proximaChave = 0;
  CustomWorkout? _original;
  bool _mudou = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_carregar);
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final meus = await ref.read(customWorkoutsProvider.future);
    CustomWorkout? meu(String? id) {
      for (final m in meus) {
        if (m.id == id) return m;
      }
      return null;
    }

    var nome = '';
    var blocos = [WorkoutBlock.novo(BlockKind.aquecer), WorkoutBlock.novo(BlockKind.soltar)];
    final editar = meu(widget.editId);
    final origem = widget.fromId;
    if (editar != null) {
      _original = editar;
      nome = editar.name;
      blocos = editar.blocks;
    } else if (origem != null) {
      final deMeu = meu(origem);
      final pronto = deMeu == null ? ref.read(findWorkoutProvider)(origem) : null;
      final base = deMeu?.name ?? pronto?.name;
      if (base != null) nome = workoutNameOrDefault('$base (cópia)');
      blocos = deMeu?.blocks ?? (pronto == null ? blocos : blocksFromSteps(pronto.steps));
    }
    if (!mounted) return;
    setState(() {
      _nome.text = nome;
      _itens = [for (final b in blocos) (_proximaChave++, b)];
    });
    _nome.addListener(() {
      if (!_mudou) setState(() => _mudou = true);
    });
  }

  List<WorkoutBlock> get _blocos => [for (final i in _itens ?? const <(int, WorkoutBlock)>[]) i.$2];

  void _trocar(List<(int, WorkoutBlock)> itens) => setState(() {
    _itens = itens;
    _mudou = true;
  });

  Future<void> _editar(int indice, int Function(double) watts) async {
    final itens = _itens!;
    final novo = await editarBloco(context, bloco: itens[indice].$2, watts: watts);
    if (novo == null || !mounted) return;
    _trocar([...itens]..[indice] = (itens[indice].$1, novo));
  }

  Future<void> _adicionar(int Function(double) watts) async {
    final tipo = await escolherTipoDeBloco(context);
    if (tipo == null || !mounted) return;
    final itens = _itens!;
    final onde = insertIndex(_blocos);
    _trocar([...itens]..insert(onde, (_proximaChave++, WorkoutBlock.novo(tipo))));
    await _editar(onde, watts);
  }

  void _duplicar(int indice) {
    final itens = _itens!;
    _trocar([...itens]..insert(indice + 1, (_proximaChave++, itens[indice].$2)));
  }

  void _apagar(int indice) => _trocar([..._itens!]..removeAt(indice));

  Future<void> _salvar() async {
    final blocos = _blocos;
    final problema = workoutProblem(blocos);
    if (problema != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problema)));
      return;
    }
    setState(() => _salvando = true);
    final agora = DateTime.now();
    final original = _original;
    final treino = CustomWorkout(
      id: original?.id ?? newCustomWorkoutId(agora, math.Random()),
      name: workoutNameOrDefault(_nome.text),
      blocks: blocos,
      createdAt: original?.createdAt ?? agora,
      updatedAt: agora,
    );
    await ref.read(customWorkoutsStoreProvider).upsert(treino);
    ref.invalidate(customWorkoutsProvider);
    if (!mounted) return;
    setState(() => _mudou = false);
    if (original == null) {
      context.pushReplacement('/treino/${treino.id}');
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _descartar() async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Descartar as mudanças?'),
          content: Text(_original == null ? 'O treino não será salvo.' : 'O treino fica como estava antes.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuar editando')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Descartar')),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final itens = _itens;
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final ftp = s.ftp ?? defaultFtp(s.pesoKg);
    int watts(double f) => (ftp * f).round();
    return PopScope(
      canPop: !_mudou,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _descartar() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.editId == null ? 'Novo treino' : 'Editar treino'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(onPressed: itens == null || _salvando ? null : _salvar, child: const Text('Salvar')),
            ),
          ],
        ),
        body: itens == null
            ? const Center(child: CircularProgressIndicator())
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                header: _Cabecalho(nome: _nome, blocos: _blocos),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: itens.length >= maxBlocks
                      ? const Text('Um treino pode ter até $maxBlocks blocos.', style: AppText.suave)
                      : TextButton.icon(
                          onPressed: () => _adicionar(watts),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar bloco'),
                        ),
                ),
                itemCount: itens.length,
                onReorderItem: (de, para) => _trocar(moveBlock(itens, de, para)),
                itemBuilder: (context, i) => _CartaoBloco(
                  key: ValueKey(itens[i].$1),
                  bloco: itens[i].$2,
                  watts: watts,
                  onTap: () => _editar(i, watts),
                  onDuplicar: itens.length < maxBlocks ? () => _duplicar(i) : null,
                  onApagar: () => _apagar(i),
                ),
              ),
      ),
    );
  }
}

/// Nome, desenho e números do treino, que mudam a cada ajuste.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.nome, required this.blocos});

  final TextEditingController nome;
  final List<WorkoutBlock> blocos;

  @override
  Widget build(BuildContext context) {
    final w = Workout(
      id: 'previa',
      name: '',
      summary: '',
      category: customWorkoutCategory,
      steps: [for (final b in blocos) ...b.toSteps()],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nome,
            maxLength: maxWorkoutName,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.corpoForte.copyWith(fontSize: 18),
            decoration: const InputDecoration(labelText: 'Nome do treino', hintText: 'Meu treino', counterText: ''),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkoutChart(workout: w, height: 80),
                const SizedBox(height: 8),
                Text(
                  blocos.isEmpty
                      ? 'Sem blocos ainda'
                      : '${w.seconds ~/ 60} min · ${w.level} · carga ${w.stress.round()}',
                  style: AppText.suave.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('Toque num bloco para ajustar. Segure e arraste para mudar a ordem.', style: AppText.suave),
        ],
      ),
    );
  }
}

/// Um bloco na lista: cor da zona, nome, tempo e o resumo em palavras com os watts.
class _CartaoBloco extends StatelessWidget {
  const _CartaoBloco({
    super.key,
    required this.bloco,
    required this.watts,
    required this.onTap,
    required this.onDuplicar,
    required this.onApagar,
  });

  final WorkoutBlock bloco;
  final int Function(double fraction) watts;
  final VoidCallback onTap;
  final VoidCallback? onDuplicar;
  final VoidCallback onApagar;

  @override
  Widget build(BuildContext context) {
    final cor = bloco.kind == BlockKind.livre
        ? zoneColor(1).withValues(alpha: 0.4)
        : zoneColor(zoneFor(math.max(bloco.from, bloco.to)).number);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 42,
              decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(blockHeading(bloco), style: AppText.corpoForte)),
                      Text(formatTime(bloco.totalSeconds.toDouble()), style: AppText.corpoForte),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(describeBlock(bloco, watts), style: AppText.suave, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (bloco.cue != null)
                    Text('“${bloco.cue}”', style: AppText.suave, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções do bloco',
              onSelected: (opcao) => opcao == 'duplicar' ? onDuplicar?.call() : onApagar(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'duplicar', enabled: onDuplicar != null, child: const Text('Duplicar')),
                const PopupMenuItem(value: 'apagar', child: Text('Apagar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
