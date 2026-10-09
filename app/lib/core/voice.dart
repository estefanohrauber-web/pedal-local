import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Fala os avisos do pedal.
abstract interface class Voice {
  Future<void> speak(String text);
  Future<void> stop();

  /// As vozes em português do Brasil que o celular tem, a mais natural primeiro.
  Future<List<VoiceOption>> options();

  /// Usa esta voz nos próximos avisos ([VoiceOption.id]; null = a automática).
  Future<void> choose(String? id);
}

/// Motor de voz do Google: as vozes dele em português soam bem mais naturais que as de fábrica.
const googleTtsEngine = 'com.google.android.tts';

/// Uma voz do celular.
class VoiceOption {
  const VoiceOption({required this.engine, required this.name, required this.locale, required this.label, this.network = false});

  final String engine;
  final String name;
  final String locale;

  /// Como aparece nos Ajustes (“Google · voz 1”).
  final String label;

  /// Precisa de internet para falar.
  final bool network;

  String get id => '$engine|$name|$locale';
}

/// Motor, nome e idioma de uma voz guardada nos ajustes ([VoiceOption.id]).
({String engine, String name, String locale})? parseVoiceId(String? id) {
  final partes = id?.split('|');
  if (partes == null || partes.length != 3) return null;
  return (engine: partes[0], name: partes[1], locale: partes[2]);
}

String _nomeDoMotor(String engine) => switch (engine) {
      googleTtsEngine => 'Google',
      'com.samsung.SMT' => 'Samsung',
      _ => 'Do celular',
    };

const _qualidade = {'very high': 5, 'high': 4, 'normal': 3, 'low': 2, 'very low': 1};

/// As vozes em português do Brasil instaladas em cada motor, a mais natural primeiro: as do
/// Google antes, as que falam sem internet antes, as de qualidade maior antes.
List<VoiceOption> portugueseVoices(Map<String, List<Map<String, String>>> porMotor) {
  final motores = porMotor.keys.toList()..sort((a, b) => (a == googleTtsEngine ? 0 : 1).compareTo(b == googleTtsEngine ? 0 : 1));
  final out = <VoiceOption>[];
  for (final motor in motores) {
    final vozes = [
      for (final v in porMotor[motor]!)
        if ((v['locale'] ?? '').replaceAll('_', '-').toLowerCase() == 'pt-br' && !(v['features'] ?? '').contains('notInstalled')) v,
    ];
    bool internet(Map<String, String> v) => v['network_required'] == '1';
    vozes.sort((a, b) {
      final rede = (internet(a) ? 1 : 0).compareTo(internet(b) ? 1 : 0);
      if (rede != 0) return rede;
      return (_qualidade[b['quality']] ?? 0).compareTo(_qualidade[a['quality']] ?? 0);
    });
    for (var i = 0; i < vozes.length; i++) {
      final v = vozes[i];
      out.add(VoiceOption(
        engine: motor,
        name: v['name']!,
        locale: v['locale']!,
        network: internet(v),
        label: '${_nomeDoMotor(motor)} · voz ${i + 1}${internet(v) ? ' (com internet)' : ''}',
      ));
    }
  }
  return out;
}

/// Palavras que a voz em português lê errado (“bike” sai “bique”): escritas como se falam.
const _pronuncia = {
  'bikes': 'baiques',
  'bike': 'baique',
  'ftp': 'éfe tê pê',
  'sprints': 'esprínts',
  'sprint': 'esprínt',
  'watts': 'uóts',
};

final _palavras = RegExp('\\b(${_pronuncia.keys.join('|')})\\b', caseSensitive: false);

/// O texto como a voz deve ler; a tela continua mostrando o original.
String paraFalar(String texto) => texto.replaceAllMapped(_palavras, (m) {
      final palavra = m[0]!;
      final troca = _pronuncia[palavra.toLowerCase()]!;
      // “Bike” no começo da frase vira “Baique”; sigla toda em maiúsculas (FTP) não.
      final resto = palavra.substring(1);
      final maiuscula = palavra[0] != palavra[0].toLowerCase() && resto != resto.toUpperCase();
      return maiuscula ? '${troca[0].toUpperCase()}${troca.substring(1)}' : troca;
    });

/// A voz do próprio celular (o leitor de texto do Android), em português do Brasil.
/// Sem escolha, usa o motor do Google quando ele tem português (mais natural que o de
/// fábrica). Abaixa a música enquanto fala. Se o celular não tiver voz, o pedal segue sem ela.
class TtsVoice implements Voice {
  Future<FlutterTts>? _motor;
  String? _escolha;

  Future<FlutterTts> _pronto() => _motor ??= _iniciar();

  Future<FlutterTts> _iniciar() async {
    final tts = FlutterTts();
    final escolha = parseVoiceId(_escolha);
    final motores = ((await tts.getEngines) as List?)?.cast<String>() ?? const <String>[];
    final motor = escolha?.engine ?? (motores.contains(googleTtsEngine) ? googleTtsEngine : null);
    if (motor != null && motores.contains(motor)) await tts.setEngine(motor);
    var temPortugues = await tts.setLanguage('pt-BR') == 1;
    if (!temPortugues && motor != null) {
      // Esse motor não tem português instalado: volta para o padrão do celular.
      final padrao = await tts.getDefaultEngine;
      if (padrao is String) await tts.setEngine(padrao);
      temPortugues = await tts.setLanguage('pt-BR') == 1;
    } else if (escolha != null) {
      await tts.setVoice({'name': escolha.name, 'locale': escolha.locale});
    }
    await tts.setSpeechRate(0.5);
    await tts.setQueueMode(1); // um aviso espera o anterior terminar
    await tts.awaitSpeakCompletion(false);
    return tts;
  }

  @override
  Future<void> speak(String text) async {
    try {
      await (await _pronto()).speak(paraFalar(text), focus: true);
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

  @override
  Future<List<VoiceOption>> options() async {
    try {
      final tts = await _pronto();
      final motores = ((await tts.getEngines) as List?)?.cast<String>() ?? const <String>[];
      final porMotor = <String, List<Map<String, String>>>{};
      for (final m in motores) {
        await tts.setEngine(m);
        final vozes = (await tts.getVoices) as List? ?? const [];
        porMotor[m] = [
          for (final v in vozes) {for (final e in (v as Map).entries) '${e.key}': '${e.value}'},
        ];
      }
      _motor = null; // a próxima fala volta para a voz escolhida
      return portugueseVoices(porMotor);
    } catch (e) {
      debugPrint('Sem lista de vozes: $e');
      return const [];
    }
  }

  @override
  Future<void> choose(String? id) async {
    if (id == _escolha && _motor != null) return;
    _escolha = id;
    _motor = null;
  }
}

final voiceProvider = Provider<Voice>((ref) => TtsVoice());
