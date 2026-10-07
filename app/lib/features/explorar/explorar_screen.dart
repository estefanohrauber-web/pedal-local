import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Explorar', style: AppText.titulo),
              SizedBox(height: 16),
              AppCard(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: AppColors.destaque),
                    SizedBox(height: 12),
                    Text(
                      'Rotas do seu bairro',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Na próxima etapa você vai criar rotas no mapa, gerar voltas de 5, 10 ou 20 km '
                      'saindo de casa e ver todas as suas rotas aqui.',
                      textAlign: TextAlign.center,
                      style: AppText.suave,
                    ),
                    SizedBox(height: 12),
                    EmBreveTag(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
