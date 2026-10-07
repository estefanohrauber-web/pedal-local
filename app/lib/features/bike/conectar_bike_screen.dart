import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class ConectarBikeScreen extends ConsumerStatefulWidget {
  const ConectarBikeScreen({super.key});

  @override
  ConsumerState<ConectarBikeScreen> createState() => _ConectarBikeScreenState();
}

class _ConectarBikeScreenState extends ConsumerState<ConectarBikeScreen> {
  StreamSubscription<List<FoundDevice>>? _sub;
  List<FoundDevice> _devices = const [];
  bool _scanning = false;
  bool _showAll = false;
  String? _problem;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    await _sub?.cancel();
    setState(() {
      _problem = null;
      _devices = const [];
      _scanning = true;
    });
    final scanner = ref.read(bikeScannerProvider);
    final problem = await scanner.check();
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _problem = bleProblemText(problem);
        _scanning = false;
      });
      return;
    }
    _sub = scanner.scan().listen(
      (lista) => setState(() => _devices = lista),
      onError: (Object e) => setState(() => _problem = 'Não consegui procurar: $e'),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _connect(FoundDevice d) async {
    await _sub?.cancel();
    setState(() {
      _scanning = false;
      _connectingId = d.id;
    });
    await ref.read(bikeControllerProvider.notifier).useDevice(d.id, d.name);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ref.read(bikeControllerProvider).connected) context.pop();
  }

  Future<void> _useSimulated() async {
    await _sub?.cancel();
    await ref.read(bikeControllerProvider.notifier).useSimulated();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(bikeControllerProvider);
    final visible = _showAll ? _devices : _devices.where((d) => d.likelyBike).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar bike')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (bike.connected) ...[
            AppCard(
              color: AppColors.destaqueSuave,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.destaque),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${bike.source!.name} conectada', style: AppText.corpoForte)),
                  TextButton(
                    onPressed: () => ref.read(bikeControllerProvider.notifier).disconnect(),
                    child: const Text('Desconectar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_problem != null) ...[
            _Aviso(texto: _problem!),
            const SizedBox(height: 12),
          ],
          if (bike.message != null) ...[
            _Aviso(texto: bike.message!),
            const SizedBox(height: 12),
          ],
          if (bike.diagnostic != null) ...[
            AppCard(
              child: SelectableText(bike.diagnostic!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: Text(_showAll ? 'Aparelhos por perto' : 'Bikes encontradas', style: AppText.secao)),
              if (_scanning)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                TextButton(onPressed: _scan, child: const Text('Procurar de novo')),
            ],
          ),
          const SizedBox(height: 8),
          for (final d in visible) ...[
            AppCard(
              onTap: _connectingId == null ? () => _connect(d) : null,
              child: Row(
                children: [
                  Icon(d.likelyBike ? Icons.directions_bike : Icons.bluetooth, color: AppColors.destaque),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: AppText.corpoForte),
                        Text(d.likelyBike ? 'Parece uma bike' : 'Outro aparelho', style: AppText.suave),
                      ],
                    ),
                  ),
                  if (_connectingId == d.id)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  else
                    const Icon(Icons.chevron_right, color: AppColors.textoSuave),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (visible.isEmpty && !_scanning && _problem == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma bike apareceu. Ligue a bike, pedale um pouco para o painel acordar e feche o app FitShow. '
                'Se não resolver, tire e recoloque as pilhas do painel.',
                style: AppText.suave,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar todos os aparelhos'),
            value: _showAll,
            onChanged: (v) => setState(() => _showAll = v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _useSimulated,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Usar bike simulada'),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(16)),
      child: Text(texto, style: const TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w600)),
    );
  }
}
