import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/core/router/app_router.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/custom_workouts_store.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/power.dart';

import '../support/fakes.dart';

/// Os watts da Winnek: uma tabela do giro (o botão não entra).
int wattsDaWinnek(double rpm) => (rpm * 2.48).round();

void main() {
  late MemorySettingsStore ajustes;
  late FakeVoice voz;
  late ProviderContainer container;

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2070);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    ajustes = MemorySettingsStore();
    voz = FakeVoice();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(ajustes),
          ridesStoreProvider.overrideWithValue(MemoryRidesStore()),
          routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
          customWorkoutsStoreProvider.overrideWithValue(MemoryCustomWorkoutsStore()),
          wakeLockProvider.overrideWithValue(FakeWakeLock()),
          voiceProvider.overrideWithValue(voz),
          mapTilesEnabledProvider.overrideWithValue(false),
        ],
        child: const PedalLocalApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
  }

  testWidgets('a voz guia: conta as voltas, mede o giro e vê que a bike não sente o botão', (tester) async {
    await abrir(tester);
    final bike = FakeBikeSource(name: 'WINNEK BT-151');
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    container.read(appRouterProvider).push('/bike/botao');
    await tester.pumpAndSettle();

    expect(find.text('Ensine o botão ao app'), findsOneWidget);
    expect(find.textContaining('A bike não está conectada'), findsNothing);
    await tester.tap(find.text('Começar'));
    await tester.pump();
    expect(voz.spoken.last, 'Pedale no mais leve, num giro perto de 60.');

    // Mantém 60 rpm até a volta 3; da 4 em diante não aguenta (45 rpm).
    var volta = 0;
    Future<void> pedalar(int segundos) async {
      for (var s = 0; s < segundos * 2; s++) {
        final giro = volta <= 3 ? 60.0 : 45.0;
        bike.emitReading(BikeReading(cadence: giro, power: wattsDaWinnek(giro), timestamp: DateTime(2026)));
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    await pedalar(15);
    expect(voz.spoken.last, 'Gire mais uma volta.');
    expect(find.textContaining('Volta 1'), findsOneWidget);
    for (volta = 1; volta <= 4; volta++) {
      await pedalar(10);
    }
    expect(find.textContaining('Volta 5'), findsOneWidget); // a voz pediu a volta 5 e o botão travou
    await tester.tap(find.text('O botão não gira mais'));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('Você manteve 60 rpm até a volta 3'), findsOneWidget);
    expect(find.textContaining('Os watts não mudaram com o botão'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final salvo = await ajustes.load();
    expect(salvo.voltasBotao, 4);
    expect(salvo.limiteBotao, 3);
    expect(salvo.modoPotencia, PowerMode.auto);
    expect(find.text('Calibrar o botão'), findsNothing);
  });

  testWidgets('sem a bike: só conta; desfazer e corrigir o total', (tester) async {
    await abrir(tester);
    await ajustes.save(const AppSettings(voltasBotao: 13, limiteBotao: 9));
    container.invalidate(settingsProvider);
    container.read(appRouterProvider).push('/bike/botao');
    await tester.pumpAndSettle();

    expect(find.textContaining('A bike não está conectada'), findsOneWidget);
    expect(find.textContaining('Da última vez foram 13 voltas'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pump(const Duration(seconds: 15));
    expect(voz.spoken.last, 'Gire mais uma volta.');
    await tester.tap(find.text('Desfazer uma volta'));
    await tester.pump();
    expect(find.textContaining('No mais leve'), findsOneWidget);
    expect(find.text('sem a bike, só contando'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15)); // volta 1
    await tester.pump(const Duration(seconds: 10)); // volta 2: travou
    await tester.tap(find.text('O botão não gira mais'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem o giro da bike'), findsOneWidget);
    await tester.tap(find.byTooltip('Uma volta a mais'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final salvo = await ajustes.load();
    expect(salvo.voltasBotao, 2);
    expect(salvo.limiteBotao, isNull); // a medida antiga não vale para o botão recontado
  });
}
