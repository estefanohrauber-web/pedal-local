import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/botao_peso.dart';
import 'package:pedal_local/domain/guia_botao.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

/// Relevo com um ponto a cada 20 m.
RouteProfile relevo(List<double> alts) => RouteProfile(northProfile(alts));

/// Altitudes a cada 20 m: [plano] metros planos e depois cada trecho (metros, inclinação).
List<double> trechos(double plano, List<(double, double)> resto) {
  final alts = [for (var d = 0.0; d <= plano + 1e-9; d += 20) 100.0];
  for (final (metros, rampa) in resto) {
    for (var d = 20.0; d <= metros + 1e-9; d += 20) {
      alts.add(alts.last + 20 * rampa);
    }
  }
  return alts;
}

class Mudanca {
  Mudanca(this.d, this.de, this.para, this.frase);
  final double d;
  final int de;
  final int para;
  final String frase;
  @override
  String toString() => '$d m: $de → $para ($frase)';
}

/// Pedala o relevo de 5 em 5 m seguindo o guia, sem os avisos de subida e descida.
List<Mudanca> pedalar(GuiaBotao guia, RouteProfile r, {void Function(double d, int posicao)? cada}) {
  var posicao = 0;
  final mudancas = <Mudanca>[];
  for (var d = 0.0; d <= r.distance; d += 5) {
    final m = guia.passo(r, d, posicao);
    if (m != null) {
      mudancas.add(Mudanca(d, posicao, m.posicao, m.frase));
      posicao = m.posicao;
    }
    cada?.call(d, posicao);
  }
  return mudancas;
}

void main() {
  const botao = BotaoPeso(13); // a Winnek: 13 voltas, dá para pedalar até a 9

  group('posição para o relevo', () {
    test('no plano, um quarto do limite; na subida, nunca abaixo disso', () {
      expect(botao.plano, 2);
      expect(botao.posicaoNoRelevo(0), 2);
      expect(botao.posicaoNoRelevo(0.015), 2);
      expect(botao.posicaoNoRelevo(0.03), 3);
      expect(botao.posicaoNoRelevo(0.05), 5);
      expect(botao.posicaoNoRelevo(0.08), 7);
      expect(botao.posicaoNoRelevo(0.10), 9);
      expect(botao.posicaoNoRelevo(0.15), 9);
    });

    test('descida de 1,5 % ou mais: o mais leve; mais suave que isso, é plano', () {
      expect(botao.posicaoNoRelevo(-0.01), 2);
      expect(botao.posicaoNoRelevo(-0.015), 0);
      expect(botao.posicaoNoRelevo(-0.08), 0);
    });

    test('botão curto: o plano pode ser o mais leve', () {
      expect(const BotaoPeso(2).plano, 0); // limite 1
      expect(const BotaoPeso(2).posicaoNoRelevo(0), 0);
    });
  });

  group('guia do botão', () {
    test('plano: aquece 150 m no mais leve, pede o peso do plano uma vez e não fala mais', () {
      final mudancas = pedalar(GuiaBotao(botao), relevo(trechos(1000, [])));
      expect(mudancas, hasLength(1));
      expect(mudancas.single.d, 150);
      expect(mudancas.single.para, 2);
      expect(mudancas.single.frase, 'Trecho plano: gire o botão mais duas voltas.');
    });

    test('subida suave, sem aviso: pesa uma volta perto da subida', () {
      final mudancas = pedalar(GuiaBotao(botao), relevo(trechos(600, [(600, 0.03)])));
      expect(mudancas.map((m) => m.para), [2, 3]);
      expect(mudancas.last.frase, 'Subida de 3 por cento: gire o botão mais uma volta.');
      expect(mudancas.last.d, inInclusiveRange(450, 620)); // a subida começa nos 600 m
    });

    test('topo: segura o peso até o topo e só alivia na descida', () {
      // 200 m planos, 400 m a 6 % e 400 m descendo a 5 %: o topo fica nos 600 m.
      final mudancas = pedalar(GuiaBotao(botao), relevo(trechos(200, [(400, 0.06), (400, -0.05)])), cada: (d, p) {
        if (d >= 400 && d < 600) expect(p, 5, reason: 'aos $d m, ainda subindo');
      });
      final alivio = mudancas.firstWhere((m) => m.para < m.de);
      expect(alivio.d, inInclusiveRange(600, 660));
      expect(alivio.para, 0);
      expect(alivio.frase, 'Descida: volte o botão 5 voltas.');
    });

    test('relevo ondulado: muda mais vezes, mas nunca com menos de 150 m entre uma fala e outra', () {
      final alts = [for (var i = 0; i < 200; i++) 100 + 6 * math.sin(i * 20 / 300 * 2 * math.pi)];
      final mudancas = pedalar(GuiaBotao(botao), relevo(alts));
      expect(mudancas.map((m) => m.para).toSet().length, greaterThanOrEqualTo(3));
      for (var i = 1; i < mudancas.length; i++) {
        expect(mudancas[i].d - mudancas[i - 1].d, greaterThanOrEqualTo(botaoIntervaloM), reason: '$mudancas');
      }
    });

    test('vai e volta de uma volta só (plano, 3 %, plano, 3 %…): não fica trocando', () {
      final mudancas = pedalar(
        GuiaBotao(botao),
        relevo(trechos(300, [(300, 0.03), (300, 0), (300, 0.03), (300, 0), (300, 0.03)])),
      );
      expect(mudancas.map((m) => m.para), [2, 3]);
    });

    test('com um aviso chegando, espera o aviso cuidar do botão', () {
      final guia = GuiaBotao(botao);
      final r = relevo(trechos(1000, []));
      for (var d = 0.0; d <= 400; d += 5) {
        expect(guia.passo(r, d, 0, avisoChegando: true), isNull);
      }
    });
  });

  group('no aviso', () {
    final r = relevo(trechos(200, [(400, 0.06), (400, -0.05)]));

    test('subida: pesa para a rampa mais forte, a qualquer hora', () {
      final guia = GuiaBotao(botao);
      expect(guia.noAviso(r, 140, 2, const RideAlert(AlertKind.subida, 0.06, 0.06)), 5);
      expect(guia.noAviso(r, 140, 5, const RideAlert(AlertKind.subida, 0.06, 0.06)), isNull);
    });

    test('descida antes do topo: não alivia ainda; depois do topo, alivia', () {
      final guia = GuiaBotao(botao);
      const descida = RideAlert(AlertKind.descida, -0.05, -0.05);
      expect(guia.noAviso(r, 560, 5, descida), isNull);
      expect(guia.noAviso(r, 650, 5, descida), 0);
    });

    test('a mudança no aviso conta para o intervalo das falas seguintes', () {
      final guia = GuiaBotao(botao);
      final plano = relevo(trechos(2000, []));
      expect(guia.noAviso(plano, 500, 0, const RideAlert(AlertKind.subida, 0.04, 0.04)), 4);
      expect(guia.passo(plano, 640, 4), isNull);
      expect(guia.passo(plano, 700, 4)?.posicao, 2);
    });
  });
}
