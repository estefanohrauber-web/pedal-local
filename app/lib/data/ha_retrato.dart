import 'dart:convert';
import 'dart:math' as math;

import '../domain/route_profile.dart';
import '../domain/stats.dart';
import 'rides_store.dart';
import 'routes_store.dart';

/// O “retrato” que o app manda para o Home Assistant da casa: todos os pedais, para o painel da TV
/// mostrar uma cópia da aba Você. Cada envio substitui o anterior. O formato está combinado com o
/// painel (pedalaqui-ha.md, na pasta do Home Assistant do PC).

/// Ordem dos números de cada pedal.
const haColunas = [
  'inicio', 'distancia_m', 'tempo_s', 'potencia_w', 'velocidade_kmh', 'subida_m', //
  'kcal', 'completo', 'nome', 'modo', 'rota', 'voltas',
];

/// Com muitos anos de pedais, vão só os mais novos (o resumo continua contando todos).
const haMaxPedais = 1500;

/// Tamanho máximo do JSON (bytes).
const haLimiteBytes = 200 * 1000;

/// O retrato como mapa (vira JSON direto). [nome] e [pesoKg] são os de Ajustes › Você; sem nome,
/// o campo fica de fora (o Home Assistant põe o da pessoa).
Map<String, Object?> retratoHa({
  required String? nome,
  required double pesoKg,
  required List<RideRecord> pedais,
  required List<RouteRecord> rotas,
  int maxPedais = haMaxPedais,
}) {
  final ordem = [...pedais]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final porId = {for (final r in rotas) r.id: r};
  final total = summarize(ordem);
  final linhas = <List<Object?>>[];
  final usadas = <String, Map<String, Object?>>{};
  for (final p in ordem.take(maxPedais)) {
    final rota = p.routeId == null ? null : porId[p.routeId];
    var idRota = p.routeId;
    if (idRota != null && !usadas.containsKey(idRota)) {
      if (rota != null) {
        usadas[idRota] = {'nome': rota.name, 'cor': rota.colorIndex, 'forma': formaHa(rota.points)};
      } else if ((p.track?.length ?? 0) > 1) {
        // a rota foi apagada: como no app, fica “Rota”, na primeira cor, com o desenho do pedal
        usadas[idRota] = {'nome': rideName(p), 'cor': 0, 'forma': formaHa(p.track!)};
      } else {
        idRota = null;
      }
    }
    linhas.add([
      p.startedAt.millisecondsSinceEpoch ~/ 1000,
      _inteiro(p.distanceM),
      _inteiro(p.movingTimeS),
      _inteiro(p.avgPowerW),
      _umaCasa(p.avgSpeedKmh),
      _inteiro(p.gainM),
      _inteiro(p.kcal),
      p.completed ? 1 : 0,
      rideName(p, routeName: rota?.name),
      p.mode.name,
      idRota,
      p.loop ? p.laps : 0,
    ]);
  }
  final quem = nome?.trim() ?? '';
  return {
    'versao': 1,
    if (quem.isNotEmpty) 'nome': quem,
    'peso_kg': pesoKg == pesoKg.roundToDouble() ? pesoKg.round() : _umaCasa(pesoKg),
    'resumo': {
      'pedais': total.count,
      'distancia_m': _inteiro(total.distanceM),
      'tempo_s': _inteiro(total.movingTimeS),
      'subida_m': _inteiro(total.gainM),
    },
    'colunas': haColunas,
    'pedais': linhas,
    'rotas': usadas,
  };
}

/// O retrato em JSON, abaixo de [limiteBytes]: se passar, corta mais pedais antigos.
String corpoHa({
  required String? nome,
  required double pesoKg,
  required List<RideRecord> pedais,
  required List<RouteRecord> rotas,
  int limiteBytes = haLimiteBytes,
}) {
  var quantos = math.min(pedais.length, haMaxPedais);
  while (true) {
    final corpo = jsonEncode(retratoHa(nome: nome, pesoKg: pesoKg, pedais: pedais, rotas: rotas, maxPedais: quantos));
    final tamanho = utf8.encode(corpo).length;
    if (tamanho <= limiteBytes || quantos == 0) return corpo;
    // tira na proporção do excesso (e pelo menos um pedal), com uma folga
    quantos = math.min(quantos - 1, (quantos * limiteBytes / tamanho * 0.95).floor());
    quantos = math.max(quantos, 0);
  }
}

