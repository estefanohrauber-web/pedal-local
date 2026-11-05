import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/cabecalho_pedal.dart';
import 'package:pedal_local/data/ha_detalhe.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/domain/ride_analysis.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

/// [n] amostras, uma por segundo, a [mps] metros por segundo; a potência sobe e desce.
List<RideSample> amostras(int n, {double mps = 5, double? fc}) => [
  for (var i = 0; i < n; i++)
    RideSample(
      t: i + 1.0,
      distance: (i + 1) * mps,
      speedKmh: mps * 3.6 + (i % 7) * 0.3,
      power: 100 + (i % 40) * 3.0,
      cadence: i % 10 == 9 ? 0 : 80,
      heartRate: fc == null ? null : fc + i % 5,
    ),
];

/// Duas voltas e 300 m na volta quadrada de 1600 m (lados de 400 m), a 5 m/s.
RideRecord voltaDoBairro({int n = 700, double? fc}) => RideRecord(
  id: 'v',
  routeId: 'r1',
  mode: RideMode.rota,
  startedAt: DateTime.utc(2026, 11, 3, 22),
  movingTimeS: n.toDouble(),
  distanceM: n * 5.0,
  avgPowerW: 157,
  avgSpeedKmh: 18,
  gainM: 0,
  kcal: 110,
  completed: true,
  samples: amostras(n, fc: fc),
  laps: n * 5 ~/ 1600,
  loop: true,
  track: squareLoop(400),
);

RideRecord livre(int n) => RideRecord(
  id: 'l',
  mode: RideMode.livre,
  startedAt: DateTime.utc(2026, 11, 2, 7),
  movingTimeS: n.toDouble(),
  distanceM: n * 5.0,
  avgPowerW: 150,
  avgSpeedKmh: 18,
  gainM: 0,
  kcal: 90,
  completed: true,
  samples: amostras(n),
);

Map<String, Object?> linha(Map<String, Object?> detalhe, int i) {
  final colunas = (detalhe['colunas'] as List).cast<String>();
  final valores = (detalhe['amostras'] as List)[i] as List;
  return {for (var c = 0; c < colunas.length; c++) colunas[c]: valores[c]};
}

