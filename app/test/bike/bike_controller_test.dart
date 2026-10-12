import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/bike/ftms_source.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/settings_store.dart';

import '../support/fakes.dart';

void main() {
  late FakeBikeSource fake;
  late MemorySettingsStore settings;
  late ProviderContainer container;

  setUp(() {
    fake = FakeBikeSource(name: 'FS-1234');
    settings = MemorySettingsStore();
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      ftmsFactoryProvider.overrideWithValue((id, name) => fake),
      reconnectDelaysProvider.overrideWithValue(const [Duration.zero, Duration.zero, Duration.zero]),
    ]);
    addTearDown(container.dispose);
  });

  BikeController ctrl() => container.read(bikeControllerProvider.notifier);
  BikeState estado() => container.read(bikeControllerProvider);

  test('useDevice conecta e lembra a bike', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    expect(estado().connected, isTrue);
    expect(estado().source!.name, 'FS-1234');
    final s = await settings.load();
    expect(s.ultimaBikeId, 'AA:BB');
    expect(s.ultimaBikeNome, 'FS-1234');
  });

  test('reconnectLast usa a bike salva', () async {
    await settings.save(const AppSettings(ultimaBikeId: 'AA:BB', ultimaBikeNome: 'FS-1234'));
    await ctrl().reconnectLast();
    expect(estado().connected, isTrue);
    expect(fake.connectCalls, 1);
  });

  test('sem FTMS: mostra o diagnóstico e não fica conectada', () async {
    fake.failWith = const NoFtmsException('Aparelho: X\nServiços:\n  fff0');
    await ctrl().useDevice('AA:BB', 'X');
    expect(estado().connected, isFalse);
    expect(estado().source, isNull);
    expect(estado().diagnostic, contains('fff0'));
    expect(estado().message, contains('FTMS'));
    expect(fake.disposed, isTrue);
  });

  test('bike desligada (erro 133 do Android): explica que é só pedalar para acordar', () async {
    fake.failWith = Exception('UniversalBleException: Code: UniversalBleErrorCode.unknownError, Message: Unknown Error 133');
    await ctrl().useDevice('AA:BB', 'WINNEK BT-151');
    expect(estado().connected, isFalse);
    expect(estado().message, contains('pedale'));
    expect(estado().message, isNot(contains('133')));
  });

  test('tocar de novo enquanto a primeira conexão demora: a falha dela não apaga a nova', () async {
    fake.hold = Completer<void>();
    fake.failWith = Exception('Unknown Error 133');
    final primeira = ctrl().useDevice('AA:BB', 'WINNEK BT-151');
    await settle();
    await ctrl().useSimulated();
    fake.hold!.complete();
    await primeira;
    expect(estado().connected, isTrue);
    expect(estado().source!.simulated, isTrue);
    expect(estado().message, isNull);
  });

  test('queda: reconecta sozinho', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    fake.failNext = 1;
    fake.emitConnection(BikeConnection.caiu);
    await settle();
    expect(fake.connectCalls, 3); // conexão inicial + 1 falha + 1 sucesso
    expect(estado().connection, BikeConnection.conectada);
  });

  test('queda: desiste depois de 3 tentativas', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    fake.failNext = 99;
    fake.emitConnection(BikeConnection.caiu);
    await settle();
    expect(fake.connectCalls, 4);
    expect(estado().connected, isFalse);
    expect(estado().message, contains('Reconectar'));
  });

  test('com um pedal aberto, não desiste: tenta até a bike acordar', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    ctrl().manterConectada(true);
    fake.failNext = 6; // a bike dormiu: mais falhas do que as 3 esperas
    fake.emitConnection(BikeConnection.caiu);
    await settle();
    expect(fake.connectCalls, 8); // conexão inicial + 6 falhas + 1 sucesso
    expect(estado().connection, BikeConnection.conectada);
  });

  test('erros em português simples, sem o texto técnico', () async {
    fake.failWith = Exception('PlatformException(sem conexão)');
    await ctrl().useDevice('AA:BB', 'FS-1234');
    expect(estado().message, isNot(contains('Exception')));
    fake = FakeBikeSource(name: 'FS-1234'); // a primeira foi descartada na falha
    await ctrl().useDevice('AA:BB', 'FS-1234');
    fake.failWith = Exception('PlatformException(sem conexão)');
    await ctrl().reconnectNow();
    expect(estado().message, startsWith('Não reconectou'));
    expect(estado().message, isNot(contains('Exception')));
  });

  test('bike simulada', () async {
    await ctrl().useSimulated();
    expect(estado().connected, isTrue);
    expect(estado().source!.simulated, isTrue);
    await ctrl().disconnect();
    expect(estado().source, isNull);
  });
}
