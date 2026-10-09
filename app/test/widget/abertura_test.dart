import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_log.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/core/widgets/pedalaqui_logo.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/features/abertura/abertura.dart';

import '../support/fakes.dart';

Future<void> _abrirApp(WidgetTester tester, {bool doAndroid = false}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        ridesStoreProvider.overrideWithValue(MemoryRidesStore()),
        routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
        wakeLockProvider.overrideWithValue(FakeWakeLock()),
        voiceProvider.overrideWithValue(FakeVoice()),
        mapTilesEnabledProvider.overrideWithValue(false),
        locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
        bikeLogProvider.overrideWithValue(BikeLog()),
        aberturaDoAndroidProvider.overrideWithValue(doAndroid),
      ],
      child: const PedalLocalApp(),
    ),
  );
}

/// A tela de carregamento do Android passa a abertura, como na MainActivity, no ponto [decorrido]
/// (ms) da animação; [inicio] é o começo dela no relógio dos quadros (o padrão bate com ele).
/// Devolve a resposta do app quando ela chegar.
List<Object?> _entregar(WidgetTester tester, {required double decorrido, double? inicio}) {
  const codec = StandardMethodCodec();
  final agora = tester.binding.currentSystemFrameTimeStamp.inMicroseconds / 1000;
  final respostas = <Object?>[];
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    aberturaCanal.name,
    codec.encodeMethodCall(
      MethodCall('abrir', {'decorrido': decorrido, 'inicio': inicio ?? agora - decorrido}),
    ),
    (data) => respostas.add(codec.decodeEnvelope(data!)),
  );
  return respostas;
}

PedalaquiMark _marca(WidgetTester t) => t.widget<PedalaquiMark>(find.byType(PedalaquiMark));
PedalaquiWordmark _nome(WidgetTester t) => t.widget<PedalaquiWordmark>(find.byType(PedalaquiWordmark));
RevealMask _revela(WidgetTester t) => t.widget<RevealMask>(find.byType(RevealMask));

void main() {
  testWidgets('abertura: a rota se desenha; depois a bolinha com o anel, o nome e o pininho; a bolinha abre o app', (tester) async {
    await _abrirApp(tester);
    await tester.pump();
    expect(find.byKey(aberturaKey), findsOneWidget);
    expect(_marca(tester).progress, lessThan(0.05)); // a linha começa do zero
    expect(_revela(tester).fraction, 0); // o nome só depois da linha

    await tester.pump(const Duration(milliseconds: 400)); // no meio do caminho
    expect(_marca(tester).progress, inExclusiveRange(0.2, 0.9));
    expect(_marca(tester).dot, 0);
    expect(_revela(tester).fraction, 0);
    expect(find.text('Bora pedalar?'), findsNothing); // o app por baixo ainda não foi montado

    await tester.pump(const Duration(milliseconds: 550)); // 0,95 s: linha pronta, bolinha e nome chegando
    expect(_marca(tester).progress, 1);
    expect(_marca(tester).dot, greaterThan(0));
    expect(_marca(tester).ring, inExclusiveRange(0, 1)); // o anel se espalhando
    expect(_revela(tester).fraction, greaterThan(0.3));

    await tester.pump(const Duration(milliseconds: 650)); // 1,6 s: logo completa, parada
    expect(_marca(tester).dot, closeTo(1, 0.01));
    expect(_marca(tester).ring, 0);
    expect(_nome(tester).pin, closeTo(1, 0.01));
    expect(_revela(tester).fraction, 1);
    expect(find.text('Bora pedalar?'), findsOneWidget); // o app já está pronto por baixo

    await tester.pump(const Duration(milliseconds: 600)); // 2,2 s: nenhum anel novo
    expect(_marca(tester).ring, 0);

    await tester.pumpAndSettle();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('abertura: assume do ponto em que a tela de carregamento do Android estava', (tester) async {
    await _abrirApp(tester, doAndroid: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_marca(tester).progress, 0); // esperando o Android (que está por cima)
    expect(_revela(tester).fraction, 0);

    // O app demorou: a animação do Android já tinha a bolinha e soltava o segundo anel.
    final resposta = _entregar(tester, decorrido: 2300);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_marca(tester).progress, 1);
    expect(_marca(tester).dot, closeTo(1, 0.01));
    expect(_marca(tester).ring, inExclusiveRange(0.3, 0.8)); // o anel no mesmo ponto
    expect(resposta, isEmpty); // responde só depois de dois quadros desenhados assim
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(resposta, [true]);
    expect(_revela(tester).fraction, lessThan(0.2)); // só então o nome começa

    await tester.pump(const Duration(milliseconds: 700));
    expect(_revela(tester).fraction, 1);
    expect(_nome(tester).pin, closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 300)); // 3,35 s: sem um terceiro anel
    expect(_marca(tester).ring, 0);

    await tester.pumpAndSettle();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('abertura: o app travado ao começar (versão de teste) não faz desistir do aviso', (tester) async {
    await _abrirApp(tester, doAndroid: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300)); // um quadro só, 1,3 s depois
    await tester.pump(const Duration(milliseconds: 16));
    expect(_marca(tester).progress, 0); // ainda esperando
    _entregar(tester, decorrido: 2200);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_marca(tester).dot, closeTo(1, 0.01)); // continua de onde o Android estava
  });

  testWidgets('abertura: se o relógio do Android não bater, vale o tempo que ele contou', (tester) async {
    await _abrirApp(tester, doAndroid: true);
    await tester.pump();
    _entregar(tester, decorrido: 400, inicio: -5);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_marca(tester).progress, inExclusiveRange(0.3, 0.8)); // a linha pela metade
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_marca(tester).progress, 1);
    expect(_marca(tester).dot, greaterThan(0));
    expect(_revela(tester).fraction, greaterThan(0)); // o nome junto com a bolinha
  });

  testWidgets('abertura: sem a animação do Android (ou sem aviso), o app desenha tudo', (tester) async {
    await _abrirApp(tester, doAndroid: true);
    await tester.pump();
    _entregar(tester, decorrido: -1, inicio: -1); // a tela de carregamento não tinha animação
    await tester.pump(const Duration(milliseconds: 16));
    expect(_marca(tester).progress, lessThan(0.05));
    await tester.pumpAndSettle();
    expect(find.text('Bora pedalar?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // recomeça o app do zero
    await _abrirApp(tester, doAndroid: true);
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // ~1 s de quadros
    }
    expect(_marca(tester).progress, 0); // ainda esperando o aviso
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // passou do prazo: começa sozinho
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(_marca(tester).progress, inExclusiveRange(0.2, 0.9));
    await tester.pumpAndSettle();
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('abertura: um toque pula para a transição', (tester) async {
    await _abrirApp(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(aberturaKey));
    await tester.pump(); // a transição começa a contar neste quadro
    await tester.pump(const Duration(milliseconds: 500)); // termina em menos de 0,5 s
    await tester.pump();
    expect(find.byKey(aberturaKey), findsNothing);
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });
}
