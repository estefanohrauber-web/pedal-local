import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice.dart';
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
  final _nome = TextEditingController();
  final _peso = TextEditingController();
  final _meta = TextEditingController();
  final _base = TextEditingController();
  final _fator = TextEditingController();
  final _ftp = TextEditingController();
  AppSettings? _settings;
  PowerMode _modo = PowerMode.auto;
  double _carga = 4;
  double _margem = 3;
  bool _voz = true;
  String? _vozId;
  List<VoiceOption> _vozes = const [];
  bool _controleBike = true;
  double _intensidade = 1;

  @override
  void initState() {
    super.initState();
    ref.read(settingsStoreProvider).load().then((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _nome.text = s.nome ?? '';
        _peso.text = s.pesoKg.round().toString();
        _meta.text = s.metaSemanalKm.round().toString();
        _base.text = s.base.toString().replaceAll('.', ',');
        _fator.text = s.fator.toString().replaceAll('.', ',');
        _modo = s.modoPotencia;
        _carga = s.cargaPadrao.toDouble();
        _margem = (s.margemVolta * 100).roundToDouble().clamp(0, 10);
        _voz = s.voz;
        _vozId = s.vozId;
        _ftp.text = s.ftp == null ? '' : s.ftp!.round().toString();
        _controleBike = s.controleBike;
        _intensidade = s.intensidade;
      });
      _carregarVozes(s.vozId);
    });
  }

  /// Vozes em português do celular; o exemplo já sai com a voz guardada.
  Future<void> _carregarVozes(String? guardada) async {
    final voz = ref.read(voiceProvider);
    final vozes = await voz.options();
    if (!mounted) return;
    final existe = vozes.any((v) => v.id == guardada);
    await voz.choose(existe ? guardada : null);
    if (!mounted) return;
    setState(() {
      _vozes = vozes;
      if (!existe) _vozId = null;
    });
  }

  void _escolherVoz(String? id) {
    setState(() => _vozId = id);
    ref.read(voiceProvider).choose(id);
  }

  @override
  void dispose() {
    for (final c in [_nome, _peso, _meta, _base, _fator, _ftp]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _numero(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _salvar() async {
    final s = _settings!;
    final novo = s.copyWith(
      nome: _nome.text.trim(),
      pesoKg: _numero(_peso)?.clamp(30, 200).toDouble(),
      metaSemanalKm: _numero(_meta)?.clamp(1, 1000).toDouble(),
      base: _numero(_base)?.clamp(0, 5).toDouble(),
      fator: _numero(_fator)?.clamp(0, 5).toDouble(),
      modoPotencia: _modo,
      cargaPadrao: _carga.round(),
      margemVolta: _margem / 100,
      voz: _voz,
      vozId: _vozId,
      vozAutomatica: _vozId == null,
      ftp: _numero(_ftp)?.clamp(50, 600).roundToDouble(),
      controleBike: _controleBike,
      intensidade: _intensidade,
    );
    await ref.read(settingsStoreProvider).save(novo);
    ref.invalidate(settingsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes salvos')));
    context.pop();
  }

  String get _explicaModo => switch (_modo) {
        PowerMode.auto =>
          'Usa a potência que a bike mandar. Se em 10 segundos ela não mandar nada, o app estima pela cadência e pela carga. Recomendado.',
        PowerMode.bike => 'Só usa a potência que a bike mede.',
        PowerMode.estimada =>
          'Sempre estima pela cadência e pela carga que você marca no pedal, mesmo que a bike mande potência.',
      };

  String get _exemplo {
    final base = _numero(_base) ?? 0.6;
    final fator = _numero(_fator) ?? 0.25;
    final carga = _carga.round();
    return 'Exemplo: 80 rpm na carga $carga = ${formatNumber(80 * (base + fator * carga))} W.';
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
                const SectionTitle('Perfil'),
                TextField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Seu nome', hintText: 'Como quer ser chamado'),
                ),
                const _Ajuda('Aparece no Início e na aba Você.'),
                const SizedBox(height: 14),
                TextField(
                  controller: _peso,
                  keyboardType: numeroTeclado,
                  decoration: const InputDecoration(labelText: 'Seu peso (kg)'),
                ),
                const _Ajuda('Entra na conta da velocidade: quanto mais peso, mais devagar nas subidas.'),
                const SizedBox(height: 14),
                TextField(
                  controller: _meta,
                  keyboardType: numeroTeclado,
                  decoration: const InputDecoration(labelText: 'Meta semanal (km)'),
                ),
                const _Ajuda('A aba Você mostra quanto já foi da meta na semana (segunda a domingo).'),
                const SizedBox(height: 24),
                const SectionTitle('Voltas'),
                Text('Margem para fechar a volta: ${_margem.round()}%', style: AppText.corpoForte),
                Slider(
                  value: _margem,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '${_margem.round()}%',
                  onChanged: (v) => setState(() => _margem = v),
                ),
                const _Ajuda(
                  'Numa volta fechada, se você encerrar logo depois de completar a volta, o que passou até essa '
                  'porcentagem é descartado e a volta fica certinha. Numa volta de 3 km, 3% são 90 m.',
                ),
                const SizedBox(height: 24),
                const SectionTitle('Voz'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisos falados no pedal', style: AppText.corpoForte),
                  value: _voz,
                  onChanged: (v) => setState(() => _voz = v),
                ),
                const _Ajuda(
                  'O celular fala as subidas e descidas que vêm pela frente, cada quilômetro, as voltas, '
                  'os 200 metros finais e como você está contra o fantasma. A música abaixa enquanto ele fala. '
                  'Dá para ligar e desligar também no pedal, no botão do alto-falante.',
                ),
                if (_vozes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _vozId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Qual voz'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Automática (a mais natural)')),
                      for (final v in _vozes) DropdownMenuItem(value: v.id, child: Text(v.label)),
                    ],
                    onChanged: _escolherVoz,
                  ),
                  const _Ajuda('Escolha uma e toque em “Ouvir um exemplo” para comparar.'),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => ref.read(voiceProvider).speak('Subida de 6 por cento chegando. Aumente a carga da bike.'),
                    icon: const Icon(Icons.record_voice_over_outlined),
                    label: const Text('Ouvir um exemplo'),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Treinos'),
                TextField(
                  controller: _ftp,
                  keyboardType: numeroTeclado,
                  decoration: InputDecoration(
                    labelText: 'Seu FTP (W)',
                    hintText: 'Vazio: ${formatNumber((_numero(_peso) ?? 75) * 2)} W, pelo peso',
                  ),
                ),
                const _Ajuda(
                  'A força que você aguenta por uma hora. As metas dos treinos saem dele. '
                  'O teste de rampa, na aba Treinos, mede e preenche sozinho.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deixar a bike ajustar a carga', style: AppText.corpoForte),
                  subtitle: const Text(
                    'Nos treinos, se a bike aceitar comando (modo ERG), ela segura a meta sozinha.',
                    style: AppText.suave,
                  ),
                  value: _controleBike,
                  onChanged: (v) => setState(() => _controleBike = v),
                ),
                if ((_intensidade - 1).abs() > 0.001)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ajuste pelas suas respostas: ${_intensidade > 1 ? '+' : ''}${((_intensidade - 1) * 100).round()}% nas metas.',
                          style: AppText.suave,
                        ),
                      ),
                      TextButton(onPressed: () => setState(() => _intensidade = 1), child: const Text('Zerar')),
                    ],
                  ),
                const SizedBox(height: 24),
                const SectionTitle('Potência'),
                SegmentedButton<PowerMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: PowerMode.auto, label: Text('Automática')),
                    ButtonSegment(value: PowerMode.bike, label: Text('Da bike')),
                    ButtonSegment(value: PowerMode.estimada, label: Text('Estimada')),
                  ],
                  selected: {_modo},
                  onSelectionChanged: (v) => setState(() => _modo = v.first),
                ),
                _Ajuda(_explicaModo),
                if (_modo == PowerMode.bike)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(14)),
                    child: const Text(
                      'Atenção: se a sua bike não manda potência, ela fica em 0 e a bike virtual não anda. '
                      'Confira em “Ver o que a bike envia”.',
                      style: TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Carga inicial: ${_carga.round()}', style: AppText.corpoForte),
                Slider(
                  value: _carga,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_carga.round()}',
                  onChanged: (v) => setState(() => _carga = v),
                ),
                const _Ajuda(
                  'O app não consegue ler o botão de carga da bike. Durante o pedal, use o − e o + para '
                  'acompanhar o botão; aqui fica a carga com que o pedal começa.',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/bike/dados'),
                  icon: const Icon(Icons.sensors),
                  label: const Text('Ver o que a bike envia'),
                ),
                const _Ajuda('Mostra ao vivo se a sua bike manda potência e o nível do botão de carga.'),
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const Key('avancado'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('Avançado: calibração da estimativa', style: AppText.corpoForte),
                    children: [
                      const _Ajuda('Potência estimada = RPM × (base + fator × carga).'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _base,
                              keyboardType: numeroTeclado,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Base'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _fator,
                              keyboardType: numeroTeclado,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Fator'),
                            ),
                          ),
                        ],
                      ),
                      _Ajuda(_exemplo),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _salvar, child: const Text('Salvar')),
                const SizedBox(height: 12),
                const Text(
                  'Integrações (Strava, Health Connect), tema escuro e a calibração guiada chegam nas próximas versões.',
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

class _Ajuda extends StatelessWidget {
  const _Ajuda(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(texto, style: AppText.suave),
    );
  }
}
