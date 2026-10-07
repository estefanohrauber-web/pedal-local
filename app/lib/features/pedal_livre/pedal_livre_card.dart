import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/theme/app_theme.dart';

/// Cartão escuro de destaque: abre o pedal livre (ou a conexão, se não houver bike).
class PedalLivreCard extends ConsumerWidget {
  const PedalLivreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(bikeControllerProvider.select((s) => s.connected));
    return Material(
      color: AppColors.escuro,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(connected ? '/pedal-livre' : '/bike'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFF2A3832), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF7FD9A8)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pedal livre', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Só os dados da bike, no seu ritmo', style: TextStyle(color: Color(0xFFB9C6BF), fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
