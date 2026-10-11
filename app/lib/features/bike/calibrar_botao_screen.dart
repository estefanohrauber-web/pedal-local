import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';

/// Calibrar o botão de peso: começando no mais leve, a pessoa gira o botão com uma mão e toca
/// no círculo a cada volta inteira com a outra; o app conta. Depois, ele guia as voltas nas
/// subidas e conta o peso nos watts.
class CalibrarBotaoScreen extends ConsumerStatefulWidget {
  const CalibrarBotaoScreen({super.key});

  @override
  ConsumerState<CalibrarBotaoScreen> createState() =>
      _CalibrarBotaoScreenState();
}

class _CalibrarBotaoScreenState extends ConsumerState<CalibrarBotaoScreen> {
  int _voltas = 0;

  /// Voltas guardadas agora (mostra a tela de pronto).
  int? _salvas;

  void _contar() {
    HapticFeedback.selectionClick();
    setState(() => _voltas++);
  }

  Future<void> _salvar() async {
    final store = ref.read(settingsStoreProvider);
    await store.save((await store.load()).copyWith(voltasBotao: _voltas));
    ref.invalidate(settingsProvider);
    if (mounted) setState(() => _salvas = _voltas);
  }

  @override
  Widget build(BuildContext context) {
    final anterior = ref.watch(settingsProvider).value?.voltasBotao;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('Calibrar o botão'),
      ),
      body: SafeArea(
        child: _salvas == null
            ? _Contagem(
                voltas: _voltas,
                anterior: anterior,
                onContar: _contar,
                onDesfazer: _voltas > 0
                    ? () => setState(() => _voltas--)
                    : null,
                onPronto: _voltas > 0 ? _salvar : null,
              )
            : _Pronto(
                voltas: _salvas!,
                onDeNovo: () => setState(() {
                  _salvas = null;
                  _voltas = 0;
                }),
              ),
      ),
    );
  }
}

class _Contagem extends StatelessWidget {
  const _Contagem({
    required this.voltas,
    required this.anterior,
    required this.onContar,
    required this.onDesfazer,
    required this.onPronto,
  });

  final int voltas;
  final int? anterior;
  final VoidCallback onContar;
  final VoidCallback? onDesfazer;
  final VoidCallback? onPronto;

  @override
  Widget build(BuildContext context) {
    final pilulas = math.max(8, voltas + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              const Text(
                'Toque a cada volta completa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comece com o botão no mais leve. Gire o botão e toque no círculo '
                'sempre que ele der uma volta inteira, até chegar no mais pesado.'
                '${anterior == null ? '' : ' Da última vez foram $anterior.'}',
                style: AppText.subtitulo.copyWith(height: 1.45),
              ),
              const SizedBox(height: 28),
              Center(
                child: Semantics(
                  button: true,
                  label: 'Contar uma volta. $voltas até agora.',
                  excludeSemantics: true,
                  child: Material(
                    color: AppColors.destaque,
                    shape: const CircleBorder(
                      side: BorderSide(
                        color: AppColors.destaqueSuave,
                        width: 10,
                      ),
                    ),
                    child: InkWell(
                      key: const Key('contar-volta'),
                      customBorder: const CircleBorder(),
                      onTap: onContar,
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$voltas',
                              style: const TextStyle(
                                fontSize: 84,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              voltas == 1 ? 'volta' : 'voltas',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'toque aqui',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.destaqueSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < pilulas; i++)
                    Container(
                      width: 22,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < voltas
                            ? AppColors.destaque
                            : AppColors.borda,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Embaixo, sempre à vista: desfazer um toque errado é comum enquanto se gira o botão.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: onDesfazer,
                icon: const Icon(Icons.undo),
                label: const Text('Desfazer o último toque'),
              ),
              const SizedBox(height: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.escuro,
                ),
                onPressed: onPronto,
                child: const Text('Cheguei no mais pesado'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pronto extends StatelessWidget {
  const _Pronto({required this.voltas, required this.onDeNovo});

  final int voltas;
  final VoidCallback onDeNovo;

  @override
  Widget build(BuildContext context) {
    const passos = [
      (Icons.restart_alt, 'Comece cada pedal com o botão no mais leve.'),
      (Icons.trending_up, 'Nas subidas, a voz diz quantas voltas girar.'),
      (Icons.bolt, 'Os watts passam a contar o peso do botão.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.destaque,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pronto! Seu botão dá $voltas ${voltas == 1 ? 'volta' : 'voltas'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              for (final (icone, texto) in passos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Icon(icone, color: AppColors.destaque),
                      const SizedBox(width: 12),
                      Expanded(child: Text(texto, style: AppText.corpoForte)),
                    ],
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: onDeNovo,
                  child: const Text('Contar de novo'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Concluir'),
          ),
        ),
      ],
    );
  }
}
