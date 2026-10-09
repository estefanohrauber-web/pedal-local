// Gera os ícones em imagem a partir do desenho da logo (lib/core/widgets/pedalaqui_logo.dart):
// os do Android 7 (que não tem ícone adaptável) e os da marca, em docs/marca.
// Rodar de novo quando a logo mudar: flutter test tool/gerar_icones_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/core/widgets/pedalaqui_logo.dart';

Future<void> _salvar(
  WidgetTester tester,
  String caminho,
  int lado, {
  bool rounded = true,
  double markFraction = 0.83,
}) async {
  final gravador = ui.PictureRecorder();
  paintAppIcon(
    ui.Canvas(gravador),
    lado.toDouble(),
    rounded: rounded,
    markFraction: markFraction,
  );
  final imagem = await tester.runAsync(
    () => gravador.endRecording().toImage(lado, lado),
  );
  final png = await tester.runAsync(
    () => imagem!.toByteData(format: ui.ImageByteFormat.png),
  );
  File(caminho)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('gera os ícones', (tester) async {
    const mipmaps = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final MapEntry(key: pasta, value: lado) in mipmaps.entries) {
      await _salvar(
        tester,
        'android/app/src/main/res/mipmap-$pasta/ic_launcher.png',
        lado,
      );
    }
    // Loja (Google Play): quadrado inteiro, a loja arredonda os cantos.
    await _salvar(
      tester,
      '../docs/marca/pedalaqui-icone-loja-512.png',
      512,
      rounded: false,
      markFraction: 0.72,
    );
    await _salvar(tester, '../docs/marca/pedalaqui-icone-1024.png', 1024);
  });
}
