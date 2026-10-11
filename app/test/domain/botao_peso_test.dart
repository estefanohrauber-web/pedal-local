import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/botao_peso.dart';
import 'package:pedal_local/domain/power.dart';

void main() {
  const botao = BotaoPeso(8);

  test('posição do botão para cada inclinação: o botão todo cobre até 10%', () {
    expect(botao.posicaoPara(0), 0);
    expect(botao.posicaoPara(0.06), 5); // 4,8 voltas
    expect(botao.posicaoPara(0.10), 8);
    expect(botao.posicaoPara(0.15), 8); // não passa do mais pesado
    expect(botao.posicaoPara(-0.04), 0); // descida: mais leve
  });

  test('carga equivalente (1 a 10) para a estimativa dos watts', () {
    expect(botao.cargaEquivalente(0), 1);
    expect(botao.cargaEquivalente(8), 10);
    expect(botao.cargaEquivalente(4), 5.5);
    expect(botao.cargaEquivalente(12), 10); // fora da faixa: fica no limite
  });

  test('o que falar para girar o botão', () {
    expect(BotaoPeso.instrucao(0, 5), 'Gire o botão mais 5 voltas.');
    expect(BotaoPeso.instrucao(3, 4), 'Gire o botão mais uma volta.');
    expect(BotaoPeso.instrucao(5, 0), 'Volte o botão 5 voltas.');
    expect(BotaoPeso.instrucao(4, 2), 'Volte o botão duas voltas.');
    expect(BotaoPeso.instrucao(3, 3), isNull);
  });

  test('posição do botão que dá uma meta de watts num giro', () {
    const c = PowerCalibration(base: 0.6, factor: 0.25);
    // 180 W a 85 rpm = carga 6,07 → 4,5 voltas de 8 → 5
    expect(botao.posicaoParaWatts(180, 85, c), 5);
    expect(botao.posicaoParaWatts(60, 85, c), 0);
    expect(botao.posicaoParaWatts(900, 85, c), 8);
    expect(botao.posicaoParaWatts(180, 0, c), 0);
  });

  test('a estimativa usa a carga equivalente do botão', () {
    const c = PowerCalibration(base: 0.6, factor: 0.25);
    // volta 4 de 8 = carga 5,5 → 80 × (0,6 + 0,25 × 5,5) = 158 W
    expect(estimatePower(80, botao.cargaEquivalente(4), c), 158);
  });
}