void main() {
  group('formato', () {
    test('as chaves, na ordem combinada, e as colunas das amostras', () {
      final d = detalheHa(voltaDoBairro(), nomeRota: 'Volta do bairro');
      expect(d.keys, [
        'versao', 'inicio', 'modo', 'rota', 'nome', 'titulo', 'detalhes', 'concluiu', 'numeros', //
        'metricas', 'escala', 'faixas', 'voltas', 'forma', 'colunas', 'amostras',
      ]);
      expect(d['versao'], 1);
      expect(d['inicio'], DateTime.utc(2026, 11, 3, 22).millisecondsSinceEpoch ~/ 1000);
      expect(d['modo'], 'rota');
      expect(d['rota'], 'r1');
      expect(d['nome'], 'Volta do bairro');
      expect(d['colunas'], ['t', 'd', 'v', 'pot', 'cad', 'inc', 'alt', 'fc', 'x', 'y']);
      expect(jsonDecode(jsonEncode(d)), isA<Map<String, dynamic>>());
    });

    test('o topo da tela: título, detalhes e se concluiu', () {
      final d = detalheHa(voltaDoBairro());
      expect(d['titulo'], 'Rota concluída!');
      expect(d['detalhes'], ['2 voltas + 0,30 km', 'sentido horário']);
      expect(d['concluiu'], isTrue);
    });

    test('os números do cartão: médias, máximas e a cadência só girando', () {
      final r = voltaDoBairro();
      final n = detalheHa(r)['numeros'] as Map;
      expect(n['distancia_m'], 3500);
      expect(n['tempo_s'], 700);
      expect(n['velocidade_kmh'], 18.0);
      expect(n['potencia_w'], 157);
      expect(n['kcal'], 110);
      expect(n['velocidade_max_kmh'], 19.8); // 18 + 6 × 0,3
      expect(n['potencia_max_w'], 217); // 100 + 39 × 3
      expect(n['cadencia_media_rpm'], 80, reason: 'as paradas de giro (0 rpm) não entram na média');
    });

    test('as métricas na ordem dos botões, com a faixa de cores da tela', () {
      final r = voltaDoBairro();
      final d = detalheHa(r);
      final metricas = (d['metricas'] as List).cast<Map>();
      expect([for (final m in metricas) m['col']], ['v', 'pot', 'cad', 'inc']);
      expect(metricas.first, containsPair('nome', 'Velocidade'));
      expect(metricas.first, containsPair('unidade', 'km/h'));
      expect(metricas.first, containsPair('casas', 1));
      final (lo, hi) = colorRange(metricSeries(r.samples, RideMetric.potencia));
      expect(metricas[1]['min'], (lo * 10).round() / 10);
      expect(metricas[1]['max'], (hi * 10).round() / 10);
      expect(d['escala'], ['#2563EB', '#06B6D4', '#22C55E', '#EAB308', '#DC2626']);
      expect(d['faixas'], 24);
    });

    test('com cinta cardíaca, a frequência entra nas métricas e nas amostras', () {
      final d = detalheHa(voltaDoBairro(fc: 140));
      expect([for (final m in (d['metricas'] as List).cast<Map>()) m['col']], contains('fc'));
      expect(linha(d, 10)['fc'], inInclusiveRange(140, 144));
    });
  });

  group('amostras', () {
    test('até 600, a mesma suavização da tela (média de 5 s)', () {
      final r = voltaDoBairro();
      final d = detalheHa(r, maxLinhas: 1000);
      expect(d['amostras'], hasLength(700));
      final pot = metricSeries(r.samples, RideMetric.potencia);
      final v = metricSeries(r.samples, RideMetric.velocidade);
      for (final i in [0, 1, 50, 399, 699]) {
        expect(linha(d, i)['t'], i + 1);
        expect(linha(d, i)['d'], (i + 1) * 5);
        expect(linha(d, i)['pot'], pot[i].round());
        expect(linha(d, i)['v'], (v[i] * 10).round() / 10);
        expect(linha(d, i)['alt'], 700);
        expect(linha(d, i)['inc'], 0.0);
        expect(linha(d, i)['fc'], isNull);
      }
    });

    test('pedal longo: junta em grupos (média do grupo, tempo e distância do fim dele)', () {
      final r = voltaDoBairro(n: 1800);
      final d = detalheHa(r);
      expect(d['amostras'], hasLength(600));
      final pot = metricSeries(r.samples, RideMetric.potencia);
      expect(linha(d, 0)['t'], 3);
      expect(linha(d, 0)['d'], 15);
      expect(linha(d, 0)['pot'], ((pot[0] + pot[1] + pot[2]) / 3).round());
      expect(linha(d, 599)['t'], 1800);
      expect(linha(d, 599)['d'], 9000);
    });

    test('x e y de 0 a 100 no caminho; cada volta passa pelo mesmo lugar', () {
      final d = detalheHa(voltaDoBairro(), maxLinhas: 1000);
      // a 400 m do começo, a volta quadrada (sobe para o norte) chega ao canto de cima, à esquerda
      expect([linha(d, 79)['x'], linha(d, 79)['y']], [0.0, 100.0]);
      // 400 m depois de começar a 2.ª volta, o mesmo canto
      expect([linha(d, 399)['x'], linha(d, 399)['y']], [0.0, 100.0]);
      // 800 m: o canto de cima, à direita
      expect([linha(d, 159)['x'], linha(d, 159)['y']], [100.0, 100.0]);
      for (var i = 0; i < 700; i++) {
        expect(linha(d, i)['x'] as double, inInclusiveRange(0, 100));
        expect(linha(d, i)['y'] as double, inInclusiveRange(0, 100));
      }
    });

    test('o desenho do caminho na mesma escala, até 200 pontos', () {
      final forma = (detalheHa(voltaDoBairro())['forma'] as List).cast<List>();
      expect(forma.first, [0.0, 0.0]);
      expect(forma.last, [0.0, 0.0]);
      expect(forma, containsAll([
        [0.0, 100.0],
        [100.0, 100.0],
        [100.0, 0.0],
      ]));
      expect(forma.length, lessThanOrEqualTo(200));
    });

    test('as voltas, como os botões da tela (a última parcial)', () {
      expect(detalheHa(voltaDoBairro())['voltas'], [
        {'inicio_m': 0, 'metros': 1600, 'tempo_s': 320, 'completa': true},
        {'inicio_m': 1600, 'metros': 1600, 'tempo_s': 320, 'completa': true},
        {'inicio_m': 3200, 'metros': 1600, 'tempo_s': 60, 'completa': false},
      ]);
    });
  });

  group('pedal livre (sem caminho)', () {
    test('sem mapa: x, y, inclinação e altitude vão null', () {
      final d = detalheHa(livre(300));
      expect(d['modo'], 'livre');
      expect(d['rota'], isNull);
      expect(d['nome'], 'Pedal livre');
      expect(d['titulo'], 'Pedal concluído!');
      expect(d['detalhes'], isEmpty);
      expect(d['forma'], isEmpty);
      expect(d['voltas'], isEmpty);
      expect([for (final m in (d['metricas'] as List).cast<Map>()) m['col']], ['v', 'pot', 'cad']);
      final l = linha(d, 10);
      expect([l['inc'], l['alt'], l['x'], l['y']], [null, null, null, null]);
      expect(l['v'], isNotNull);
    });
  });

  group('tamanho', () {
    test('3 horas com cinta cardíaca: até 600 amostras e abaixo de 60 KB', () {
      final corpo = corpoDetalheHa(voltaDoBairro(n: 3 * 3600, fc: 150));
      expect(utf8.encode(corpo).length, lessThan(60 * 1000));
      final d = jsonDecode(corpo) as Map<String, dynamic>;
      expect((d['amostras'] as List).length, lessThanOrEqualTo(600));
    });

    test('se ainda passar do limite, junta mais as amostras', () {
      final corpo = corpoDetalheHa(voltaDoBairro(n: 3600), limiteBytes: 10 * 1000);
      expect(utf8.encode(corpo).length, lessThanOrEqualTo(10 * 1000));
      expect((jsonDecode(corpo)['amostras'] as List).length, lessThan(600));
    });
  });

  group('topo da tela do pedal', () {
    RideRecord ida({required double distancia, int voltas = 0, bool invertido = false, bool completo = true}) => RideRecord(
      id: 'i',
      routeId: 'r',
      mode: RideMode.rota,
      startedAt: DateTime(2026, 11, 1),
      movingTimeS: 100,
      distanceM: distancia,
      avgPowerW: 100,
      avgSpeedKmh: 15,
      gainM: 0,
      kcal: 10,
      completed: completo,
      laps: voltas,
      reversed: invertido,
      track: northProfile(List.filled(51, 700.0)), // 1 km
    );

    test('ida pela metade, no sentido contrário', () {
      final r = ida(distancia: 500, invertido: true);
      final c = cabecalhoPedal(r, RouteProfile(r.track!));
      expect(c.titulo, 'Pedal encerrado');
      expect(c.detalhes, ['sentido invertido', 'faltaram 0,50 km']);
      expect(c.concluiu, isFalse);
    });

    test('pedal salvo no meio (app fechado)', () {
      final r = ida(distancia: 1000, voltas: 1, completo: false);
      expect(cabecalhoPedal(r, RouteProfile(r.track!)).titulo, 'Pedal salvo');
    });
  });
}
