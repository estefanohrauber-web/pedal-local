import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_live.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_scanner.dart';
import '../../bike/bike_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';

/// Conectar a bike como uma lista de verificação: Bluetooth, bike achada, conectada e dados
/// chegando, já com os números ao vivo. Cada etapa diz o que fazer quando trava.
class ConectarBikeScreen extends ConsumerStatefulWidget {
  const ConectarBikeScreen({super.key});

  @override
  ConsumerState<ConectarBikeScreen> createState() => _ConectarBikeScreenState();
}

class _ConectarBikeScreenState extends ConsumerState<ConectarBikeScreen>
    with WidgetsBindingObserver {
  StreamSubscription<List<FoundDevice>>? _sub;
  List<FoundDevice> _devices = const [];
  bool _scanning = false;
  bool _checando = true;
  bool _showAll = false;
  String? _problem;
  BleProblem? _bleProblem;
  String? _connectingId;

  /// A bike de sempre já foi tentada sozinha nesta tela (só uma vez).
  bool _tentouAUltima = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  /// Ao voltar da caixa de permissão (ou das configurações do Bluetooth), tenta de novo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _bleProblem != null &&
        !_scanning) {
      _scan();
    }
  }

  Future<void> _scan() async {
    await _sub?.cancel();
    setState(() {
      _problem = null;
      _bleProblem = null;
      _devices = const [];
      _scanning = true;
      _checando = true;
    });
    final scanner = ref.read(bikeScannerProvider);
    final problem = await scanner.check();
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _bleProblem = problem;
        _problem = bleProblemText(problem);
        _scanning = false;
        _checando = false;
      });
      return;
    }
    setState(() => _checando = false);
    _sub = scanner.scan().listen(
      (lista) {
        setState(() => _devices = lista);
        _conectarAUltima(lista);
      },
      onError: (Object e) =>
          setState(() => _problem = 'Não consegui procurar: $e'),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  /// A bike de sempre apareceu e nenhuma está conectada: conecta sozinho.
  void _conectarAUltima(List<FoundDevice> lista) {
    final bike = ref.read(bikeControllerProvider);
    final ultima = ref.read(settingsProvider).value?.ultimaBikeId;
    final ocupado = bike.connected || _connectingId != null;
    if (_tentouAUltima || ultima == null || ocupado) return;
    for (final d in lista) {
      if (d.id == ultima) {
        _tentouAUltima = true;
        _connect(d);
        return;
      }
    }
  }

  Future<void> _connect(FoundDevice d) async {
    // Sem esperar: pode ser chamado de dentro da própria busca (a bike de sempre apareceu).
    unawaited(_sub?.cancel());
    _sub = null;
    setState(() {
      _scanning = false;
      _connectingId = d.id;
    });
    await ref.read(bikeControllerProvider.notifier).useDevice(d.id, d.name);
    if (mounted) setState(() => _connectingId = null);
  }

  Future<void> _useSimulated() async {
    await _sub?.cancel();
    await ref.read(bikeControllerProvider.notifier).useSimulated();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(bikeControllerProvider);
    final live = ref.watch(bikeLiveProvider);
    final ultima = ref.watch(settingsProvider).value?.ultimaBikeId;
    final conectada = bike.connected ? bike.source : null;
    final outras = (_showAll ? _devices : _devices.where((d) => d.likelyBike))
        .where((d) => conectada == null || d.name != conectada.name)
        .toList();
    final bikesPorPerto = _devices.where((d) => d.likelyBike).toList();
    final conectando =
        _connectingId != null || bike.connection == BikeConnection.conectando;
    final nomeConectando = _devices
        .where((d) => d.id == _connectingId)
        .firstOrNull
        ?.name;
    final ultimaPorPerto = bikesPorPerto
        .where((d) => d.id == ultima)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Conectar bike')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _Etapa(
                  estado: _checando
                      ? _Estado.agora
                      : _bleProblem != null
                      ? _Estado.problema
                      : _Estado.feita,
                  titulo: _bleProblem == null
                      ? 'Bluetooth ligado'
                      : 'Bluetooth',
                  texto: _checando ? 'Conferindo o Bluetooth…' : _problem,
                  acao: _bleProblem == null
                      ? null
                      : TextButton(
                          onPressed: _scan,
                          child: const Text('Tentar de novo'),
                        ),
                ),
                _Etapa(
                  divisoria: true,
                  estado: conectada != null || bikesPorPerto.isNotEmpty
                      ? _Estado.feita
                      : _scanning
                      ? _Estado.agora
                      : _bleProblem != null
                      ? _Estado.esperando
                      : _Estado.problema,
                  titulo: conectada != null
                      ? '${conectada.name} encontrada'
                      : ultimaPorPerto != null
                      ? '${ultimaPorPerto.name} encontrada'
                      : bikesPorPerto.isNotEmpty
                      ? (bikesPorPerto.length == 1
                            ? '1 bike por perto'
                            : '${bikesPorPerto.length} bikes por perto')
                      : 'Achar a bike',
                  texto: conectada != null
                      ? null
                      : ultimaPorPerto != null
                      ? 'A bike que você usou da última vez'
                      : bikesPorPerto.isNotEmpty
                      ? 'Toque nela, logo abaixo'
                      : _scanning
                      ? 'Procurando bikes por perto…'
                      : _bleProblem != null
                      ? null
                      : 'Nenhuma bike apareceu. Pedale um pouco para o painel acordar e feche o app FitShow. '
                            'Se não resolver, tire e recoloque as pilhas do painel.',
                  acao:
                      !_scanning &&
                          conectada == null &&
                          _bleProblem == null &&
                          bikesPorPerto.isEmpty
                      ? TextButton(
                          onPressed: _scan,
                          child: const Text('Procurar de novo'),
                        )
                      : null,
                ),
                _Etapa(
                  divisoria: true,
                  estado: conectada != null
                      ? _Estado.feita
                      : conectando
                      ? _Estado.agora
                      : bike.message != null
                      ? _Estado.problema
                      : _Estado.esperando,
                  titulo: conectada != null
                      ? 'Conectada'
                      : conectando
                      ? 'Conectando${nomeConectando == null ? '' : ' a $nomeConectando'}…'
                      : 'Conectar',
                  texto: conectada != null
                      ? (conectada.simulated
                            ? 'Bike simulada, para testar sem a bike'
                            : 'Ela respondeu e começou o pedal')
                      : conectando
                      ? null
                      : bike.message,
                  acao: conectada == null
                      ? null
                      : TextButton(
                          onPressed: () => ref
                              .read(bikeControllerProvider.notifier)
                              .disconnect(),
                          child: const Text('Desconectar'),
                        ),
                ),
                _Etapa(
                  divisoria: true,
                  estado: switch (live.status) {
                    BikeLive.aoVivo => _Estado.feita,
                    BikeLive.parada || BikeLive.esperando => _Estado.agora,
                    _ => _Estado.esperando,
                  },
                  titulo: 'Dados chegando',
                  texto: switch (live.status) {
                    BikeLive.aoVivo => null,
                    BikeLive.parada => 'A bike responde, mas está parada: pedale um pouco para conferir.',
                    BikeLive.esperando when live.waiting.inSeconds >= 10 => 'Nada chegando ainda. Pedale para o painel acordar; se o app FitShow estiver aberto, feche.',
                    BikeLive.esperando => 'Esperando a bike mandar os números…',
                    _ => null,
                  },
                  extra:
                      live.status == BikeLive.aoVivo ||
                          live.status == BikeLive.parada
                      ? _NumerosAoVivo(
                          leitura: live.last,
                          vivo: live.status == BikeLive.aoVivo,
                        )
                      : null,
                ),
              ],
            ),
          ),
          if (live.status == BikeLive.aoVivo) ...[
            const SizedBox(height: 10),
            _Faixa(texto: _tudoCerto(live.last)),
          ],
          if (bike.diagnostic != null) ...[
            const SizedBox(height: 10),
            AppCard(
              child: SelectableText(
                bike.diagnostic!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  conectada != null
                      ? 'Outras bikes por perto'
                      : _showAll
                      ? 'Aparelhos por perto'
                      : 'Bikes encontradas',
                  style: AppText.secao,
                ),
              ),
              if (_scanning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                TextButton(
                  onPressed: _scan,
                  child: const Text('Procurar de novo'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final d in outras) ...[
            AppCard(
              onTap: _connectingId == null ? () => _connect(d) : null,
              child: Row(
                children: [
                  Icon(
                    d.likelyBike ? Icons.directions_bike : Icons.bluetooth,
                    color: AppColors.destaque,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: AppText.corpoForte),
                        Text(
                          d.id == ultima
                              ? 'A bike que você usou da última vez'
                              : d.likelyBike
                              ? 'Parece uma bike'
                              : 'Outro aparelho',
                          style: AppText.suave,
                        ),
                      ],
                    ),
                  ),
                  if (_connectingId == d.id)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textoSuave,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (outras.isEmpty && !_scanning && conectada != null)
            const Text('Nenhuma outra bike por perto.', style: AppText.suave),
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
      bottomNavigationBar: conectada == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Pronto, pedalar'),
                ),
              ),
            ),
    );
  }

  /// “Tudo certo: giro, potência e velocidade estão vindo da bike.” (só o que ela manda).
  static String _tudoCerto(BikeReading? r) {
    final campos = [
      if (r?.cadence != null) 'giro',
      if (r?.power != null) 'potência',
      if (r?.speedKmh != null) 'velocidade',
    ];
    if (campos.isEmpty) return 'Tudo certo: os dados estão vindo da bike.';
    final lista = campos.length == 1
        ? campos.single
        : '${campos.sublist(0, campos.length - 1).join(', ')} e ${campos.last}';
    final verbo = campos.length == 1 ? 'está vindo' : 'estão vindo';
    return 'Tudo certo: $lista $verbo da bike.';
  }
}

