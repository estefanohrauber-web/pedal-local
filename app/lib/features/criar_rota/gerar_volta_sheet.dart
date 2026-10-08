import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../data/route_builder.dart';
import '../../data/services/routing_service.dart';
import '../../domain/geo.dart';
import '../pedal/ride_widgets.dart';
import '../voce/ride_tile.dart';

/// Distâncias oferecidas, em km.
const loopTargetsKm = [3, 5, 10, 20];

/// Escolher a distância, gerar as voltas e tocar numa para usar no editor.
/// Fecha devolvendo a volta escolhida.
class GerarVoltaSheet extends ConsumerStatefulWidget {
  const GerarVoltaSheet({super.key, required this.saida, required this.doPrimeiroPonto, required this.trocaPontos});

  final GeoPoint saida;

  /// A partida é o primeiro ponto marcado (senão, o centro do mapa).
  final bool doPrimeiroPonto;

  /// Já há uma rota marcada, que a volta escolhida vai substituir.
  final bool trocaPontos;

  @override
  ConsumerState<GerarVoltaSheet> createState() => _GerarVoltaSheetState();
}

class _GerarVoltaSheetState extends ConsumerState<GerarVoltaSheet> {
  int _km = 5;
  bool _maisSubida = false;
  bool _gerando = false;
  double _progresso = 0;
  String? _erro;
  List<BuiltRoute>? _voltas;

  void _muda(void Function() alteracao) => setState(() {
        alteracao();
        _voltas = null;
        _erro = null;
      });

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _progresso = 0;
      _erro = null;
      _voltas = null;
    });
    try {
      final voltas = await ref.read(loopGeneratorProvider).generate(
            widget.saida,
            targetM: _km * 1000.0,
            moreClimb: _maisSubida,
            onProgress: (p) {
              if (mounted) setState(() => _progresso = p);
            },
          );
      if (mounted) setState(() => _voltas = voltas);
    } on RouteException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não deu para gerar a volta: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voltas = _voltas;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gerar volta', style: AppText.secao),
            const SizedBox(height: 4),
            Text(
              widget.doPrimeiroPonto
                  ? 'Saindo do primeiro ponto que você marcou.'
                  : 'Saindo do centro do mapa. Para sair de outro lugar, feche e marque o ponto de partida.',
              style: AppText.suave,
            ),
            const SizedBox(height: 14),
            const Text('Distância', style: AppText.corpoForte),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final km in loopTargetsKm)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text('$km km'),
                    selected: _km == km,
                    onSelected: _gerando ? null : (_) => _muda(() => _km = km),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mais subida', style: AppText.corpoForte),
              subtitle: const Text('Procura caminhos com mais ladeira. Demora um pouco mais.', style: AppText.suave),
              value: _maisSubida,
              onChanged: _gerando ? null : (v) => _muda(() => _maisSubida = v),
            ),
            if (widget.trocaPontos)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('A volta escolhida troca os pontos marcados agora (dá para desfazer).', style: AppText.suave),
              ),
            if (_gerando) ...[
              const SizedBox(height: 6),
              const Text('Procurando caminhos pelas ruas…', style: AppText.corpoForte),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _progresso),
              const SizedBox(height: 4),
              Text(
                _maisSubida ? 'Testando 6 direções. Pode levar uns 30 segundos.' : 'Testando 3 direções. Pode levar uns 15 segundos.',
                style: AppText.suave,
              ),
              const SizedBox(height: 10),
            ],
            if (_erro != null) AvisoFaixa(texto: _erro!),
            if (voltas != null) ...[
              const SizedBox(height: 6),
              const Text('Toque numa volta para usar', style: AppText.corpoForte),
              const SizedBox(height: 8),
              for (var i = 0; i < voltas.length; i++) ...[
                _CartaoVolta(
                  key: Key('volta-$i'),
                  volta: voltas[i],
                  cor: routeColor(i + 1),
                  onTap: () => Navigator.of(context).pop(voltas[i]),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _gerando ? null : _gerar,
              icon: const Icon(Icons.auto_awesome),
              label: Text(voltas == null ? 'Gerar voltas' : 'Gerar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoVolta extends StatelessWidget {
  const _CartaoVolta({super.key, required this.volta, required this.cor, required this.onTap});

  final BuiltRoute volta;
  final Color cor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = volta.route;
    return Material(
      color: AppColors.neutro,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 56, height: 56, child: CustomPaint(painter: TrackShapePainter(r.points, cor))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatKm(r.distanceM), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(
                      volta.flat ? 'Sem relevo agora (rota plana)' : '↑ ${formatNumber(r.gainM)} m de subida',
                      style: AppText.suave,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
