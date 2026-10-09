import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/core/voice.dart';

Map<String, String> voz(
  String nome, {
  String locale = 'pt-BR',
  String qualidade = 'normal',
  bool internet = false,
  String extras = '',
}) => {
  'name': nome,
  'locale': locale,
  'quality': qualidade,
  'latency': 'normal',
  'network_required': internet ? '1' : '0',
  'features': extras,
};

void main() {
  group('pronúncia', () {
    test('bike é falado “baique”, com maiúscula ou não', () {
      expect(
        paraFalar('A bike desconectou. Pedal pausado.'),
        'A baique desconectou. Pedal pausado.',
      );
      expect(paraFalar('Bike conectada'), 'Baique conectada');
      expect(paraFalar('Duas bikes'), 'Duas baiques');
    });

    test('FTP, sprint e watts ficam como se falam', () {
      expect(
        paraFalar('Seu FTP é de 180 watts.'),
        'Seu éfe tê pê é de 180 uóts.',
      );
      expect(paraFalar('Sprint! 15 segundos'), 'Esprínt! 15 segundos');
    });

    test('só a palavra inteira: “bikers” e “biker” não mudam', () {
      expect(paraFalar('bikers e biker'), 'bikers e biker');
      expect(
        paraFalar('Subida de 6 por cento chegando.'),
        'Subida de 6 por cento chegando.',
      );
    });
  });

  group('vozes em português', () {
    test('Google primeiro, sem internet antes, qualidade maior antes; só pt-BR instaladas', () {
      final opcoes = portugueseVoices({
        'com.samsung.SMT': [
          voz('pt-BR-SMTf00', qualidade: 'high'),
          voz('en-US-SMTf00', locale: 'en-US'),
        ],
        googleTtsEngine: [
          voz('pt-br-x-afs-network', qualidade: 'very high', internet: true),
          voz('pt-br-x-afs-local', qualidade: 'high'),
          voz('pt-br-x-ptd-local', qualidade: 'very high'),
          voz(
            'pt-br-x-pte-local',
            extras: 'legacySetLanguageVoice\tnotInstalled',
          ),
          voz('pt-pt-x-sfs-local', locale: 'pt-PT'),
        ],
      });
      expect(
        [for (final o in opcoes) o.name],
        [
          'pt-br-x-ptd-local',
          'pt-br-x-afs-local',
          'pt-br-x-afs-network',
          'pt-BR-SMTf00',
        ],
      );
      expect(
        [for (final o in opcoes) o.label],
        [
          'Google · voz 1',
          'Google · voz 2',
          'Google · voz 3 (com internet)',
          'Samsung · voz 1',
        ],
      );
      expect(opcoes.first.id, '$googleTtsEngine|pt-br-x-ptd-local|pt-BR');
    });

    test('a escolha guardada vira motor, nome e idioma de novo', () {
      final o = parseVoiceId('$googleTtsEngine|pt-br-x-ptd-local|pt-BR');
      expect(o, (
        engine: googleTtsEngine,
        name: 'pt-br-x-ptd-local',
        locale: 'pt-BR',
      ));
      expect(parseVoiceId('quebrado'), isNull);
      expect(parseVoiceId(null), isNull);
    });
  });
}
