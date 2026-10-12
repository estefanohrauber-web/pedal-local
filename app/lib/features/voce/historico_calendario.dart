import 'package:flutter/material.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/rides_store.dart';
import '../../domain/calendario.dart';
import 'ride_tile.dart';

/// Tons de verde dos dias pedalados (1 = pouco, 3 = o dia que mais pedalou no mês).
const _tons = [Color(0xFFB9E3CB), Color(0xFF7CCB9E), AppColors.destaque];
const _textoDosTons = [
  AppColors.destaqueTexto,
  Color(0xFF0B3D25),
  Colors.white,
];

/// O histórico como calendário do mês: os dias pedalados pintados de verde (mais escuro quando
/// pedalou mais) e os números do mês; embaixo, todos os pedais, ou só os do [dia] escolhido.
class HistoricoCalendario extends StatefulWidget {
  const HistoricoCalendario({super.key, required this.pedais, required this.dia, required this.onDia, this.hoje});

  /// Todos os pedais, do mais novo ao mais velho.
  final List<RideRecord> pedais;

  /// O dia que filtra a lista (null = todos).
  final DateTime? dia;

  /// Tocar num dia pedalado escolhe (ou solta, se já era ele); trocar de mês solta.
  final ValueChanged<DateTime?> onDia;

  /// Hoje (nos testes, um dia fixo).
  final DateTime? hoje;

  @override
  State<HistoricoCalendario> createState() => _HistoricoCalendarioState();
}

class _HistoricoCalendarioState extends State<HistoricoCalendario> {
  late DateTime _mes;

  DateTime get _hoje => widget.hoje ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _mes = DateTime(_hoje.year, _hoje.month);
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    widget.onDia(null);
  }

  @override
  Widget build(BuildContext context) {
    final km = kmPorDia(widget.pedais, ano: _mes.year, mes: _mes.month);
    final maior = maiorKm(km);
    final noMes = widget.pedais
        .where(
          (p) =>
              p.startedAt.year == _mes.year && p.startedAt.month == _mes.month,
        )
        .length;
    final seguidos = diasSeguidos(widget.pedais, _hoje);
    final dia = widget.dia;
    final mesAtual = _mes.year == _hoje.year && _mes.month == _hoje.month;
    final hoje = DateTime(_hoje.year, _hoje.month, _hoje.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    onPressed: () => _mudarMes(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      nomeDoMes(_mes.year, _mes.month),
                      textAlign: TextAlign.center,
                      style: AppText.secao,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: mesAtual ? null : () => _mudarMes(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final inicial in iniciaisDaSemana)
                    Expanded(
                      child: Text(
                        inicial,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _Grade(
                dias: gradeDoMes(_mes.year, _mes.month),
                km: km,
                maior: maior,
                escolhido: dia,
                hoje: hoje,
                onDia: (d) => widget.onDia(d == dia ? null : d),
              ),
              const Divider(height: 22, color: Color(0xFFEEF1EF)),
              Row(
                children: [
                  _Numero(
                    valor: '$noMes',
                    rotulo: noMes == 1 ? 'pedal' : 'pedais',
                  ),
                  _Numero(
                    valor: formatNumber(
                      km.values.fold(0.0, (a, b) => a + b),
                      1,
                    ),
                    rotulo: 'km',
                  ),
                  _Numero(
                    valor: '$seguidos',
                    rotulo: seguidos == 1 ? 'dia seguido' : 'dias seguidos',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Quanto mais escuro o dia, mais você pedalou.',
          style: AppText.suave,
        ),
        const SizedBox(height: 16),
        if (dia == null)
          const Text('Todos os pedais', style: AppText.secao)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: _Filtro(dia: dia, onTirar: () => widget.onDia(null)),
          ),
        _ListaDePedais(
          comDias: dia == null, // filtrada, o selo já diz o dia
          pedais: [
            for (final p in widget.pedais)
              if (dia == null || _mesmoDia(p.startedAt, dia)) p,
          ],
        ),
      ],
    );
  }
}

class _Grade extends StatelessWidget {
  const _Grade({
    required this.dias,
    required this.km,
    required this.maior,
    required this.escolhido,
    required this.hoje,
    required this.onDia,
  });

  final List<DateTime?> dias;
  final Map<int, double> km;
  final double maior;
  final DateTime? escolhido;
  final DateTime hoje;
  final ValueChanged<DateTime> onDia;

  @override
  Widget build(BuildContext context) {
    final semanas = [
      for (var i = 0; i < dias.length; i += 7) dias.sublist(i, i + 7),
    ];
    return Column(
      children: [
        for (final semana in semanas)
          Row(
            children: [
              for (final d in semana)
                Expanded(
                  child: d == null
                      ? const SizedBox(height: 44)
                      : _Dia(
                          dia: d,
                          tom: tomDoDia(km[d.day] ?? 0, maior),
                          escolhido: d == escolhido,
                          futuro: d.isAfter(hoje),
                          onTap: km.containsKey(d.day) ? () => onDia(d) : null,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.dia,
    required this.tom,
    required this.escolhido,
    required this.futuro,
    required this.onTap,
  });

  final DateTime dia;
  final int tom;
  final bool escolhido;
  final bool futuro;

  /// Só nos dias pedalados (os outros não têm o que mostrar).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = tom == 0 ? null : _tons[tom - 1];
    final texto = tom == 0
        ? (futuro ? const Color(0xFFB8C4BD) : AppColors.texto)
        : _textoDosTons[tom - 1];
    return Semantics(
      button: onTap != null,
      selected: escolhido,
      label: '${nomeDoDia(dia)}${tom == 0 ? '' : ', com pedal'}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
                border: escolhido
                    ? Border.all(color: AppColors.escuro, width: 2)
                    : null,
              ),
              child: Text(
                '${dia.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: tom == 0 ? FontWeight.w600 : FontWeight.w800,
                  color: texto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
    child: MetricTile(value: valor, label: rotulo),
  );
}

bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// O selo escuro do filtro: o dia escolhido e o X que volta a mostrar todos.
class _Filtro extends StatelessWidget {
  const _Filtro({required this.dia, required this.onTirar});

  final DateTime dia;
  final VoidCallback onTirar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Só ${nomeDoDia(dia)}. Tocar mostra todos os pedais.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.escuro,
        shape: const StadiumBorder(),
        child: InkWell(
          key: const Key('tirar-filtro'),
          customBorder: const StadiumBorder(),
          onTap: onTirar,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    nomeDoDia(dia),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.close, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Os pedais agrupados por dia, do mais novo ao mais velho.
class _ListaDePedais extends StatelessWidget {
  const _ListaDePedais({required this.pedais, required this.comDias});

  final List<RideRecord> pedais;
  final bool comDias;

  @override
  Widget build(BuildContext context) {
    final filhos = <Widget>[];
    DateTime? diaAtual;
    for (final p in pedais) {
      final d = DateTime(p.startedAt.year, p.startedAt.month, p.startedAt.day);
      if (d != diaAtual && comDias) {
        diaAtual = d;
        filhos.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              nomeDoDia(d),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textoSuave),
            ),
          ),
        );
      } else {
        filhos.add(SizedBox(height: filhos.isEmpty ? 12 : 10));
      }
      filhos.add(RideTile(ride: p));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos);
  }
}
