import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/training.dart';
import '../../domain/workout_blocks.dart';

/// Ajustes de um bloco do treino, numa folha de baixo. Devolve o bloco mudado (null = cancelou).
Future<WorkoutBlock?> editarBloco(
  BuildContext context, {
  required WorkoutBlock bloco,
  required int Function(double fraction) watts,
}) => showModalBottomSheet<WorkoutBlock>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _BlocoSheet(bloco: bloco, watts: watts),
);

/// Escolha do tipo de bloco novo.
Future<BlockKind?> escolherTipoDeBloco(BuildContext context) => showModalBottomSheet<BlockKind>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('Adicionar bloco', style: AppText.secao),
          ),
          for (final tipo in BlockKind.values)
            ListTile(
              title: Text(blockTitles[tipo]!, style: AppText.corpoForte),
              subtitle: Text(blockHints[tipo]!, style: AppText.suave),
              trailing: const Icon(Icons.add_circle_outline, color: AppColors.destaque),
              onTap: () => Navigator.pop(c, tipo),
            ),
        ],
      ),
    ),
  ),
);

class _BlocoSheet extends StatefulWidget {
  const _BlocoSheet({required this.bloco, required this.watts});

  final WorkoutBlock bloco;
  final int Function(double fraction) watts;

  @override
  State<_BlocoSheet> createState() => _BlocoSheetState();
}

class _BlocoSheetState extends State<_BlocoSheet> {
  late WorkoutBlock _b = widget.bloco;
  late final _frase = TextEditingController(text: widget.bloco.cue ?? '');

  @override
  void dispose() {
    _frase.dispose();
    super.dispose();
  }

  void _mudar(WorkoutBlock b) => setState(() => _b = b);

  void _pronto() {
    final frase = _frase.text.trim();
    Navigator.pop(context, _b.copyWith(cue: frase.isEmpty ? null : frase));
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final serie = b.kind == BlockKind.serie;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(blockTitles[b.kind]!, style: AppText.titulo.copyWith(fontSize: 22)),
                if (serie) ...[
                  const _Rotulo('Repetições'),
                  _Passos(
                    nome: 'repetições',
                    valor: '${b.reps} vezes',
                    menos: b.reps > minReps ? () => _mudar(b.copyWith(reps: b.reps - 1)) : null,
                    mais: b.reps < maxReps ? () => _mudar(b.copyWith(reps: b.reps + 1)) : null,
                  ),
                  const _Rotulo('Tiro'),
                  _Tempo(
                    nome: 'o tempo do tiro',
                    segundos: b.seconds,
                    onChanged: (s) => _mudar(b.copyWith(seconds: s)),
                  ),
                  _Intensidade(
                    nome: 'a intensidade do tiro',
                    fracao: b.from,
                    watts: widget.watts,
                    onChanged: (f) => _mudar(b.copyWith(from: f)),
                  ),
                  _Giro(
                    min: b.cadenceMin,
                    max: b.cadenceMax,
                    onChanged: (mn, mx) => _mudar(b.copyWith(cadenceMin: mn, cadenceMax: mx)),
                  ),
                  const _Rotulo('Descanso'),
                  _Tempo(
                    nome: 'o tempo do descanso',
                    segundos: b.restSeconds,
                    onChanged: (s) => _mudar(b.copyWith(restSeconds: s)),
                  ),
                  _Intensidade(
                    nome: 'a intensidade do descanso',
                    fracao: b.restFraction,
                    watts: widget.watts,
                    onChanged: (f) => _mudar(b.copyWith(restFraction: f)),
                  ),
                ] else ...[
                  const _Rotulo('Tempo'),
                  _Tempo(
                    nome: 'o tempo',
                    segundos: b.seconds,
                    onChanged: (s) => _mudar(b.copyWith(seconds: s)),
                  ),
                  if (b.kind == BlockKind.subida) ...[
                    const _Rotulo('Inclinação'),
                    _Passos(
                      nome: 'a inclinação',
                      valor: '${(b.grade * 100).round()} %',
                      menos: b.grade > minGrade + 1e-9
                          ? () => _mudar(b.copyWith(grade: _inclinacao(b.grade, -1)))
                          : null,
                      mais: b.grade < maxGrade - 1e-9 ? () => _mudar(b.copyWith(grade: _inclinacao(b.grade, 1))) : null,
                    ),
                  ],
                  if (b.hasRamp) ...[
                    const _Rotulo('Começa em'),
                    _Intensidade(
                      nome: 'o começo',
                      fracao: b.from,
                      watts: widget.watts,
                      onChanged: (f) => _mudar(b.copyWith(from: f)),
                    ),
                    const _Rotulo('Termina em'),
                    _Intensidade(
                      nome: 'o fim',
                      fracao: b.to,
                      watts: widget.watts,
                      onChanged: (f) => _mudar(b.copyWith(to: f)),
                    ),
                  ] else if (b.kind != BlockKind.livre) ...[
                    const _Rotulo('Intensidade'),
                    _Intensidade(
                      nome: 'a intensidade',
                      fracao: b.from,
                      watts: widget.watts,
                      onChanged: (f) => _mudar(b.copyWith(from: f)),
                    ),
                  ],
                  if (b.kind != BlockKind.livre)
                    _Giro(
                      min: b.cadenceMin,
                      max: b.cadenceMax,
                      onChanged: (mn, mx) => _mudar(b.copyWith(cadenceMin: mn, cadenceMax: mx)),
                    ),
                ],
                _Rotulo(serie ? 'A voz fala no começo de cada tiro' : 'A voz fala no começo do bloco'),
                TextField(
                  controller: _frase,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: serie ? 'Vai!' : 'Segura firme',
                    helperText: 'Opcional. Depois a voz diz o tempo e a meta.',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _pronto, child: const Text('Pronto')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inclinação 1 % mais ou menos, dentro dos limites.
double _inclinacao(double atual, int direcao) =>
    ((atual * 100).round() + direcao).clamp((minGrade * 100).round(), (maxGrade * 100).round()) / 100;

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(texto, style: AppText.corpoForte),
  );
}

/// Um valor com botões − e + (segurar repete).
class _Passos extends StatelessWidget {
  const _Passos({required this.nome, required this.valor, required this.menos, required this.mais});

