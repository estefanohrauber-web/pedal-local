import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_log.dart';

void main() {
  final t0 = DateTime(2026, 10, 9, 20, 15, 3, 42);

  test('cada linha leva dia e hora; fica só o fim quando passa do limite', () {
    withClock(Clock.fixed(t0), () {
      final log = BikeLog(maxLines: 3);
      for (var i = 1; i <= 5; i++) {
        log.add('evento $i');
      }
      expect(log.lines, [
        '10-09 20:15:03.042 evento 3',
        '10-09 20:15:03.042 evento 4',
        '10-09 20:15:03.042 evento 5',
      ]);
    });
  });

  test('pacote cru em hexadecimal; os últimos pacotes ficam à mão', () {
    withClock(Clock.fixed(t0), () {
      final log = BikeLog();
      log.add('conectou');
      log.packet(Uint8List.fromList([0x45, 0x00, 0xa0, 0x0f]));
      log.packet(Uint8List.fromList([0x00, 0x02, 0xc4]));
      expect(log.lines[1], '10-09 20:15:03.042 dados 45 00 a0 0f');
      expect(log.recentPackets(1), ['10-09 20:15:03.042 dados 00 02 c4']);
      expect(log.recentPackets(5).length, 2);
    });
  });

  test(
    'grava no arquivo e, ao abrir o app de novo, continua o mesmo diário',
    () async {
      final dir = await Directory.systemTemp.createTemp('bike_log');
      final arquivo = File('${dir.path}/bike_log.txt');
      final primeiro = BikeLog(file: () async => arquivo, maxLines: 4);
      withClock(Clock.fixed(t0), () {
        primeiro.add('a');
        primeiro.add('b');
        primeiro.add('c');
      });
      await primeiro.flush();
      expect(await arquivo.readAsLines(), hasLength(3));

      final segundo = BikeLog(file: () async => arquivo, maxLines: 4);
      withClock(Clock.fixed(t0.add(const Duration(days: 1))), () {
        segundo.add('d');
        segundo.add('e');
      });
      await segundo.flush();
      final linhas = await arquivo.readAsLines();
      expect(linhas, [
        '10-09 20:15:03.042 b',
        '10-09 20:15:03.042 c',
        '10-10 20:15:03.042 d',
        '10-10 20:15:03.042 e',
      ]);
      expect(segundo.lines, linhas);
      await dir.delete(recursive: true);
    },
  );

  test('sem arquivo (ou arquivo com problema) não atrapalha', () async {
    final log = BikeLog(
      file: () async => throw const FileSystemException('sem pasta'),
    );
    log.add('x');
    await log.flush();
    expect(log.lines.single, endsWith(' x'));
    await BikeLog().flush();
  });
}
