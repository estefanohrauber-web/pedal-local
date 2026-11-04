import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/ha_retrato.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:pedal_local/domain/stats.dart';

import '../support/geo_helpers.dart';

/// 1/1/2026 00:00 UTC, em segundos.
const virada = 1767225600;

RideRecord pedal(
  String id, {
  required DateTime inicio,
  RideMode modo = RideMode.livre,
  String? rota,
  double distancia = 3215.4,
  double tempo = 812.2,
  double potencia = 117.6,
  double velocidade = 14.24,
  double subida = 23.4,
  double kcal = 95.3,
  bool completo = true,
  int voltas = 0,
  bool fechada = false,
  String? treino,
  List<ProfilePoint>? caminho,
}) => RideRecord(
  id: id,
  routeId: rota,
  mode: modo,
  startedAt: inicio,
  movingTimeS: tempo,
  distanceM: distancia,
  avgPowerW: potencia,
  avgSpeedKmh: velocidade,
  gainM: subida,
  kcal: kcal,
  completed: completo,
  laps: voltas,
  loop: fechada,
  workoutId: treino == null ? null : 'meu',
  workoutName: treino,
  track: caminho,
);

RouteRecord rotaDeTeste(String id, String nome, {int cor = 0, List<ProfilePoint>? pontos}) => RouteRecord(
  id: id,
  name: nome,
  createdAt: DateTime(2026, 10, 1),
  waypoints: const [GeoPoint(-23.5, -46.6)],
  points: pontos ?? squareLoop(400),
  distanceM: 1600,
  gainM: 0,
  lossM: 0,
  colorIndex: cor,
);

/// Caminho em L: 1 km para o norte e depois 500 m para o leste.
List<ProfilePoint> emL() {
  const inicio = GeoPoint(-23.5, -46.6);
  final mPorGrauLon = mPerDegLat * math.cos(inicio.lat * math.pi / 180);
  final norte = northLine(51, 20, start: inicio);
  final topo = norte.last;
  return [
    for (final p in norte) ProfilePoint(p.lat, p.lon, 0),
    for (var i = 1; i <= 25; i++) ProfilePoint(topo.lat, topo.lon + i * 20 / mPorGrauLon, 0),
  ];
}

