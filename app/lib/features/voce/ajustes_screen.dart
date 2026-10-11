import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/power.dart';

/// Muda e guarda um ajuste na hora (“tudo se salva sozinho”). Uma gravação espera a outra, para
/// a de uma tecla não passar por cima da seguinte.
final salvarAjusteProvider =
    Provider<Future<void> Function(AppSettings Function(AppSettings))>((ref) {
      var fila = Future<void>.value();
      return (mudar) => fila = fila.catchError((_) {}).then((_) async {
        final store = ref.read(settingsStoreProvider);
        await store.save(mudar(await store.load()));
        ref.invalidate(settingsProvider);
      });
    });

/// Os assuntos dos Ajustes, na ordem da lista.
enum Assunto {
  voce('Você', Icons.person_outline),
  bike('Sua bike', Icons.directions_bike),
  voz('Voz', Icons.volume_up_outlined),
  pedal('Pedal e voltas', Icons.route_outlined),
  treinos('Treinos', Icons.track_changes),
  avancado('Avançado', Icons.build_outlined);

  const Assunto(this.titulo, this.icone);

  final String titulo;
  final IconData icone;
}

/// Ajustes por assunto: cada linha já diz como está e abre a própria tela.
class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  String _resumo(Assunto a, AppSettings s, String? bike) => switch (a) {
    Assunto.voce => [
      if ((s.nome ?? '').trim().isNotEmpty) s.nome!.trim(),
      '${formatNumber(s.pesoKg)} kg',
      'meta ${formatNumber(s.metaSemanalKm)} km',
    ].join(' · '),
    Assunto.bike => [
      bike ?? 'sem bike conectada',
      if (s.voltasBotao != null) 'botão com ${s.voltasBotao} voltas',
    ].join(' · '),
    Assunto.voz =>
      s.voz
          ? (s.vozId == null ? 'Ligada · voz automática' : 'Ligada')
          : 'Desligada',
    Assunto.pedal => 'Margem da volta ${(s.margemVolta * 100).round()}%',
    Assunto.treinos =>
      s.ftp == null ? 'FTP pelo peso' : 'FTP ${formatNumber(s.ftp!)} W',
    Assunto.avancado => 'Potência, estimativa e dados da bike',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value;
    final bike = ref.watch(bikeControllerProvider);
    Widget linha(Assunto a, {bool divisoria = true}) => _Linha(
      assunto: a,
      resumo: s == null
          ? ''
          : _resumo(a, s, bike.connected ? bike.source!.name : null),
      divisoria: divisoria,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                linha(Assunto.voce, divisoria: false),
                linha(Assunto.bike),
                linha(Assunto.voz),
                linha(Assunto.pedal),
                linha(Assunto.treinos),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: linha(Assunto.avancado, divisoria: false),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.destaque,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tudo se salva sozinho e vale a partir do próximo pedal.',
                  style: AppText.suave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.assunto,
    required this.resumo,
    required this.divisoria,
  });

  final Assunto assunto;
  final String resumo;
  final bool divisoria;

  @override
  Widget build(BuildContext context) {
    final avancado = assunto == Assunto.avancado;
    return InkWell(
      onTap: () => context.push('/ajustes/${assunto.name}'),
      child: Container(
        decoration: divisoria
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEF1EF))),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avancado ? AppColors.neutro : AppColors.destaqueSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                assunto.icone,
                color: avancado
                    ? AppColors.textoSuave
                    : AppColors.destaqueTexto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assunto.titulo, style: AppText.corpoForte),
                  if (resumo.isNotEmpty)
                    Text(
                      resumo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.suave,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textoSuave),
          ],
        ),
      ),
    );
  }
}

/// A tela de um assunto. Cada mudança é guardada na hora.
class AjustesAssuntoScreen extends ConsumerStatefulWidget {
  const AjustesAssuntoScreen({super.key, required this.assunto});

  final Assunto assunto;

  @override
  ConsumerState<AjustesAssuntoScreen> createState() =>
      _AjustesAssuntoScreenState();
}

