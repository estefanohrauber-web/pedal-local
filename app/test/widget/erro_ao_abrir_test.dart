import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/main.dart';

void main() {
  testWidgets(
    'banco que não abre: explica, mostra o detalhe e deixa tentar de novo',
    (tester) async {
      var tentou = 0;
      await tester.pumpWidget(
        ErroAoAbrir(erro: 'disk I/O error', tentarDeNovo: () => tentou++),
      );
      expect(find.text('Não consegui abrir seus dados'), findsOneWidget);
      expect(
        find.textContaining('continuam guardados no celular'),
        findsOneWidget,
      );
      expect(find.textContaining('disk I/O error'), findsOneWidget);
      await tester.tap(find.text('Tentar de novo'));
      expect(tentou, 1);
    },
  );
}