void main() {
  final utc = DateTime.fromMillisecondsSinceEpoch(virada * 1000, isUtc: true);

  test('formato: versão, nome, peso, colunas e o resumo de todos os pedais', () {
    final pedais = [
      pedal('a', inicio: utc, distancia: 1000.4, tempo: 300.6, subida: 10.2),
      pedal('b', inicio: utc.add(const Duration(days: 1)), distancia: 2000.4, tempo: 600.6, subida: 0.4),
    ];
    final r = retratoHa(nome: ' Estéfano ', pesoKg: 78, pedais: pedais, rotas: const []);
    expect(r.keys, ['versao', 'nome', 'peso_kg', 'resumo', 'colunas', 'pedais', 'rotas']);
    expect(r['versao'], 1);
    expect(r['nome'], 'Estéfano');
    expect(r['peso_kg'], 78);
    expect(r['peso_kg'], isA<int>());
    expect(r['colunas'], [
      'inicio', 'distancia_m', 'tempo_s', 'potencia_w', 'velocidade_kmh', 'subida_m', //
      'kcal', 'completo', 'nome', 'modo', 'rota', 'voltas',
    ]);
    final s = summarize(pedais);
    expect(r['resumo'], {
      'pedais': 2,
      'distancia_m': s.distanceM.round(),
      'tempo_s': s.movingTimeS.round(),
      'subida_m': s.gainM.round(),
    });
    expect(r['rotas'], isEmpty);
    // vira JSON de verdade (sem tipos do Dart no meio)
    expect(jsonDecode(jsonEncode(r)), r);
  });

  test('cada pedal na ordem das colunas, do mais novo ao mais velho', () {
    final r = retratoHa(
      nome: 'Ana',
      pesoKg: 60,
      pedais: [
        pedal('livre', inicio: utc, distancia: 10400, tempo: 1800, potencia: 135.4, velocidade: 20.83, subida: 0),
        pedal(
          'rota',
          inicio: utc.add(const Duration(days: 2)),
          modo: RideMode.rota,
          rota: 'r1',
          voltas: 3,
          fechada: true,
        ),
        pedal(
          'treino',
          inicio: utc.add(const Duration(days: 1)),
          modo: RideMode.treino,
          treino: 'Série de tiros',
          completo: false,
          voltas: 1,
        ),
      ],
      rotas: [rotaDeTeste('r1', 'Entre pontes')],
    );
    final linhas = r['pedais'] as List;
    expect(linhas, [
      [virada + 2 * 86400, 3215, 812, 118, 14.2, 23, 95, 1, 'Entre pontes', 'rota', 'r1', 3],
      // o treino “terminado” tem laps = 1, mas não é volta fechada: voltas = 0
      [virada + 86400, 3215, 812, 118, 14.2, 23, 95, 0, 'Série de tiros', 'treino', null, 0],
      [virada, 10400, 1800, 135, 20.8, 0, 95, 1, 'Pedal livre', 'livre', null, 0],
    ]);
    expect((linhas.first as List)[0], isA<int>());
    expect((linhas.first as List)[4], isA<double>());
  });

  test('a hora de início é UTC, igual para hora local e UTC', () {
    final local = DateTime.fromMillisecondsSinceEpoch(virada * 1000);
    final r = retratoHa(nome: null, pesoKg: 70, pedais: [pedal('a', inicio: local)], rotas: const []);
    expect(((r['pedais'] as List).single as List).first, virada);
  });

  test('rotas: só as que aparecem nos pedais, com nome, cor e forma', () {
    final r = retratoHa(
      nome: 'Ana',
      pesoKg: 60,
      pedais: [
        pedal('a', inicio: utc, modo: RideMode.rota, rota: 'r1'),
        pedal('b', inicio: utc.add(const Duration(hours: 1)), modo: RideMode.rota, rota: 'r1'),
      ],
      rotas: [rotaDeTeste('r1', 'Entre pontes', cor: 2), rotaDeTeste('r2', 'Casa trabalho', cor: 1)],
    );
    final rotas = r['rotas'] as Map;
    expect(rotas.keys, ['r1']);
    final r1 = rotas['r1'] as Map;
    expect(r1['nome'], 'Entre pontes');
    expect(r1['cor'], 2);
    expect(r1['forma'], [
      [0, 0], [0, 100], [100, 100], [100, 0], [0, 0], //
    ]);
  });

  test('rota apagada: o pedal fica “Rota”, com o desenho do próprio pedal; sem desenho, sem rota', () {
    final r = retratoHa(
      nome: 'Ana',
      pesoKg: 60,
      pedais: [
        pedal('com', inicio: utc, modo: RideMode.rota, rota: 'sumiu', caminho: emL()),
        pedal('sem', inicio: utc.subtract(const Duration(days: 1)), modo: RideMode.rota, rota: 'tambem'),
      ],
      rotas: const [],
    );
    final linhas = r['pedais'] as List;
    expect((linhas[0] as List).sublist(8), ['Rota', 'rota', 'sumiu', 0]);
    expect((linhas[1] as List).sublist(8), ['Rota', 'rota', null, 0]);
    expect(r['rotas'], {
      'sumiu': {
        'nome': 'Rota',
        'cor': 0,
        'forma': [
          [25, 0], [25, 100], [75, 100], //
        ],
      },
    });
  });

  test('sem nome, o nome fica de fora; peso quebrado vai com uma casa', () {
    final vazio = retratoHa(nome: '  ', pesoKg: 78.46, pedais: const [], rotas: const []);
    expect(vazio.containsKey('nome'), isFalse);
    expect(vazio['peso_kg'], 78.5);
    expect(vazio['resumo'], {'pedais': 0, 'distancia_m': 0, 'tempo_s': 0, 'subida_m': 0});
    expect(vazio['pedais'], isEmpty);
    expect(retratoHa(nome: null, pesoKg: 70, pedais: const [], rotas: const []).containsKey('nome'), isFalse);
  });

  group('forma do caminho', () {
    test('no máximo 24 pontos inteiros de 0 a 100', () {
      // volta torta: um círculo de 300 pontos
      const c = GeoPoint(-23.5, -46.6);
      final circulo = [
        for (var i = 0; i <= 300; i++)
          ProfilePoint(c.lat + 0.01 * math.sin(i * 2 * math.pi / 300), c.lon + 0.01 * math.cos(i * 2 * math.pi / 300), 0),
      ];
      final f = formaHa(circulo);
      expect(f.length, inInclusiveRange(20, 24));
      for (final p in f) {
        expect(p, hasLength(2));
        for (final v in p) {
          expect(v, isA<int>());
          expect(v, inInclusiveRange(0, 100));
        }
      }
      expect(f.first, f.last, reason: 'a volta fecha no começo');
    });

    test('mantém a proporção, centraliza e o y cresce para o norte', () {
      expect(formaHa(emL()), [
        [25, 0], [25, 100], [75, 100], //
      ]);
    });

    test('a proporção leva em conta a latitude (1 grau de longitude é mais curto)', () {
      // 0,01° para o norte e 0,01° para o leste, a 60° de latitude: o leste mede a metade
      final f = formaHa(const [ProfilePoint(60, 10, 0), ProfilePoint(60.01, 10, 0), ProfilePoint(60.01, 10.01, 0)]);
      expect(f, [
        [25, 0], [25, 100], [75, 100], //
      ]);
    });

    test('um caminho com 1 ponto, ou parado no lugar, não tem desenho', () {
      expect(formaHa(const []), isEmpty);
      expect(formaHa(const [ProfilePoint(-23.5, -46.6, 0)]), isEmpty);
      expect(formaHa(const [ProfilePoint(-23.5, -46.6, 0), ProfilePoint(-23.5, -46.6, 1)]), isEmpty);
    });

    test('pede menos pontos e respeita', () {
      final f = formaHa(squareLoop(400), maxPontos: 3);
      expect(f.length, lessThanOrEqualTo(3));
    });
  });

  group('tamanho', () {
    List<RideRecord> muitos(int n) => [
      for (var i = 0; i < n; i++)
        pedal(
          'p$i',
          inicio: utc.add(Duration(hours: i)),
          modo: RideMode.treino,
          treino: 'Treino com um nome bem comprido, de verdade',
        ),
    ];

    test('com muitos anos de pedais, manda os 1500 mais novos e fica abaixo de 200 KB', () {
      final pedais = muitos(2000);
      final corpo = corpoHa(nome: 'Ana', pesoKg: 60, pedais: pedais, rotas: const []);
      expect(utf8.encode(corpo).length, lessThan(200 * 1000));
      final r = jsonDecode(corpo) as Map<String, dynamic>;
      final linhas = r['pedais'] as List;
      expect(linhas, hasLength(1500));
      expect((linhas.first as List).first, virada + 1999 * 3600, reason: 'o mais novo primeiro');
      expect((r['resumo'] as Map)['pedais'], 2000, reason: 'o resumo conta todos');
    });

    test('se ainda passar do limite, corta mais pedais antigos', () {
      final corpo = corpoHa(nome: 'Ana', pesoKg: 60, pedais: muitos(100), rotas: const [], limiteBytes: 3000);
      expect(utf8.encode(corpo).length, lessThanOrEqualTo(3000));
      final linhas = (jsonDecode(corpo) as Map)['pedais'] as List;
      expect(linhas, isNotEmpty);
      expect(linhas.length, lessThan(100));
      expect((linhas.first as List).first, virada + 99 * 3600);
    });
  });
}
