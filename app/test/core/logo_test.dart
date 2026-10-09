import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/core/widgets/pedalaqui_logo.dart';

double _comprimento(Path p) =>
    p.computeMetrics().fold(0.0, (soma, m) => soma + m.length);

void main() {
  test('a rota da logo cabe no quadro de 200 e o pino fica no alto da segunda colina', () {
    // A caixa de verdade, seguindo o traço (getBounds conta os pontos de controle das curvas).
    final m = logoRoute().computeMetrics().first;
    final pontos = [for (var d = 0.0; d <= m.length; d += 0.5) m.getTangentForOffset(d)!.position];
    final b = Rect.fromLTRB(
      pontos.map((p) => p.dx).reduce(math.min),
      pontos.map((p) => p.dy).reduce(math.min),
      pontos.map((p) => p.dx).reduce(math.max),
      pontos.map((p) => p.dy).reduce(math.max),
    );
    expect(b.left, greaterThanOrEqualTo(0));
    expect(b.right, lessThanOrEqualTo(200));
    expect(b.top, closeTo(36, 1)); // topo da cabeça do pino (58 − 22)
    expect(b.bottom, closeTo(150, 1));
    expect(logoPinCenter.dx, closeTo(b.left + 128, 1));
  });

  test('no cruzamento embaixo do pino as duas linhas passam retas, num X simétrico', () {
    final m = logoRoute().computeMetrics().first;
    const ponta = Offset(136, 96);
    final passagens = <double>[];
    for (var s = 0.0; s <= m.length; s += 0.25) {
      final perto = (m.getTangentForOffset(s)!.position - ponta).distance < 0.2;
      if (perto && (passagens.isEmpty || s - passagens.last > 20)) passagens.add(s);
    }
    expect(passagens.length, 2); // passa pela ponta do pino duas vezes
    for (final s in passagens) {
      final antes = m.getTangentForOffset(s - 14)!.vector;
      final depois = m.getTangentForOffset(s + 14)!.vector;
      expect((antes.direction - depois.direction).abs(), lessThan(0.01)); // reta
    }
    final subida = m.getTangentForOffset(passagens[0])!.vector;
    final descida = m.getTangentForOffset(passagens[1])!.vector;
    expect(subida.dx, closeTo(descida.dx, 0.01)); // espelhadas: sobe para a direita…
    expect(subida.dy, closeTo(-descida.dy, 0.01)); // …e desce para a direita
  });

  test('desenho parcial: metade do caminho tem metade do comprimento', () {
    final total = _comprimento(logoRoute());
    expect(_comprimento(partialPath(logoRoute(), 0)), 0);
    expect(_comprimento(partialPath(logoRoute(), 0.5)), closeTo(total / 2, 1));
    expect(_comprimento(partialPath(logoRoute(), 1)), closeTo(total, 0.5));
  });

  test('o nome se revela junto com a ponta da linha e espera no laço do pino', () {
    expect(logoRevealFraction(0), 0);
    expect(logoRevealFraction(1), 1);
    final valores = [for (var i = 0; i <= 50; i++) logoRevealFraction(i / 50)];
    for (var i = 1; i < valores.length; i++) {
      expect(valores[i], greaterThanOrEqualTo(valores[i - 1])); // nunca volta
    }
    // No laço do pino a linha volta para a esquerda: o nome para por um tempo.
    var parado = 0;
    for (var i = 1; i < valores.length; i++) {
      if ((valores[i] - valores[i - 1]).abs() < 1e-9) parado++;
    }
    expect(parado, greaterThan(2));
  });

  testWidgets('símbolo, ícone e nome escrito aparecem sem erro', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            PedalaquiMark(size: 120),
            PedalaquiIcon(size: 64),
            PedalaquiWordmark(fontSize: 32),
          ],
        ),
      ),
    );
    expect(find.byType(PedalaquiMark), findsNWidgets(2)); // o ícone usa o símbolo
    expect(find.text('Pedalaqui', findRichText: true), findsOneWidget); // o i com o pingo normal
    expect(tester.takeException(), isNull);
  });
}
