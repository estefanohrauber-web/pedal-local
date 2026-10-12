import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A miniatura do pedal: a janela flutuante do Android (picture-in-picture) que fica por cima
/// de outros apps quando a pessoa sai do app pedalando. O estado diz se está nela agora.
class Miniatura extends Notifier<bool> {
  static const _canal = MethodChannel('pedalaqui/miniatura');

  @override
  bool build() {
    _canal.setMethodCallHandler((chamada) async {
      if (chamada.method == 'mudou') state = chamada.arguments == true;
    });
    return false;
  }

  /// Ao sair do app, vira miniatura ([sim]) ou fica como sempre.
  Future<void> permitir(bool sim) async {
    try {
      await _canal.invokeMethod<void>('permitir', sim);
    } on MissingPluginException {
      // Fora do Android (testes): não há miniatura.
    } on PlatformException {
      // Celular sem suporte: o pedal segue sem a miniatura.
    }
  }
}

final miniaturaProvider = NotifierProvider<Miniatura, bool>(Miniatura.new);
