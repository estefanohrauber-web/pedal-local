import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/core/widgets/pedalaqui_logo.dart';

double _comprimento(Path p) =>
    p.computeMetrics().fold(0.0, (soma, m) => soma + m.length);

void main() {
  test('a rota da logo cabe no quadro de 200 e o pino fica no alto da segunda colina', () {
    final b = logoRoute().getBounds();
    expect(b.left, greaterThanOrEqualTo(0));
    expect(b.right, lessThanOrEqualTo(200));
    expect(b.top, closeTo(36, 1)); // topo da cabeça do pino (58 − 22)
    expect(b.bottom, closeTo(150, 1));
    expect(logoPinCenter.dx, closeTo(b.left + 128, 1));
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
            PedalaquiWordmark(fontSize: 32, pin: 0.5),
          ],
        ),
      ),
    );
    expect(find.byType(PedalaquiMark), findsNWidgets(2)); // o ícone usa o símbolo
    expect(find.textContaining('Pedal', findRichText: true), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
