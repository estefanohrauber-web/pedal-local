import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Fala os avisos do pedal.
abstract interface class Voice {
  Future<void> speak(String text);
  Future<void> stop();
}

/// A voz do próprio celular (o leitor de texto do Android), em português do Brasil.
/// Abaixa a música enquanto fala. Se o celular não tiver voz, o pedal segue sem ela.
class TtsVoice implements Voice {
  Future<FlutterTts>? _motor;

  Future<FlutterTts> _pronto() => _motor ??= () async {
        final tts = FlutterTts();
        await tts.setLanguage('pt-BR');
        await tts.setSpeechRate(0.5);
        await tts.setQueueMode(1); // um aviso espera o anterior terminar
        await tts.awaitSpeakCompletion(false);
        return tts;
      }();

  @override
  Future<void> speak(String text) async {
    try {
      await (await _pronto()).speak(text, focus: true);
    } catch (e) {
      debugPrint('Voz indisponível: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await (await _pronto()).stop();
    } catch (_) {}
  }
}

final voiceProvider = Provider<Voice>((ref) => TtsVoice());
