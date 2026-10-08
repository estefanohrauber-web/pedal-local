import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// Mostra ao vivo o que a bike manda pelo Bluetooth, para saber se ela informa
/// potência e o nível do botão de carga.
class DadosBikeScreen extends ConsumerStatefulWidget {
  const DadosBikeScreen({super.key});

  @override
  ConsumerState<DadosBikeScreen> createState() => _DadosBikeScreenState();
}

/// Menor e maior valor vistos de um campo.
class _Faixa {
  _Faixa(double v)
      : min = v,
        max = v,
        last = v;

  double min;
  double max;
  double last;

  void add(double v) {
    last = v;
    if (v < min) min = v;
    if (v > max) max = v;
  }
}

class _DadosBikeScreenState extends ConsumerState<DadosBikeScreen> {
  StreamSubscription<BikeReading>? _sub;
  BikeSource? _fonte;
  int _pacotes = 0;
  final _campos = <String, _Faixa>{};

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _ouvir(BikeSource? fonte) {
    if (identical(fonte, _fonte)) return;
    _sub?.cancel();
    _fonte = fonte;
    _pacotes = 0;
    _campos.clear();
    _sub = fonte?.readings.listen((r) {
      if (!mounted) return;
      setState(() {
        _pacotes++;
        void anota(String k, num? v) {
          if (v == null) return;
          final faixa = _campos[k];
          if (faixa == null) {
            _campos[k] = _Faixa(v.toDouble());
          } else {
            faixa.add(v.toDouble());
          }
        }

        anota('cadencia', r.cadence);
        anota('potencia', r.power);
        anota('nivel', r.resistance);
        anota('velocidade', r.speedKmh);
        anota('fc', r.heartRate);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(bikeControllerProvider);
    final fonte = bike.connected ? bike.source : null;
    _ouvir(fonte);
    return Scaffold(
      appBar: AppBar(title: const Text('Dados da bike')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: fonte == null
            ? [
                const Text('Conecte a bike para ver o que ela envia.', style: AppText.corpoForte),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => context.push('/bike'), child: const Text('Conectar bike')),
              ]
            : [
                Text(fonte.name, style: AppText.secao),
                Text('$_pacotes leituras recebidas', style: AppText.suave),
                const SizedBox(height: 12),
                const AppCard(
                  child: Text(
                    'Pedale e gire o botão de carga devagar, do mais leve ao mais pesado. '
                    'Se “Potência” ou “Nível do botão” mudarem junto, a bike manda esse dado. '
                    'Se aparecer “não manda”, o app precisa estimar.',
                    style: AppText.suave,
                  ),
                ),
                const SizedBox(height: 12),
                _Linha(rotulo: 'Cadência', faixa: _campos['cadencia'], unidade: 'rpm'),
                _Linha(rotulo: 'Potência', faixa: _campos['potencia'], unidade: 'W'),
                _Linha(rotulo: 'Nível do botão', faixa: _campos['nivel'], unidade: ''),
                _Linha(rotulo: 'Velocidade', faixa: _campos['velocidade'], unidade: 'km/h', casas: 1),
                _Linha(rotulo: 'Frequência cardíaca', faixa: _campos['fc'], unidade: 'bpm'),
              ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.faixa, required this.unidade, this.casas = 0});

  final String rotulo;
  final _Faixa? faixa;
  final String unidade;
  final int casas;

  String _v(double v) => '${formatNumber(v, casas)}${unidade.isEmpty ? '' : ' $unidade'}';

  @override
  Widget build(BuildContext context) {
    final f = faixa;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              f == null ? Icons.remove_circle_outline : Icons.check_circle,
              color: f == null ? AppColors.textoSuave : AppColors.destaque,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(rotulo, style: AppText.corpoForte)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(f == null ? 'não manda' : _v(f.last), style: AppText.corpoForte),
                if (f != null && f.max > f.min)
                  Text('de ${_v(f.min)} a ${_v(f.max)}', style: AppText.suave),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
