import 'dart:async';
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

  test('resposta da bike em palavras, para o diário', () {
    expect(describeControlResponse(const ControlResponse(0x00, 1)), 'pedir controle: ok');
    expect(describeControlResponse(const ControlResponse(0x07, 5)), 'começar: sem permissão');
    expect(describeControlResponse(const ControlResponse(0x05, 2)), 'potência alvo: comando não aceito');
    expect(describeControlResponse(const ControlResponse(0x30, 9)), 'comando 0x30: código 9');
  });

  test('aviso de estado da bike (Machine Status) em palavras', () {
    expect(describeMachineStatus(bytes([0x04])), 'começou');
    expect(describeMachineStatus(bytes([0x02, 0x01])), 'parou');
    expect(describeMachineStatus(bytes([0x02, 0x02])), 'pausou');
    expect(describeMachineStatus(bytes([0x01])), 'reiniciou');
    expect(describeMachineStatus(bytes([0xFF])), 'o app perdeu o controle');
    expect(describeMachineStatus(bytes([0x08, 0xC8, 0x00])), 'aviso 0x08');
    expect(describeMachineStatus(bytes([])), 'aviso vazio');
  });

  group('começar a sessão (pedir controle e depois começar)', () {
    test('manda os dois comandos e devolve a resposta ao começar', () async {
      final respostas = StreamController<ControlResponse>.broadcast();
      final enviados = <List<int>>[];
      final r = await startSession(
        write: (c) async {
          enviados.add(c.toList());
          scheduleMicrotask(() => respostas.add(ControlResponse(c[0], 1)));
        },
        responses: respostas.stream,
      );
      expect(enviados, [
        [0x00],
        [0x07],
      ]);
      expect(r!.opcode, 0x07);
      expect(r.ok, isTrue);
    });

    test('só manda começar depois que a bike responde ao pedido de controle', () async {
      final respostas = StreamController<ControlResponse>.broadcast();
      final enviados = <int>[];
      final fim = startSession(write: (c) async => enviados.add(c[0]), responses: respostas.stream);
      await pumpEventQueue();
      expect(enviados, [0x00]);
      respostas.add(const ControlResponse(0x00, 1));
      await pumpEventQueue();
      expect(enviados, [0x00, 0x07]);
      respostas.add(const ControlResponse(0x07, 1));
      expect((await fim)!.ok, isTrue);
    });

    test('bike que não responde: manda começar mesmo assim e devolve null', () async {
      final enviados = <int>[];
      final r = await startSession(
        write: (c) async => enviados.add(c[0]),
        responses: StreamController<ControlResponse>.broadcast().stream,
        wait: const Duration(milliseconds: 10),
      );
      expect(enviados, [0x00, 0x07]);
      expect(r, isNull);
    });

    test('bike que recusa: devolve a recusa ao começar', () async {
      final respostas = StreamController<ControlResponse>.broadcast();
      final r = await startSession(
        write: (c) async => scheduleMicrotask(() => respostas.add(ControlResponse(c[0], 5))),
        responses: respostas.stream,
      );
      expect(r!.ok, isFalse);
      expect(r.result, 5);
    });
  });
}
