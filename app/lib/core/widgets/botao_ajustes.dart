import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// A engrenagem do canto de cima de todas as abas: abre os Ajustes.
class BotaoAjustes extends StatelessWidget {
  const BotaoAjustes({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ajustes',
    onPressed: () => context.push('/ajustes'),
    icon: const Icon(Icons.settings_outlined, color: AppColors.texto),
  );
}
