import 'dart:math' as math;

import '../domain/geo.dart';
import '../domain/loop_geometry.dart';
import 'route_builder.dart';
import 'services/routing_service.dart';

/// Tentativas de raio por direção (cada uma é um pedido ao serviço de rotas).
const loopAttempts = 3;

/// Quantas voltas mostrar.
const loopChoices = 3;

/// Duas voltas que passam mais que isso uma por cima da outra contam como a mesma.
const _mesmaVolta = 0.8;

/// Voltas mais longe que isso do tamanho pedido só aparecem se não houver outra.
const _longeDoPedido = 0.3;

class _Achado {
  _Achado(this.waypoints, this.line, this.length);

  final List<GeoPoint> waypoints;
  final List<GeoPoint> line;
  final double length;
  late final amostra = resample(line, 50);
}

/// Gera voltas fechadas de um tamanho escolhido saindo de um ponto: um círculo em cada
/// direção, pelas ruas, ajustando o tamanho do círculo até a volta chegar perto do pedido.
class LoopGenerator {
  LoopGenerator(this._builder);

  final RouteBuilder _builder;

  /// Até [loopChoices] voltas de cerca de [targetM] metros, da melhor para a pior.
  /// Com [moreClimb], tenta 6 direções e põe primeiro as com mais subida por km.
  /// [onProgress] vai de 0 a 1.
  Future<List<BuiltRoute>> generate(
    GeoPoint start, {
    required double targetM,
    bool moreClimb = false,
    void Function(double progress)? onProgress,
  }) async {
    final rumos = loopBearings(moreClimb ? 6 : 3);
    final achados = <_Achado>[];
    for (var i = 0; i < rumos.length; i++) {
      final achado = await _naDirecao(start, rumos[i], targetM);
      if (achado != null) achados.add(achado);
      onProgress?.call(0.8 * (i + 1) / rumos.length);
    }
    if (achados.isEmpty) {
      throw const RouteException('sem-caminho', 'Não achei uma volta saindo daqui. Tente outro ponto ou outra distância.');
    }

    // Mais perto do tamanho pedido primeiro, sem repetir a mesma volta.
    achados.sort((a, b) => (a.length - targetM).abs().compareTo((b.length - targetM).abs()));
    final perto = achados.where((a) => (a.length - targetM).abs() <= _longeDoPedido * targetM).toList();
    final diferentes = <_Achado>[];
    for (final a in perto.isEmpty ? achados : perto) {
      if (diferentes.every((b) => overlapFraction(a.amostra, b.amostra) < _mesmaVolta)) diferentes.add(a);
    }
    final medir = moreClimb ? diferentes : diferentes.take(loopChoices).toList();

    final voltas = <BuiltRoute>[];
    for (var i = 0; i < medir.length; i++) {
      voltas.add(await _builder.fromLine(medir[i].waypoints, medir[i].line));
      onProgress?.call(0.8 + 0.2 * (i + 1) / medir.length);
    }
    if (moreClimb) {
      double porKm(BuiltRoute b) => b.route.gainM / math.max(1, b.route.distanceM / 1000);
      voltas.sort((a, b) => porKm(b).compareTo(porKm(a)));
    }
    return voltas.take(loopChoices).toList();
  }

  /// Os pontos do círculo caem no meio do quarteirão ou no mato; o caminho passa pela rua
  /// mais perto de cada um. Leva cada ponto para o caminho, para ficar fácil de arrastar
  /// no editor. A volta começa e termina no começo do caminho.
  static List<GeoPoint> _naRua(List<GeoPoint> pontos, List<GeoPoint> linha) {
    GeoPoint maisPerto(GeoPoint p) => linha.reduce((a, b) => haversine(p, b) < haversine(p, a) ? b : a);
    return [linha.first, for (final p in pontos.sublist(1, pontos.length - 1)) maisPerto(p), linha.first];
  }

  /// A volta mais perto de [targetM] numa direção, ou null se não houver caminho por lá.
  Future<_Achado?> _naDirecao(GeoPoint start, double rumo, double targetM) async {
    final busca = LoopRadiusSearch(targetM);
    _Achado? melhor;
    for (var t = 0; t < loopAttempts; t++) {
      final pontos = loopWaypoints(start, bearingRad: rumo, radiusM: busca.radius);
      List<GeoPoint> linha;
      try {
        linha = await _builder.routing.route(pontos);
      } on RouteException catch (e) {
        if (e.code == 'sem-conexao') rethrow;
        break;
      }
      if (linha.length < 2) break;
      final comprimento = cumulativeDistances(linha).last;
      if (melhor == null || (comprimento - targetM).abs() < (melhor.length - targetM).abs()) {
        melhor = _Achado(_naRua(pontos, linha), linha, comprimento);
      }
      if (loopCloseEnough(comprimento, targetM)) break;
      busca.record(comprimento);
    }
    return melhor;
  }
}
