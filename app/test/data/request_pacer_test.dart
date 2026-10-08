import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/services/request_pacer.dart';

void main() {
  late DateTime agora;
  late List<Duration> esperas;
  late RequestPacer pacer;

  setUp(() {
    agora = DateTime(2026, 10, 8, 10);
    esperas = [];
    pacer = RequestPacer(
      now: () => agora,
      sleep: (d) async {
        esperas.add(d);
        agora = agora.add(d);
      },
    );
  });

  test('o primeiro pedido sai na hora', () async {
    await pacer.wait();
    expect(esperas, isEmpty);
  });

  test('o segundo espera completar 1 segundo', () async {
    await pacer.wait();
    agora = agora.add(const Duration(milliseconds: 300));
    await pacer.wait();
    expect(esperas, [const Duration(milliseconds: 700)]);
  });

  test('depois de 1 segundo não espera', () async {
    await pacer.wait();
    agora = agora.add(const Duration(seconds: 2));
    await pacer.wait();
    expect(esperas, isEmpty);
  });

  test('pedidos ao mesmo tempo saem em fila, 1 por segundo', () async {
    final relogio = <Duration>[];
    final fila = RequestPacer(now: () => agora, sleep: (d) async => relogio.add(d));
    await Future.wait([fila.wait(), fila.wait(), fila.wait()]);
    expect(relogio, [const Duration(seconds: 1), const Duration(seconds: 2)]);
  });
}
