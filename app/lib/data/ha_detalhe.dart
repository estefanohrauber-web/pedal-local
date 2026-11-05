import 'dart:convert';
import 'dart:math' as math;

import '../core/theme/app_theme.dart';
import '../domain/laps.dart';
import '../domain/ride_analysis.dart';
import '../domain/route_profile.dart';
import 'cabecalho_pedal.dart';
import 'ha_retrato.dart';
import 'rides_store.dart';

/// O detalhe de um pedal para o painel da casa: o que a tela do pedal mostra (título, números,
/// voltas, o caminho e as amostras para pintar o mapa e o gráfico). Um envio por pedal; o
/// [RideRecord.startedAt] em segundos (“inicio”) é a chave, igual à do retrato. O formato está
/// combinado com o painel (pedalaqui-ha.md, na pasta do Home Assistant do PC).

/// Ordem dos números de cada amostra. Sem o dado, vai null (pedal livre e treino não têm
/// caminho: sem inc, alt, x e y; fc só com cinta cardíaca).
const haDetalheColunas = ['t', 'd', 'v', 'pot', 'cad', 'inc', 'alt', 'fc', 'x', 'y'];

/// No máximo tantas amostras (o app grava uma por segundo andando; acima disso, junta em médias).
const haDetalheMaxLinhas = 600;

/// No máximo tantos pontos no desenho do caminho.
const haDetalheMaxForma = 200;

/// Tamanho máximo do JSON (bytes): o Home Assistant guarda cada pedal num arquivo.
const haDetalheLimiteBytes = 60 * 1000;

/// A escala de cores tem tantas faixas (como no mapa do app).
const haDetalheFaixas = 24;

/// Versão do formato (mudou = manda tudo de novo).
const haDetalheVersao = 1;

/// O que pinta o mapa e o gráfico, na ordem dos botões da tela, com a coluna das amostras.
const _metricas = {
  RideMetric.velocidade: ('v', 1),
  RideMetric.potencia: ('pot', 0),
  RideMetric.cadencia: ('cad', 0),
  RideMetric.inclinacao: ('inc', 1),
  RideMetric.fc: ('fc', 0),
};

/// As cores da escala, da menor (azul) para a maior (vermelho), em “#RRGGBB”.
List<String> get haDetalheEscala => [
  for (final c in heatStops) '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
];

/// O detalhe como mapa (vira JSON direto). [nomeRota] é o nome atual da rota do pedal.
Map<String, Object?> detalheHa(
  RideRecord ride, {
  String? nomeRota,
  int maxLinhas = haDetalheMaxLinhas,
  int maxForma = haDetalheMaxForma,
}) {
  final amostras = ride.samples;
  final track = ride.track;
  final perfil = track == null || track.length < 2 ? null : RouteProfile(track);
  final projecao = perfil == null ? null : ProjecaoHa.de(track!);
  final comprimento = perfil?.distance ?? 0;
  // Na volta fechada, cada volta passa pelo mesmo caminho (mesma conta da tela).
  double naVolta(double d) =>
      ride.loop && comprimento > 0 ? d - (d / comprimento).floor() * comprimento : d;

  final disponiveis = availableMetrics(amostras, hasTerrain: perfil != null);
  final series = {
    for (final m in disponiveis)
      m: metricSeries(amostras, m, gradeAt: perfil == null ? null : (d) => perfil.gradeAt(naVolta(d))),
  };

  // Junta as amostras em até [maxLinhas] grupos seguidos: média dos valores, tempo e distância do
  // fim de cada grupo.
  final n = amostras.length;
  final grupos = n <= maxLinhas ? n : math.max(1, maxLinhas);
  final linhas = <List<Object?>>[];
  for (var g = 0; g < grupos; g++) {
    final ini = g * n ~/ grupos;
    final fim = math.max(ini + 1, (g + 1) * n ~/ grupos);
    double media(RideMetric m) {
      final s = series[m]!;
      var soma = 0.0;
      for (var i = ini; i < fim; i++) {
        soma += s[i];
      }
      return soma / (fim - ini);
    }

    double? se(RideMetric m) => series.containsKey(m) ? media(m) : null;
    final ultima = amostras[fim - 1];
    final d = naVolta(ultima.distance);
    final ponto = perfil?.positionAt(d);
    final xy = ponto == null || projecao == null ? null : projecao.xy(ponto.lat, ponto.lon);
    final inc = se(RideMetric.inclinacao);
    final fc = se(RideMetric.fc);
    linhas.add([
      _inteiro(ultima.t),
      _inteiro(ultima.distance),
      _umaCasa(media(RideMetric.velocidade)),
      _inteiro(media(RideMetric.potencia)),
      _inteiro(media(RideMetric.cadencia)),
      inc == null ? null : _umaCasa(inc),
      perfil == null ? null : _inteiro(perfil.elevationAt(d)),
      fc == null ? null : _inteiro(fc),
      xy == null ? null : _umaCasa(xy.$1),
      xy == null ? null : _umaCasa(xy.$2),
    ]);
  }

  final fatias = lapSlices(amostras, perfil != null && ride.loop ? comprimento : double.infinity);
  final tempos = lapTimes(amostras, perfil != null && ride.loop ? comprimento : double.infinity);
  final cabecalho = cabecalhoPedal(ride, perfil);
  return {
    'versao': haDetalheVersao,
    'inicio': ride.startedAt.millisecondsSinceEpoch ~/ 1000,
    'modo': ride.mode.name,
    'rota': ride.routeId,
    'nome': rideName(ride, routeName: nomeRota),
    'titulo': cabecalho.titulo,
    'detalhes': cabecalho.detalhes,
    'concluiu': cabecalho.concluiu,
    'numeros': _numeros(ride),
    'metricas': [
      for (final m in disponiveis)
        () {
          final (col, casas) = _metricas[m]!;
          final (lo, hi) = colorRange(series[m]!);
          return {'col': col, 'nome': m.label, 'unidade': m.unit, 'casas': casas, 'min': _umaCasa(lo), 'max': _umaCasa(hi)};
        }(),
    ],
    'escala': haDetalheEscala,
    'faixas': haDetalheFaixas,
    'voltas': [
      if (fatias.length > 1)
        for (final f in fatias)
          {
            'inicio_m': _inteiro(f.start),
            'metros': _inteiro(f.length),
            'tempo_s': f.index < tempos.length ? _inteiro(tempos[f.index]) : null,
            'completa': f.complete,
          },
    ],
    'forma': projecao == null ? const <List<double>>[] : _forma(track!, projecao, maxForma),
    'colunas': haDetalheColunas,
    'amostras': linhas,
  };
}

