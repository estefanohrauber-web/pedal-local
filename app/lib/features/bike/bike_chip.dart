import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_live.dart';
import '../../bike/bike_source.dart';
import '../../core/theme/app_theme.dart';
import 'selo_ao_vivo.dart';

/// O selo da bike na barra do topo: a bolinha do estado (verde = dados chegando) e o nome;
/// sem bike, “Conectar”. Tocar abre a tela de conexão.
class BikeChip extends ConsumerWidget {
  const BikeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);
    final live = ref.watch(bikeLiveProvider);
    final fonte = bike.source;
    final conectada = bike.connected && fonte != null;
    final (estado, cor) = textoAoVivo(live.status, simulada: fonte?.simulated ?? false);
    final texto = conectada
        ? fonte.name
        : bike.connection == BikeConnection.caiu
            ? 'Reconectando…'
            : 'Conectar';
    return Semantics(
      button: true,
      label: conectada ? 'Bike ${fonte.name}, $estado' : texto,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push('/bike'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            border: Border.all(color: const Color(0xFFD5DCD8)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conectada)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: live.status == BikeLive.aoVivo ? const Color(0xFF1FB866) : cor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const Icon(Icons.bluetooth, size: 16, color: AppColors.destaqueTexto),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: conectada ? AppColors.texto : AppColors.destaqueTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