class _AjustesAssuntoScreenState extends ConsumerState<AjustesAssuntoScreen> {
  final _nome = TextEditingController();
  final _peso = TextEditingController();
  final _meta = TextEditingController();
  final _base = TextEditingController();
  final _fator = TextEditingController();
  final _ftp = TextEditingController();
  AppSettings? _s;
  List<VoiceOption> _vozes = const [];

  @override
  void initState() {
    super.initState();
    ref.read(settingsStoreProvider).load().then((s) {
      if (!mounted) return;
      setState(() {
        _s = s;
        _nome.text = s.nome ?? '';
        _peso.text = s.pesoKg.round().toString();
        _meta.text = s.metaSemanalKm.round().toString();
        _base.text = s.base.toString().replaceAll('.', ',');
        _fator.text = s.fator.toString().replaceAll('.', ',');
        _ftp.text = s.ftp == null ? '' : s.ftp!.round().toString();
      });
      if (widget.assunto == Assunto.voz) _carregarVozes(s.vozId);
    });
  }

  @override
  void dispose() {
    for (final c in [_nome, _peso, _meta, _base, _fator, _ftp]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Muda na tela e guarda.
  void _mudar(AppSettings Function(AppSettings) mudar) {
    setState(() => _s = mudar(_s!));
    ref.read(salvarAjusteProvider)(mudar);
  }

  double? _numero(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Vozes em português do celular; o exemplo já sai com a voz guardada.
  Future<void> _carregarVozes(String? guardada) async {
    final voz = ref.read(voiceProvider);
    final vozes = await voz.options();
    if (!mounted) return;
    final existe = vozes.any((v) => v.id == guardada);
    await voz.choose(existe ? guardada : null);
    if (!mounted) return;
    setState(() => _vozes = vozes);
    if (!existe && guardada != null) {
      _mudar((s) => s.copyWith(vozAutomatica: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: Text(widget.assunto.titulo)),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: switch (widget.assunto) {
                Assunto.voce => _voce(),
                Assunto.bike => _bike(s),
                Assunto.voz => _voz(s),
                Assunto.pedal => _pedal(s),
                Assunto.treinos => _treinos(s),
                Assunto.avancado => _avancado(s),
              },
            ),
    );
  }

  static const _numeroTeclado = TextInputType.numberWithOptions(decimal: true);

  List<Widget> _voce() => [
    TextField(
      controller: _nome,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Seu nome',
        hintText: 'Como quer ser chamado',
      ),
      onChanged: (v) => _mudar((s) => s.copyWith(nome: v.trim())),
    ),
    const _Ajuda('Aparece no Início e na aba Você.'),
    const SizedBox(height: 14),
    TextField(
      controller: _peso,
      keyboardType: _numeroTeclado,
      decoration: const InputDecoration(labelText: 'Seu peso (kg)'),
      onChanged: (_) {
        final n = _numero(_peso);
        if (n != null) {
          _mudar((s) => s.copyWith(pesoKg: n.clamp(30, 200).toDouble()));
        }
      },
    ),
    const _Ajuda(
      'Entra na conta da velocidade: quanto mais peso, mais devagar nas subidas.',
    ),
    const SizedBox(height: 14),
    TextField(
      controller: _meta,
      keyboardType: _numeroTeclado,
      decoration: const InputDecoration(labelText: 'Meta semanal (km)'),
      onChanged: (_) {
        final n = _numero(_meta);
        if (n != null) {
          _mudar((s) => s.copyWith(metaSemanalKm: n.clamp(1, 1000).toDouble()));
        }
      },
    ),
    const _Ajuda(
      'A aba Você mostra quanto já foi da meta na semana (segunda a domingo).',
    ),
  ];

  List<Widget> _bike(AppSettings s) {
    final bike = ref.watch(bikeControllerProvider);
    final voltas = s.voltasBotao;
    return [
      AppCard(
        child: Row(
          children: [
            Icon(
              Icons.directions_bike,
              color: bike.connected ? AppColors.destaque : AppColors.textoSuave,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bike.connected
                    ? '${bike.source!.name} conectada'
                    : 'Nenhuma bike conectada',
                style: AppText.corpoForte,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/bike'),
              child: Text(bike.connected ? 'Trocar' : 'Conectar'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SectionTitle('Botão de peso'),
      Text(
        voltas == null
            ? 'Ainda não calibrado.'
            : 'Calibrado: $voltas ${voltas == 1 ? 'volta' : 'voltas'} do mais leve ao mais pesado.',
        style: AppText.corpoForte,
      ),
      const _Ajuda(
        'A bike não sabe a posição do botão. Calibrado, o app diz quantas voltas girar nas '
        'subidas e conta o peso nos watts.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => context.push('/bike/botao'),
              child: Text(
                voltas == null ? 'Calibrar o botão' : 'Calibrar de novo',
              ),
            ),
          ),
          if (voltas != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _mudar((s) => s.copyWith(semBotao: true)),
              child: const Text('Não usar'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 20),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Deixar a bike ajustar a carga',
          style: AppText.corpoForte,
        ),
        subtitle: Text(
          voltas == null
              ? 'Nos treinos, se a bike aceitar comando (modo ERG), ela segura a meta sozinha.'
              : 'Com o botão calibrado, a bike é de botão manual: o app guia pela voz.',
          style: AppText.suave,
        ),
        value:
            voltas == null &&
            s.controleBike, // calibrado: a bike não ajusta (o app guia)
        onChanged: voltas != null
            ? null
            : (v) => _mudar((s) => s.copyWith(controleBike: v)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => context.push('/bike/dados'),
        icon: const Icon(Icons.sensors),
        label: const Text('Ver o que a bike envia'),
      ),
    ];
  }

  List<Widget> _voz(AppSettings s) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Avisos falados no pedal', style: AppText.corpoForte),
      value: s.voz,
      onChanged: (v) => _mudar((s) => s.copyWith(voz: v)),
    ),
    const _Ajuda(
      'O celular fala as subidas e descidas que vêm pela frente, cada quilômetro, as voltas, '
      'os 200 metros finais e como você está contra o fantasma. A música abaixa enquanto ele fala. '
      'Dá para ligar e desligar também no pedal, no botão do alto-falante.',
    ),
    if (_vozes.isNotEmpty) ...[
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(
        initialValue: _vozes.any((v) => v.id == s.vozId) ? s.vozId : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Qual voz'),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Automática (a mais natural)'),
          ),
          for (final v in _vozes)
            DropdownMenuItem(value: v.id, child: Text(v.label)),
        ],
        onChanged: (id) {
          ref.read(voiceProvider).choose(id);
          _mudar((s) => s.copyWith(vozId: id, vozAutomatica: id == null));
        },
      ),
      const _Ajuda('Escolha uma e toque em “Ouvir um exemplo” para comparar.'),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => ref
            .read(voiceProvider)
            .speak('Subida de 6 por cento chegando. Aumente a carga da bike.'),
        icon: const Icon(Icons.record_voice_over_outlined),
        label: const Text('Ouvir um exemplo'),
      ),
    ),
  ];

