import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  /// Borda grossa nesta cor (cartão escolhido); sem ela, a borda fina do tema.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final borda = borderColor;
    return Card(
      color: color,
      shape: borda == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borda, width: 2),
            ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class EmBreveTag extends StatelessWidget {
  const EmBreveTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.neutro, borderRadius: BorderRadius.circular(999)),
      child: const Text(
        'em breve',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textoSuave),
      ),
    );
  }
}

class EmBreveCard extends StatelessWidget {
  const EmBreveCard({super.key, required this.icon, required this.titulo, required this.texto});

  final IconData icon;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.neutro, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.textoSuave),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.corpoForte),
                const SizedBox(height: 2),
                Text(texto, style: AppText.suave),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const EmBreveTag(),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Números grandes encolhem em vez de quebrar linha (ex.: "1:02:05" numa coluna estreita).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.texto,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoSuave),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppText.secao),
      );
}
