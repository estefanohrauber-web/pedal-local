import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ftms_control.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  test('o que a bike aceita: potência (bit 3), resistência (bit 2) e simulação (bit 13)', () {
    final tudo = parseFeatures(bytes([0x00, 0x00, 0x00, 0x00, 0x0C, 0x20, 0x00, 0x00]));
    expect(tudo.power, isTrue);
    expect(tudo.resistance, isTrue);
    expect(tudo.simulation, isTrue);
    final soResistencia = parseFeatures(bytes([0x86, 0x50, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00]));
    expect(soResistencia.power, isFalse);
    expect(soResistencia.resistance, isTrue);
    expect(soResistencia.any, isTrue);
    expect(parseFeatures(bytes([1, 2, 3])).any, isFalse);
  });

  test('faixas de resistência (décimos) e de potência (watts)', () {
    final r = parseResistanceRange(bytes([0x0A, 0x00, 0x40, 0x01, 0x0A, 0x00]))!;
    expect(r.min, 1);
    expect(r.max, 32);
    expect(r.step, 1);
    final p = parsePowerRange(bytes([0x19, 0x00, 0xE8, 0x03, 0x05, 0x00]))!;
    expect(p.min, 25);
    expect(p.max, 1000);
    expect(p.step, 5);
  });

  test('comandos em bytes', () {
    expect(requestControlCommand(), [0x00]);
    expect(startCommand(), [0x07]);
    expect(resetCommand(), [0x01]);
    expect(targetPowerCommand(200), [0x05, 0xC8, 0x00]);
    expect(targetPowerCommand(300), [0x05, 0x2C, 0x01]);
    expect(targetResistanceCommand(8), [0x04, 0x50, 0x00]);
    // 6 % = 600 centésimos = 0x0258
    expect(simulationCommand(0.06), [0x11, 0x00, 0x00, 0x58, 0x02, 40, 51]);
    // descida de 3 %: −300 = 0xFED4
    expect(simulationCommand(-0.03), [0x11, 0x00, 0x00, 0xD4, 0xFE, 40, 51]);
  });

  test('resposta da bike', () {
    final ok = parseControlResponse(bytes([0x80, 0x05, 0x01]))!;
    expect(ok.opcode, 5);
    expect(ok.ok, isTrue);
    expect(parseControlResponse(bytes([0x80, 0x04, 0x02]))!.ok, isFalse);
    expect(parseControlResponse(bytes([0x05, 0x01])), isNull);
  });
}
