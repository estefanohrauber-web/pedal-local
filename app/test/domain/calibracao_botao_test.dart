import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/calibracao_botao.dart';

List<VoltaMedida> voltas(List<(double, double)> giroEWatts) => [
  for (var i = 0; i < giroEWatts.length; i++)
    VoltaMedida(i, giroEWatts[i].$1, giroEWatts[i].$2),
];

void main() {
  test('até que volta a pessoa manteve o giro', () {
    expect(
      limitePedalavel(
        voltas([
          (61, 153),
          (60, 149),
          (58, 141),
          (52, 119),
          (44, 87),
          (40, 77),
        ]),
      ),
      3,
    );
    expect(
      limitePedalavel(voltas([(62, 157), (60, 149), (59, 145)])),
      2,
    ); // aguentou até o fim
    expect(limitePedalavel(voltas([(0, 0), (0, 0)])), isNull); // sem a bike
    expect(limitePedalavel(const []), isNull);
  });

  test('a ordem das voltas não importa (desfazer regrava uma volta)', () {
    expect(
      limitePedalavel(const [
        VoltaMedida(2, 40, 77),
        VoltaMedida(0, 60, 149),
        VoltaMedida(1, 58, 141),
      ]),
      1,
    );
  });

  test('a Winnek não sente o botão: o mesmo giro dá os mesmos watts', () {
    expect(
      bikeSenteOBotao(
        voltas([(60, 149), (61, 153), (60, 149), (60, 149), (59, 145)]),
      ),
      isFalse,
    );
  });

  test('uma bike que mede o freio dá mais watts no mesmo giro', () {
    expect(
      bikeSenteOBotao(
        voltas([(60, 90), (60, 110), (60, 130), (60, 150), (59, 170)]),
      ),
      isTrue,
    );
  });

  test('sem giros parecidos para comparar, não dá para saber', () {
    expect(
      bikeSenteOBotao(voltas([(70, 200), (60, 149), (50, 111), (40, 77)])),
      isNull,
    );
    expect(bikeSenteOBotao(voltas([(0, 0), (0, 0), (0, 0), (0, 0)])), isNull);
  });
}
