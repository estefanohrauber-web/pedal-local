import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/power.dart';

class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _peso = TextEditingController();
  final _meta = TextEditingController();
  final _base = TextEditingController();
  final _fator = TextEditingController();
  AppSettings? _settings;
  PowerMode _modo = PowerMode.auto;
  double _carga = 4;

  @override
  void initState() {
    super.initState();
    ref.read(settingsStoreProvider).load().then((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _peso.text = s.pesoKg.round().toString();
        _meta.text = s.metaSemanalKm.round().toString();
        _base.text = s.base.toString();
        _fator.text = s.fator.toString();
        _modo = s.modoPotencia;
        _carga = s.cargaPadrao.toDouble();
      });
    });
  }

  @override
  void dispose() {
    _peso.dispose();
    _meta.dispose();
    _base.dispose();
    _fator.dispose();
    super.dispose();
  }

  double? _numero(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _salvar() async {
    final s = _settings!;
    final novo = s.copyWith(
      pesoKg: _numero(_peso)?.clamp(30, 200).toDouble(),
      metaSemanalKm: _numero(_meta)?.clamp(1, 1000).toDouble(),
      base: _numero(_base)?.clamp(0, 5).toDouble(),
      fator: _numero(_fator)?.clamp(0, 5).toDouble(),
      modoPotencia: _modo,
      cargaPadrao: _carga.round(),
    );
    await ref.read(settingsStoreProvider).save(novo);
    ref.invalidate(settingsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes salvos')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    const numeroTeclado = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                TextField(
                  controller: _peso,
                  keyboardType: numeroTeclado,
                  decoration: const InputDecoration(labelText: 'Seu peso (kg)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _meta,
                  keyboardType: numeroTeclado,
                  decoration: const InputDecoration(labelText: 'Meta semanal (km)'),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Potência'),
                SegmentedButton<PowerMode>(
                  segments: const [
                    ButtonSegment(value: PowerMode.auto, label: Text('Automática')),
                    ButtonSegment(value: PowerMode.bike, label: Text('Da bike')),
                    ButtonSegment(value: PowerMode.estimada, label: Text('Estimada')),
                  ],
                  selected: {_modo},
                  onSelectionChanged: (v) => setState(() => _modo = v.first),
                ),
                const SizedBox(height: 20),
                Text('Carga inicial no botão da bike: ${_carga.round()}', style: AppText.corpoForte),
                Slider(
                  value: _carga,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_carga.round()}',
                  onChanged: (v) => setState(() => _carga = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Calibração da estimativa: potência = RPM × (base + fator × carga)',
                  style: AppText.suave,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _base,
                        keyboardType: numeroTeclado,
                        decoration: const InputDecoration(labelText: 'Base'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fator,
                        keyboardType: numeroTeclado,
                        decoration: const InputDecoration(labelText: 'Fator'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                FilledButton(onPressed: _salvar, child: const Text('Salvar')),
                const SizedBox(height: 12),
                const Text(
                  'Integrações (Strava, Health Connect) e tema escuro chegam nas próximas versões.',
                  style: AppText.suave,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Center(child: EmBreveTag()),
                const SizedBox(height: 8),
                const Text('Os ajustes valem a partir do próximo pedal.', style: AppText.suave),
              ],
            ),
    );
  }
}