enum _Estado { feita, agora, esperando, problema }

/// Uma etapa da lista: o sinal (certo, girando, esperando ou problema), o título, o que fazer e,
/// se houver, uma ação e um conteúdo a mais.
class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.estado,
    required this.titulo,
    this.texto,
    this.acao,
    this.extra,
    this.divisoria = false,
  });

  final _Estado estado;
  final String titulo;
  final String? texto;
  final Widget? acao;
  final Widget? extra;
  final bool divisoria;

  @override
  Widget build(BuildContext context) {
    final sinal = switch (estado) {
      _Estado.feita => const _Sinal(
        cor: AppColors.destaque,
        icone: Icons.check,
      ),
      _Estado.problema => const _Sinal(
        cor: Color(0xFFD9822B),
        icone: Icons.priority_high,
      ),
      _Estado.agora => const SizedBox(
        width: 26,
        height: 26,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      _Estado.esperando => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borda, width: 2),
        ),
      ),
    };
    final apagado = estado == _Estado.esperando;
    return Container(
      decoration: divisoria
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEF1EF))),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sinal,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppText.corpoForte.copyWith(
                    color: apagado ? AppColors.textoSuave : AppColors.texto,
                  ),
                ),
                if (texto != null) ...[
                  const SizedBox(height: 2),
                  Text(texto!, style: AppText.suave),
                ],
                if (extra != null) ...[const SizedBox(height: 8), extra!],
              ],
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}

class _Sinal extends StatelessWidget {
  const _Sinal({required this.cor, required this.icone});

  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
    child: Icon(icone, color: Colors.white, size: 17),
  );
}

/// Giro, watts e velocidade que acabaram de chegar.
class _NumerosAoVivo extends StatelessWidget {
  const _NumerosAoVivo({required this.leitura, required this.vivo});

  final BikeReading? leitura;
  final bool vivo;

  @override
  Widget build(BuildContext context) {
    final r = leitura;
    final cor = vivo ? AppColors.destaque : AppColors.textoSuave;
    String n(num? v, [int casas = 0]) =>
        v == null ? '—' : formatNumber(v.toDouble(), casas);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final (valor, rotulo) in [
          (n(r?.cadence), 'rpm'),
          (n(r?.power), 'W'),
          (n(r?.speedKmh, 1), 'km/h'),
        ])
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: cor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $rotulo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textoSuave,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.destaqueSuave,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      texto,
      style: const TextStyle(
        color: AppColors.destaqueTexto,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