/// O detalhe em JSON, abaixo de [limiteBytes]: se passar, junta mais as amostras.
String corpoDetalheHa(RideRecord ride, {String? nomeRota, int limiteBytes = haDetalheLimiteBytes}) {
  var linhas = haDetalheMaxLinhas;
  var forma = haDetalheMaxForma;
  while (true) {
    final corpo = jsonEncode(detalheHa(ride, nomeRota: nomeRota, maxLinhas: linhas, maxForma: forma));
    final tamanho = utf8.encode(corpo).length;
    if (tamanho <= limiteBytes || (linhas <= 2 && forma <= 2)) return corpo;
    // tira na proporção do excesso, com uma folga
    final fator = limiteBytes / tamanho * 0.95;
    linhas = math.max(2, math.min(linhas - 1, (linhas * fator).floor()));
    forma = math.max(2, math.min(forma - 1, (forma * fator).floor()));
  }
}

/// Os números do cartão da tela do pedal.
Map<String, Object?> _numeros(RideRecord ride) {
  final amostras = ride.samples;
  final velMax = amostras.isEmpty ? 0.0 : amostras.map((s) => s.speedKmh).reduce(math.max);
  final potMax = amostras.isEmpty ? 0.0 : amostras.map((s) => s.power).reduce(math.max);
  final girando = [for (final s in amostras) if (s.cadence > 0) s.cadence];
  final cadMedia = girando.isEmpty ? 0.0 : girando.reduce((a, b) => a + b) / girando.length;
  return {
    'distancia_m': _inteiro(ride.distanceM),
    'tempo_s': _inteiro(ride.movingTimeS),
    'velocidade_kmh': _umaCasa(ride.avgSpeedKmh),
    'potencia_w': _inteiro(ride.avgPowerW),
    'subida_m': _inteiro(ride.gainM),
    'kcal': _inteiro(ride.kcal),
    'velocidade_max_kmh': _umaCasa(velMax),
    'potencia_max_w': _inteiro(potMax),
    'cadencia_media_rpm': _inteiro(cadMedia),
  };
}

/// O caminho de uma volta na mesma escala das amostras, com uma casa decimal.
List<List<double>> _forma(List<ProfilePoint> caminho, ProjecaoHa projecao, int maxPontos) {
  final px = <double>[], py = <double>[];
  for (final p in caminho) {
    final (x, y) = projecao.xy(p.lat, p.lon);
    px.add(x);
    py.add(y);
  }
  final forma = <List<double>>[];
  for (final i in simplificarHa(px, py, maxPontos: maxPontos, tolerancia: 0.05)) {
    final ponto = [_umaCasa(px[i]), _umaCasa(py[i])];
    if (forma.isEmpty || forma.last[0] != ponto[0] || forma.last[1] != ponto[1]) forma.add(ponto);
  }
  return forma;
}

int _inteiro(double v) => v.isFinite ? v.round() : 0;

double _umaCasa(double v) => v.isFinite ? (v * 10).round() / 10 : 0;
