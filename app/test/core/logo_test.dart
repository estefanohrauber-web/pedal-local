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

  testWidgets('símbolo, ícone e nome escrito aparecem sem erro', (
    tester,
  ) async {
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
    expect(
      find.byType(PedalaquiMark),
      findsNWidgets(2),
    ); // o ícone usa o símbolo
    expect(find.textContaining('Pedal', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