/// O desenho de um caminho em até [maxPontos] pontos `[x, y]` inteiros de 0 a 100: a mesma escala
/// nos dois eixos (como no desenho do app), centralizado, com o y crescendo para o norte.
/// Vazio quando não há o que desenhar.
List<List<int>> formaHa(List<ProfilePoint> caminho, {int maxPontos = 24}) {
  final projecao = ProjecaoHa.de(caminho);
  if (projecao == null) return const [];
  final px = <double>[], py = <double>[];
  for (final p in caminho) {
    final (x, y) = projecao.xy(p.lat, p.lon);
    px.add(x);
    py.add(y);
  }
  // até sobrar só desvio menor que meia unidade (some no arredondamento)
  final forma = <List<int>>[];
  for (final i in simplificarHa(px, py, maxPontos: maxPontos, tolerancia: 0.5)) {
    final ponto = [px[i].round(), py[i].round()];
    if (forma.isEmpty || forma.last[0] != ponto[0] || forma.last[1] != ponto[1]) forma.add(ponto);
  }
  return forma.length < 2 ? const [] : forma;
}

/// Leva latitude e longitude para o quadrado de 0 a 100 de um caminho: a mesma escala nos dois
/// eixos (como no desenho do app), centralizado, com o y crescendo para o norte.
class ProjecaoHa {
  ProjecaoHa._(this._escala, this._minX, this._minY, this._k, this._dx, this._dy);

  /// A projeção que enquadra [caminho]; null quando não há o que desenhar.
  static ProjecaoHa? de(List<ProfilePoint> caminho) {
    if (caminho.length < 2) return null;
    final escala = math.cos(caminho.first.lat * math.pi / 180);
    final xs = [for (final p in caminho) p.lon * escala];
    final ys = [for (final p in caminho) p.lat];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final lado = math.max(maxX - minX, maxY - minY);
    if (lado < 1e-9) return null;
    final k = 100 / lado;
    return ProjecaoHa._(escala, minX, minY, k, (100 - (maxX - minX) * k) / 2, (100 - (maxY - minY) * k) / 2);
  }

  final double _escala, _minX, _minY, _k, _dx, _dy;

  (double, double) xy(double lat, double lon) => (_dx + (lon * _escala - _minX) * _k, _dy + (lat - _minY) * _k);
}

/// Simplifica um desenho: começa pelas pontas e vai pondo o ponto que mais foge do desenho atual,
/// até [maxPontos] ou até nenhum fugir mais que [tolerancia]. Devolve os índices, em ordem.
List<int> simplificarHa(List<double> px, List<double> py, {required int maxPontos, required double tolerancia}) {
  if (px.length < 2) return [for (var i = 0; i < px.length; i++) i];
  final escolhidos = <int>[0, px.length - 1];
  while (escolhidos.length < maxPontos) {
    var pior = -1;
    var desvio = tolerancia;
    for (var s = 0; s + 1 < escolhidos.length; s++) {
      final a = escolhidos[s], b = escolhidos[s + 1];
      for (var i = a + 1; i < b; i++) {
        final d = _distanciaAoTrecho(px[i], py[i], px[a], py[a], px[b], py[b]);
        if (d > desvio) {
          desvio = d;
          pior = i;
        }
      }
    }
    if (pior < 0) break;
    escolhidos
      ..add(pior)
      ..sort();
  }
  return escolhidos;
}

double _distanciaAoTrecho(double x, double y, double ax, double ay, double bx, double by) {
  final vx = bx - ax, vy = by - ay;
  final comprimento2 = vx * vx + vy * vy;
  final t = comprimento2 == 0 ? 0.0 : (((x - ax) * vx + (y - ay) * vy) / comprimento2).clamp(0.0, 1.0);
  final ex = ax + t * vx - x, ey = ay + t * vy - y;
  return math.sqrt(ex * ex + ey * ey);
}

int _inteiro(double v) => v.isFinite ? v.round() : 0;

double _umaCasa(double v) => v.isFinite ? (v * 10).round() / 10 : 0;