  /// O que os botões mudam, para a dica e a leitura de tela (“Aumentar a inclinação”).
  final String nome;
  final String valor;
  final VoidCallback? menos;
  final VoidCallback? mais;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borda),
        borderRadius: BorderRadius.circular(14),
        color: AppColors.superficie,
      ),
      child: Row(
        children: [
          _BotaoRepete(icone: Icons.remove, dica: 'Diminuir $nome', onTap: menos),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _BotaoRepete(icone: Icons.add, dica: 'Aumentar $nome', onTap: mais),
        ],
      ),
    );
  }
}

/// Botão que repete enquanto está pressionado.
class _BotaoRepete extends StatefulWidget {
  const _BotaoRepete({required this.icone, required this.dica, required this.onTap});

  final IconData icone;
  final String dica;
  final VoidCallback? onTap;

  @override
  State<_BotaoRepete> createState() => _BotaoRepeteState();
}

class _BotaoRepeteState extends State<_BotaoRepete> {
  Timer? _repete;

  void _parar() {
    _repete?.cancel();
    _repete = null;
  }

  @override
  void dispose() {
    _parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ativo = widget.onTap != null;
    return GestureDetector(
      onLongPressStart: ativo
          ? (_) => _repete = Timer.periodic(const Duration(milliseconds: 110), (_) {
              final acao = widget.onTap; // a mais nova: o valor muda a cada toque
              if (acao == null) return _parar();
              acao();
            })
          : null,
      onLongPressEnd: (_) => _parar(),
      onLongPressCancel: _parar,
      child: IconButton(
        tooltip: widget.dica,
        onPressed: widget.onTap,
        icon: Icon(widget.icone),
        color: AppColors.destaque,
      ),
    );
  }
}

class _Tempo extends StatelessWidget {
  const _Tempo({required this.nome, required this.segundos, required this.onChanged});

  final String nome;
  final int segundos;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _Passos(
    nome: nome,
    valor: formatTime(segundos.toDouble()),
    menos: segundos > minBlockSeconds ? () => onChanged(lessTime(segundos)) : null,
    mais: segundos < maxBlockSeconds ? () => onChanged(moreTime(segundos)) : null,
  );
}

/// Intensidade em palavras (uma por zona) e o ajuste fino de 1 %, com os watts.
class _Intensidade extends StatelessWidget {
  const _Intensidade({required this.nome, required this.fracao, required this.watts, required this.onChanged});

  final String nome;
  final double fracao;
  final int Function(double fraction) watts;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final zona = zoneFor(fracao).number;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < trainingZones.length; i++)
              ChoiceChip(
                label: Text(trainingZones[i].effort),
                selected: zona == i + 1,
                showCheckmark: false,
                selectedColor: zoneColor(i + 1).withValues(alpha: 0.25),
                side: BorderSide(color: zona == i + 1 ? zoneColor(i + 1) : AppColors.borda),
                onSelected: (_) => onChanged(zoneTargets[i]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Passos(
          nome: nome,
          valor: '${(fracao * 100).round()} % · ${watts(fracao)} W',
          menos: fracao > minFraction + 1e-9 ? () => onChanged(clampFraction(fracao - 0.01)) : null,
          mais: fracao < maxFraction - 1e-9 ? () => onChanged(clampFraction(fracao + 0.01)) : null,
        ),
      ],
    );
  }
}

/// Faixas de giro prontas: (mínimo, máximo, nome).
const _faixas = [(70, 80, 'Pesado 70–80'), (85, 95, 'Normal 85–95'), (95, 105, 'Rápido 95–105')];

/// Giro: livre, uma faixa pronta ou “Outro” (mínimo e máximo).
class _Giro extends StatelessWidget {
  const _Giro({required this.min, required this.max, required this.onChanged});

  final int? min;
  final int? max;
  final void Function(int? min, int? max) onChanged;

  @override
  Widget build(BuildContext context) {
    final mn = min;
    final mx = max;
    final pronta = _faixas.any((f) => f.$1 == mn && f.$2 == mx);
    final outro = mn != null && mx != null && !pronta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Rotulo('Giro'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(label: const Text('Livre'), selected: mn == null, onSelected: (_) => onChanged(null, null)),
            for (final f in _faixas)
              ChoiceChip(
                label: Text(f.$3),
                selected: mn == f.$1 && mx == f.$2,
                onSelected: (_) => onChanged(f.$1, f.$2),
              ),
            ChoiceChip(label: const Text('Outro'), selected: outro, onSelected: (_) => onChanged(80, 90)),
          ],
        ),
        if (outro) ...[
          const SizedBox(height: 8),
          _Passos(
            nome: 'o giro mínimo',
            valor: 'mínimo $mn rpm',
            menos: mn > minCadence ? () => onChanged(mn - 5, mx) : null,
            mais: mn + 5 <= mx ? () => onChanged(mn + 5, mx) : null,
          ),
          const SizedBox(height: 8),
          _Passos(
            nome: 'o giro máximo',
            valor: 'máximo $mx rpm',
            menos: mx - 5 >= mn ? () => onChanged(mn, mx - 5) : null,
            mais: mx < maxCadence ? () => onChanged(mn, mx + 5) : null,
          ),
        ],
      ],
    );
  }
}
