import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_live.dart';
import 'package:pedal_local/bike/bike_source.dart';

void main() {
  final agora = DateTime(2026, 10, 11, 20, 41);
  DateTime antes(int segundos) => agora.subtract(Duration(seconds: segundos));

  BikeLive status({
    BikeConnection conexao = BikeConnection.conectada,
    bool temBike = true,
    DateTime? pacote,
    DateTime? pedalando,
  }) => bikeLiveStatus(
    connection: conexao,
    hasSource: temBike,
    lastPacket: pacote,
    lastPedaling: pedalando,
    now: agora,
  );

  test('sem bike escolhida ou desconectada', () {
    expect(status(temBike: false), BikeLive.semBike);
    expect(status(conexao: BikeConnection.desconectada), BikeLive.semBike);
  });

  test('conectando ou reconectando depois de uma queda', () {
    expect(status(conexao: BikeConnection.conectando), BikeLive.conectando);
    expect(status(conexao: BikeConnection.caiu), BikeLive.conectando);
  });

  test(
    'conectada mas nada chegou ainda, ou parou de chegar há mais de 5 s',
    () {
      expect(status(), BikeLive.esperando);
      expect(status(pacote: antes(6)), BikeLive.esperando);
    },
  );

  test('pacotes chegando, mas tudo parado: falta pedalar', () {
    expect(status(pacote: antes(1)), BikeLive.parada);
    expect(status(pacote: antes(1), pedalando: antes(4)), BikeLive.parada);
  });

  test('giro ou potência nos últimos 3 s: ao vivo', () {
    expect(status(pacote: antes(0), pedalando: antes(0)), BikeLive.aoVivo);
    expect(status(pacote: antes(1), pedalando: antes(3)), BikeLive.aoVivo);
  });
}
