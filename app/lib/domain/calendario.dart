import 'dart:math' as math;

import 'stats.dart';

/// O histórico em calendário: km de cada dia, o tom de verde, a sequência de dias e os nomes.

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const _diasDaSemana = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];

/// Iniciais dos dias, começando na segunda (como a semana da meta).
const iniciaisDaSemana = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

/// Km pedalados em cada dia do mês (dia → km).
Map<int, double> kmPorDia(
  List<RideStat> pedais, {
  required int ano,
  required int mes,
}) {
  final km = <int, double>{};
  for (final p in pedais) {
    final d = p.startedAt;
    if (d.year != ano || d.month != mes) continue;
    km[d.day] = (km[d.day] ?? 0) + p.distanceM / 1000;
  }
  return km;
}

/// 0 = sem pedal; 1, 2 e 3 = cada vez mais perto do dia que mais pedalou no mês.
int tomDoDia(double km, double maiorKm) {
  if (km <= 0 || maiorKm <= 0) return 0;
  final t = km / maiorKm;
  return t < 1 / 3
      ? 1
      : t < 2 / 3
      ? 2
      : 3;
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dias seguidos com pedal até hoje; se ainda não pedalou hoje, conta até ontem.
int diasSeguidos(List<RideStat> pedais, DateTime hoje) {
  final dias = {for (final p in pedais) _dia(p.startedAt)};
  var d = _dia(hoje);
  if (!dias.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (dias.contains(d)) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// Os dias do mês numa grade de semanas (segunda a domingo); null = casa vazia.
List<DateTime?> gradeDoMes(int ano, int mes) {
  final primeiro = DateTime(ano, mes);
  final dias = DateTime(ano, mes + 1, 0).day;
  final antes = primeiro.weekday - 1;
  final total = ((antes + dias) / 7).ceil() * 7;
  return [
    for (var i = 0; i < total; i++)
      i < antes || i >= antes + dias ? null : DateTime(ano, mes, i - antes + 1),
  ];
}

/// “Outubro 2026”.
String nomeDoMes(int ano, int mes) {
  final nome = _meses[mes - 1];
  return '${nome[0].toUpperCase()}${nome.substring(1)} $ano';
}

/// “Sábado, 10 de outubro”.
String nomeDoDia(DateTime d) =>
    '${_diasDaSemana[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

/// O maior km de um dia no mês (0 = nenhum pedal).
double maiorKm(Map<int, double> km) => km.values.fold(0.0, math.max);
