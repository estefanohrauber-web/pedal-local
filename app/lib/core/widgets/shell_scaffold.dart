import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/escolher_pedal/escolher_pedal_sheet.dart';
import '../theme/app_theme.dart';

/// Barra de 5 abas: Início · Explorar · (Pedalar) · Treinos · Você.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int branch) => shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.superficie,
          border: Border(top: BorderSide(color: AppColors.borda)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            // Cada item ocupa 1/5 da largura, então a barra nunca passa da tela.
            child: Row(
              children: [
                Expanded(child: _TabItem(icon: Icons.home_outlined, label: 'Início', selected: shell.currentIndex == 0, onTap: () => _go(0))),
                Expanded(child: _TabItem(icon: Icons.explore_outlined, label: 'Explorar', selected: shell.currentIndex == 1, onTap: () => _go(1))),
                Expanded(child: Center(heightFactor: 1, child: _PedalarButton(onTap: () => showEscolherPedal(context)))),
                Expanded(child: _TabItem(icon: Icons.bar_chart_rounded, label: 'Treinos', selected: shell.currentIndex == 2, onTap: () => _go(2))),
                Expanded(child: _TabItem(icon: Icons.person_outline, label: 'Você', selected: shell.currentIndex == 3, onTap: () => _go(3))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.destaque : AppColors.textoSuave;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // Altura mínima de 56 px, mas cresce se a fonte do sistema estiver maior.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              // Encolhe o rótulo se não couber (fonte do sistema grande, tela estreita).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PedalarButton extends StatelessWidget {
  const _PedalarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Material(
        color: AppColors.destaque,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.destaque.withValues(alpha: 0.4),
        child: InkWell(
          key: const Key('botao-pedalar'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 62,
            height: 62,
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34, semanticLabel: 'Pedalar'),
          ),
        ),
      ),
    );
  }
}
