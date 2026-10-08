import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';

Widget app(MemoryRidesStore rides) => ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        ridesStoreProvider.overrideWithValue(rides),
        routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
        mapTilesEnabledProvider.overrideWithValue(false),
        locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
      ],
      child: const PedalLocalApp(),
    );

void main() {
  testWidgets('abas e escolha do pedal', (tester) async {
    await tester.pumpWidget(app(MemoryRidesStore()));
    await tester.pumpAndSettle();
    expect(find.text('Bora pedalar?'), findsOneWidget);
    for (final aba in ['Início', 'Explorar', 'Treinos', 'Você']) {
      expect(find.text(aba), findsWidgets);
    }
    await tester.tap(find.byKey(const Key('botao-pedalar')));
    await tester.pumpAndSettle();
    expect(find.text('Como vai ser hoje?'), findsOneWidget);
    expect(find.text('Conectar a bike'), findsOneWidget);
  });

  testWidgets('aba Você mostra o histórico', (tester) async {
    final rides = MemoryRidesStore();
    await rides.upsert(RideRecord(
      id: 'a',
      mode: RideMode.livre,
      startedAt: DateTime(2026, 10, 7, 20, 4),
      movingTimeS: 1392,
      distanceM: 8400,
      avgPowerW: 161,
      avgSpeedKmh: 21.7,
      gainM: 0,
      kcal: 224,
      completed: true,
    ));
    await tester.pumpWidget(app(rides));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Você').last);
    await tester.pumpAndSettle();
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.textContaining('8,40 km'), findsOneWidget);
  });
}
