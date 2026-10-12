import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/botao_peso.dart';
import 'package:pedal_local/domain/power.dart';

void main() {
  const botao = BotaoPeso(8);

  test('posição do botão numa subida: 10% pede tudo o que dá para pedalar', () {
    const b = BotaoPeso(13, limiteMedido: 9);
    expect(b.posicaoPara(0), 0);
    expect(b.posicaoPara(0.041), 4); // a ponte do Entre pontes (antes pedia 8 voltas)
    expect(b.posicaoPara(0.054), 5);
    expect(b.posicaoPara(0.10), 9);
    expect(b.posicaoPara(0.15), 9); // não passa do que dá para pedalar
    expect(b.posicaoPara(-0.04), 0); // descida: mais leve
  });

  test('sem o limite medido, supõe que dá para pedalar até 70% das voltas', () {
    expect(const BotaoPeso(13).limite, 9);
    expect(botao.limite, 6);
    expect(const BotaoPeso(1).limite, 1);
    expect(const BotaoPeso(8, limiteMedido: 20).limite, 8);
    expect(const BotaoPeso(8, limiteMedido: 0).limite, 1);
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
