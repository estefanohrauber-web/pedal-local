import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_source.dart';
import '../../core/theme/app_theme.dart';

/// Status da bike; tocar abre a tela de conexão.
class BikeChip extends StatelessWidget {
  const BikeChip({super.key, required this.state});

  final BikeState state;

  @override
  Widget build(BuildContext context) {
    final ok = state.connected;
    final texto = ok
        ? state.source!.name
        : state.connection == BikeConnection.caiu
            ? 'Reconectando…'
            : 'Sem bike';
    final cor = ok ? AppColors.destaqueTexto : AppColors.textoSuave;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.push('/bike'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ok ? AppColors.destaqueSuave : AppColors.neutro,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth, size: 16, color: cor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