  List<Widget> _pedal(AppSettings s) {
    final margem = (s.margemVolta * 100).roundToDouble().clamp(0.0, 10.0);
    return [
      Text(
        'Margem para fechar a volta: ${margem.round()}%',
        style: AppText.corpoForte,
      ),
      Slider(
        value: margem,
        min: 0,
        max: 10,
        divisions: 10,
        label: '${margem.round()}%',
        onChanged: (v) => _mudar((s) => s.copyWith(margemVolta: v / 100)),
      ),
      const _Ajuda(
        'Numa volta fechada, se você encerrar logo depois de completar a volta, o que passou até essa '
        'porcentagem é descartado e a volta fica certinha. Numa volta de 3 km, 3% são 90 m.',
      ),
      if (s.voltasBotao == null) ...[
        const SizedBox(height: 20),
        Text('Carga inicial: ${s.cargaPadrao}', style: AppText.corpoForte),
        Slider(
          value: s.cargaPadrao.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '${s.cargaPadrao}',
          onChanged: (v) => _mudar((s) => s.copyWith(cargaPadrao: v.round())),
        ),
        const _Ajuda(
          'O app não consegue ler o botão de carga da bike. Durante o pedal, use o − e o + em '
          '“Mais dados” para acompanhar o botão; aqui fica a carga com que o pedal começa. '
          'Calibrando o botão (em Sua bike), o pedal sempre começa no mais leve.',
        ),
      ],
    ];
  }

