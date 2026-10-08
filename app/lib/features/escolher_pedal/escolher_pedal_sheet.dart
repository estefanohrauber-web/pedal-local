import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

Future<void> showEscolherPedal(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const EscolherPedalSheet(),
    );

class EscolherPedalSheet extends ConsumerWidget {
  const EscolherPedalSheet({super.key});

  void _ir(BuildContext context, String destino, {bool trocarAba = false}) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (trocarAba) {
      router.go(destino);
    } else {
      router.push(destino);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Como vai ser hoje?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _Opcao(
              icon: Icons.route,
              titulo: 'Seguir uma rota',
              texto: 'Escolha a rota na aba Explorar',
              onTap: () => _ir(context, '/explorar', trocarAba: true),
            ),
            const _Opcao(
              icon: Icons.bar_chart_rounded,
              titulo: 'Pedal livre',
              texto: 'Só os dados da bike, sem mapa',
              selecionada: true,
            ),
            const _Opcao(icon: Icons.flag_outlined, titulo: 'Contra o fantasma', texto: 'Bata o seu recorde numa rota', emBreve: true),
            const _Opcao(icon: Icons.timer_outlined, titulo: 'Treino', texto: 'Intervalos e sessões guiadas', emBreve: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bike.connected ? AppColors.destaqueSuave : AppColors.avisoFundo,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth, size: 18, color: bike.connected ? AppColors.destaqueTexto : AppColors.avisoTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bike.connected ? '${bike.source!.name} conectada' : 'Nenhuma bike conectada',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: bike.connected ? AppColors.destaqueTexto : AppColors.avisoTexto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(bike.connected ? 'Começar pedal livre' : 'Conectar a bike'),
              onPressed: () => _ir(context, bike.connected ? '/pedal-livre' : '/bike'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icon,
    required this.titulo,
    required this.texto,
    this.selecionada = false,
    this.emBreve = false,
    this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String texto;
  final bool selecionada;
  final bool emBreve;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: emBreve ? 0.6 : 1,
        child: Material(
          color: selecionada ? const Color(0xFFF3FAF6) : AppColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selecionada ? AppColors.destaque : AppColors.borda,
              width: selecionada ? 2.5 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selecionada ? AppColors.destaque : AppColors.neutro,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: selecionada ? Colors.white : AppColors.texto),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(texto, style: AppText.suave),
                      ],
                    ),
                  ),
                  if (emBreve) const EmBreveTag(),
                  if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textoSuave),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
