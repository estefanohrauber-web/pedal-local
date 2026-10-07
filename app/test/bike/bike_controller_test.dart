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

  test('bike simulada', () async {
    await ctrl().useSimulated();
    expect(estado().connected, isTrue);
    expect(estado().source!.simulated, isTrue);
    await ctrl().disconnect();
    expect(estado().source, isNull);
  });
}
