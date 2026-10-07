import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../pedal_livre/pedal_livre_card.dart';

class TreinosScreen extends StatelessWidget {
  const TreinosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: const [
            Text('Treinos', style: AppText.titulo),
            SizedBox(height: 16),
            PedalLivreCard(),
            SizedBox(height: 20),
            SectionTitle('Sessões rápidas'),
            EmBreveCard(icon: Icons.timer_outlined, titulo: 'Intervalos 5 × 1 min', texto: '20 min · moderado'),
            SizedBox(height: 10),
            EmBreveCard(icon: Icons.speed, titulo: 'Cadência alta', texto: '15 min · leve, acima de 95 rpm'),
            SizedBox(height: 10),
            EmBreveCard(icon: Icons.terrain_outlined, titulo: 'Subida longa simulada', texto: '30 min · difícil, 4% a 8%'),
            SizedBox(height: 20),
            SectionTitle('Ajustar o app à sua bike'),
            EmBreveCard(
              icon: Icons.tune,
              titulo: 'Teste de calibração',
              texto: 'Por enquanto, ajuste a calibração em Você › Ajustes.',
            ),
            SizedBox(height: 20),
            SectionTitle('Planos'),
            EmBreveCard(icon: Icons.event_note_outlined, titulo: 'Iniciante · 4 semanas', texto: '3 pedais por semana, de 20 a 40 min'),
          ],
        ),
      ),
    );
  }
}