  List<Widget> _treinos(AppSettings s) => [
    TextField(
      controller: _ftp,
      keyboardType: _numeroTeclado,
      decoration: InputDecoration(
        labelText: 'Seu FTP (W)',
        hintText: 'Vazio: ${formatNumber(s.pesoKg * 2)} W, pelo peso',
      ),
      onChanged: (_) {
        final n = _numero(_ftp);
        if (n != null) {
          _mudar((s) => s.copyWith(ftp: n.clamp(50, 600).roundToDouble()));
        }
      },
    ),
    const _Ajuda(
      'A força que você aguenta por uma hora. As metas dos treinos saem dele. '
      'O teste de rampa, na aba Treinos, mede e preenche sozinho.',
    ),
    if ((s.intensidade - 1).abs() > 0.001) ...[
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              'Ajuste pelas suas respostas: ${s.intensidade > 1 ? '+' : ''}${((s.intensidade - 1) * 100).round()}% nas metas.',
              style: AppText.suave,
            ),
          ),
          TextButton(
            onPressed: () => _mudar((s) => s.copyWith(intensidade: 1)),
            child: const Text('Zerar'),
          ),
        ],
      ),
    ],
  ];

  String get _explicaModo => switch (_s!.modoPotencia) {
    PowerMode.auto =>
      'Usa a potência que a bike mandar. Se em 10 segundos ela não mandar nada, o app estima pela '
          'cadência e pela carga. Com o botão de peso calibrado, estima pelo botão. Recomendado.',
    PowerMode.bike => 'Só usa a potência que a bike mede.',
    PowerMode.estimada => 'Sempre estima pela cadência e pela carga que você marca no pedal, mesmo que a bike mande potência.',
  };

  String get _exemplo {
    final base = _numero(_base) ?? 0.6;
    final fator = _numero(_fator) ?? 0.25;
    final carga = _s!.cargaPadrao;
    return 'Exemplo: 80 rpm na carga $carga = ${formatNumber(80 * (base + fator * carga))} W.';
  }

  List<Widget> _avancado(AppSettings s) => [
    const SectionTitle('Potência'),
    SegmentedButton<PowerMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: PowerMode.auto, label: Text('Automática')),
        ButtonSegment(value: PowerMode.bike, label: Text('Da bike')),
        ButtonSegment(value: PowerMode.estimada, label: Text('Estimada')),
      ],
      selected: {s.modoPotencia},
      onSelectionChanged: (v) =>
          _mudar((s) => s.copyWith(modoPotencia: v.first)),
    ),
    _Ajuda(_explicaModo),
    if (s.modoPotencia == PowerMode.bike)
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.avisoFundo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Atenção: se a sua bike não manda potência, ela fica em 0 e a bike virtual não anda. '
          'Confira em “Ver o que a bike envia”.',
          style: TextStyle(
            color: AppColors.avisoTexto,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    const SizedBox(height: 24),
    const SectionTitle('Calibração da estimativa'),
    const _Ajuda('Potência estimada = RPM × (base + fator × carga).'),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _base,
            keyboardType: _numeroTeclado,
            decoration: const InputDecoration(labelText: 'Base'),
            onChanged: (_) {
              final n = _numero(_base);
              if (n != null) {
                _mudar((s) => s.copyWith(base: n.clamp(0, 5).toDouble()));
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _fator,
            keyboardType: _numeroTeclado,
            decoration: const InputDecoration(labelText: 'Fator'),
            onChanged: (_) {
              final n = _numero(_fator);
              if (n != null) {
                _mudar((s) => s.copyWith(fator: n.clamp(0, 5).toDouble()));
              }
            },
          ),
        ),
      ],
    ),
    _Ajuda(_exemplo),
    const SizedBox(height: 24),
    OutlinedButton.icon(
      onPressed: () => context.push('/bike/dados'),
      icon: const Icon(Icons.sensors),
      label: const Text('Ver o que a bike envia'),
    ),
    const _Ajuda(
      'Mostra ao vivo o que a sua bike manda e o diário da conexão.',
    ),
  ];
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
