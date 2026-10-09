import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ftms_parser.dart';

Uint8List pkt(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  test('velocidade e cadência', () {
    // flags 0x0004: bit 0 = 0 (velocidade presente), bit 2 (cadência)
    expect(
      parseIndoorBikeData(pkt([0x04, 0x00, 0xc4, 0x09, 0xa0, 0x00])),
      const IndoorBikeData(speedKmh: 25, cadence: 80),
    );
  });

  test('velocidade, cadência e potência', () {
    expect(
      parseIndoorBikeData(pkt([0x44, 0x00, 0xc4, 0x09, 0xa0, 0x00, 0x96, 0x00])),
      const IndoorBikeData(speedKmh: 25, cadence: 80, power: 150),
    );
  });

  test('lê o nível de resistência e pula os outros campos opcionais', () {
    // flags 0x007E: vel. média, cadência, cad. média, distância, resistência, potência
    final r = parseIndoorBikeData(pkt([
      0x7e, 0x00,
      0xc4, 0x09, // velocidade 25,00 km/h
      0x10, 0x27, // velocidade média (ignorada)
      0xb4, 0x00, // cadência 90 rpm
      0x00, 0x00, // cadência média
      0x10, 0x27, 0x00, // distância
      0x05, 0x00, // resistência
      0xc8, 0x00, // potência 200 W
    ]));
    expect(r, const IndoorBikeData(speedKmh: 25, cadence: 90, power: 200, resistance: 5));
  });

  test('bit 0 ligado: sem velocidade', () {
    expect(
      parseIndoorBikeData(pkt([0x45, 0x00, 0xa0, 0x00, 0x96, 0x00])),
      const IndoorBikeData(cadence: 80, power: 150),
    );
  });

  test('potência negativa (sint16)', () {
    expect(parseIndoorBikeData(pkt([0x45, 0x00, 0xa0, 0x00, 0xf6, 0xff])).power, -10);
  });

  test('frequência cardíaca depois da energia', () {
    // flags 0x0304: velocidade, cadência, energia (5 bytes), FC
    final r = parseIndoorBikeData(pkt([0x04, 0x03, 0xc4, 0x09, 0xa0, 0x00, 1, 0, 2, 0, 3, 142]));
    expect(r.cadence, 80);
    expect(r.heartRate, 142);
  });

  test('pacote cortado não quebra', () {
    expect(
      parseIndoorBikeData(pkt([0x44, 0x00, 0xc4, 0x09, 0xa0])),
      const IndoorBikeData(speedKmh: 25),
    );
  });

  test('pacote vazio', () {
    expect(parseIndoorBikeData(pkt([])), const IndoorBikeData());
  });

  group('leitura dividida em pacotes (bit More Data)', () {
    final t0 = DateTime(2026, 10, 9, 20);
    DateTime em(int ms) => t0.add(Duration(milliseconds: ms));
    // 1º pedaço: bit 0 ligado (mais dados vêm depois, sem velocidade), cadência e potência.
    IndoorBikeData pedaco1(int cad2, int watts) =>
        parseIndoorBikeData(pkt([0x45, 0x00, cad2 & 0xff, cad2 >> 8, watts & 0xff, watts >> 8]));
    // 2º pedaço: velocidade e frequência cardíaca (flags 0x0200), sem cadência e potência.
    final pedaco2 = parseIndoorBikeData(pkt([0x00, 0x02, 0xc4, 0x09, 0]));

    test('o pedaço só com a velocidade não apaga a cadência e a potência do anterior', () {
      final m = IndoorBikeAssembler();
      expect(m.add(pedaco1(160, 150), em(0)), const IndoorBikeData(cadence: 80, power: 150));
      expect(m.add(pedaco2, em(40)), const IndoorBikeData(speedKmh: 25, cadence: 80, power: 150, heartRate: 0));
      expect(m.add(pedaco1(170, 160), em(1000)), const IndoorBikeData(speedKmh: 25, cadence: 85, power: 160, heartRate: 0));
    });

    test('valor novo de um campo troca o antigo, inclusive zero (parou de pedalar)', () {
      final m = IndoorBikeAssembler();
      m.add(pedaco1(160, 150), em(0));
      expect(m.add(pedaco1(0, 0), em(1000)).cadence, 0);
      expect(m.add(pedaco2, em(1040)).power, 0);
    });

    test('campo que parou de vir há mais de 3 s some', () {
      final m = IndoorBikeAssembler();
      m.add(pedaco1(160, 150), em(0));
      expect(m.add(pedaco2, em(3000)).cadence, 80);
      final depois = m.add(pedaco2, em(3500));
      expect(depois.cadence, isNull);
      expect(depois.power, isNull);
      expect(depois.speedKmh, 25);
    });

    test('recomeçar (bike reconectada) esquece tudo', () {
      final m = IndoorBikeAssembler();
      m.add(pedaco1(160, 150), em(0));
      m.reset();
      expect(m.add(pedaco2, em(100)), const IndoorBikeData(speedKmh: 25, heartRate: 0));
    });
  });
}
