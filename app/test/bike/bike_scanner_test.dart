import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_scanner.dart';

void main() {
  test('reconhece bike pelo serviço FTMS ou pelo nome FS-', () {
    expect(isLikelyBike(name: 'FS-1A2B3C'), isTrue);
    expect(isLikelyBike(name: 'fs-1a2b'), isTrue);
    expect(isLikelyBike(name: 'Qualquer', services: ['00001826-0000-1000-8000-00805F9B34FB']), isTrue);
    expect(isLikelyBike(name: 'JBL Flip'), isFalse);
    expect(isLikelyBike(), isFalse);
  });

  test('ordena: bikes primeiro, depois sinal mais forte', () {
    final lista = sortFound([
      const FoundDevice(id: 'a', name: 'Fone', likelyBike: false, rssi: -40),
      const FoundDevice(id: 'b', name: 'FS-1', likelyBike: true, rssi: -80),
      const FoundDevice(id: 'c', name: 'FS-2', likelyBike: true, rssi: -60),
      const FoundDevice(id: 'd', name: 'TV', likelyBike: false),
    ]);
    expect(lista.map((d) => d.id), ['c', 'b', 'a', 'd']);
  });

  test('textos dos problemas de Bluetooth', () {
    expect(bleProblemText(BleProblem.desligado), contains('desligado'));
    expect(bleProblemText(BleProblem.semPermissao), contains('permissão'));
  });
}
