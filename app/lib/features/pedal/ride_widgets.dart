import 'package:flutter/material.dart';

import '../../bike/sim_source.dart';
import '../../core/theme/app_theme.dart';

/// Faixa de aviso no topo do pedal (queda da bike, subida chegando, pausa).
class AvisoFaixa extends StatelessWidget {
  const AvisoFaixa({super.key, required this.texto, this.acao, this.onAcao, this.icone});

  final String texto;
  final String? acao;
  final VoidCallback? onAcao;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            if (icone != null) ...[
              Icon(icone, color: AppColors.avisoTexto),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(texto, style: const TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w700)),
            ),
            if (acao != null) TextButton(onPressed: onAcao, child: Text(acao!)),
          ],
        ),
      ),
    );
  }
}

/// Carga − / + e Pausar / Continuar.
class RideControls extends StatelessWidget {
  const RideControls({
    super.key,
    required this.level,
    required this.paused,
    required this.enabled,
    required this.onLevel,
    required this.onPause,
  });

  final int level;
  final bool paused;
  final bool enabled;
  final void Function(int delta) onLevel;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borda),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Diminuir carga',
                  onPressed: () => onLevel(-1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Carga $level', style: AppText.corpoForte),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Aumentar carga',
                  onPressed: () => onLevel(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.escuro,
            minimumSize: const Size(104, 60),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: enabled ? onPause : null,
          child: Text(paused ? 'Continuar' : 'Pausar'),
        ),
      ],
    );
  }
}

/// Botões da bike simulada (só aparecem com ela).
class SimControls extends StatelessWidget {
  const SimControls({super.key, required this.source});

  final SimSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: source.easier,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Mais fraco', maxLines: 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: source.harder,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Mais forte', maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }
}
