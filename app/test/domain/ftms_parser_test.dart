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
}
