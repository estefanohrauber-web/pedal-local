import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/geo_helpers.dart';

RideRecord pedal(String id, DateTime inicio, {bool completed = true}) => RideRecord(
      id: id,
      mode: RideMode.livre,
      startedAt: inicio,
      movingTimeS: 600,
      distanceM: 5000,
      avgPowerW: 150,
      avgSpeedKmh: 30,
      gainM: 0,
      kcal: 90,
      completed: completed,
      samples: const [
        RideSample(t: 1, distance: 8, speedKmh: 29, power: 150, cadence: 80),
        RideSample(t: 2, distance: 16, speedKmh: 29.5, power: 152, cadence: 81, heartRate: 130),
      ],
    );

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('salva e lê pelo id, com as amostras', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('a', DateTime(2026, 10, 7, 20)));
    final r = await store.byId('a');
    expect(r, isNotNull);
    expect(r!.mode, RideMode.livre);
    expect(r.distanceM, 5000);
    expect(r.completed, isTrue);
    expect(r.startedAt, DateTime(2026, 10, 7, 20));
    expect(r.samples.length, 2);
    expect(r.samples[1].heartRate, 130);
    expect(await store.byId('zzz'), isNull);
  });

  test('upsert com o mesmo id substitui', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('a', DateTime(2026, 10, 7), completed: false));
    await store.upsert(pedal('a', DateTime(2026, 10, 7)));
    expect((await store.recent()).length, 1);
    expect((await store.byId('a'))!.completed, isTrue);
  });

  test('recent: mais novo primeiro e sem amostras', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('velho', DateTime(2026, 10, 1)));
    await store.upsert(pedal('novo', DateTime(2026, 10, 7)));
    final lista = await store.recent();
    expect(lista.map((r) => r.id), ['novo', 'velho']);
    expect(lista.first.samples, isEmpty);
  });

  test('apaga', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('a', DateTime(2026, 10, 7)));
    await store.delete('a');
    expect(await store.byId('a'), isNull);
  });

  test('versão em memória ordena igual', () async {
    final store = MemoryRidesStore();
    await store.upsert(pedal('velho', DateTime(2026, 10, 1)));
    await store.upsert(pedal('novo', DateTime(2026, 10, 7)));
    expect((await store.recent()).map((r) => r.id), ['novo', 'velho']);
  });

  test('guarda voltas, sentido, corte e o caminho feito; a lista traz o caminho', () async {
    final store = SqliteRidesStore(db);
    final caminho = squareLoop(200, alts: (i) => 700.0 + i);
    await store.upsert(pedal('v', DateTime(2026, 10, 8)).copyWith(
      routeId: 'r1',
      mode: RideMode.rota,
      laps: 2,
      loop: true,
      reversed: true,
      trimmedM: 12.5,
      track: caminho,
    ));
    for (final r in [(await store.byId('v'))!, (await store.recent()).single]) {
      expect(r.laps, 2);
      expect(r.loop, isTrue);
      expect(r.reversed, isTrue);
      expect(r.trimmedM, 12.5);
      expect(r.track!.length, caminho.length);
      expect(r.track![5].alt, 705);
      expect(r.track![5].lat, caminho[5].lat);
    }
    final livre = (await store.byId('v'))!.copyWith(id: 'l');
    expect(livre.track, isNotNull);
    expect(pedal('x', DateTime(2026)).track, isNull);
    expect(pedal('x', DateTime(2026)).laps, 0);
  });

  test('pedais de uma rota, mais novo primeiro', () async {
    for (final store in <RidesStore>[SqliteRidesStore(db), MemoryRidesStore()]) {
      await store.upsert(pedal('a', DateTime(2026, 10, 1)).copyWith(routeId: 'r1', mode: RideMode.rota));
      await store.upsert(pedal('b', DateTime(2026, 10, 2)).copyWith(routeId: 'r2', mode: RideMode.rota));
      await store.upsert(pedal('c', DateTime(2026, 10, 3)).copyWith(routeId: 'r1', mode: RideMode.rota));
      expect((await store.forRoute('r1')).map((r) => r.id), ['c', 'a']);
    }
  });

  test('banco da versão 3: pedais de rota ganham o caminho da rota e a volta', () async {
    final dir = await Directory.systemTemp.createTemp('pedal_v3');
    final caminho = '${dir.path}/v3.db';
    final atual = await openAppDatabase(factory: databaseFactoryFfi, path: caminho);
    final rota = RouteRecord(
      id: 'r1',
      name: 'Volta',
      createdAt: DateTime(2026, 10, 8),
      waypoints: const [],
      points: squareLoop(200),
      distanceM: RouteProfile(squareLoop(200)).distance,
      gainM: 0,
      lossM: 0,
    );
    await SqliteRoutesStore(atual).upsert(rota);
    await atual.close();
    // volta o banco para a versão 3: sem as colunas novas de rides
    final v3 = await databaseFactoryFfi.openDatabase(caminho);
    await v3.execute('DROP TABLE rides');
    await v3.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY, route_id TEXT, mode TEXT NOT NULL, started_at INTEGER NOT NULL,
        moving_time_s REAL NOT NULL, distance_m REAL NOT NULL, avg_power_w REAL NOT NULL,
        avg_speed_kmh REAL NOT NULL, gain_m REAL NOT NULL, kcal REAL NOT NULL,
        completed INTEGER NOT NULL, samples BLOB NOT NULL
      )''');
    Map<String, Object?> linha(String id, double dist, int ok) => {
          'id': id, 'route_id': 'r1', 'mode': 'rota', 'started_at': 0, 'moving_time_s': 60,
          'distance_m': dist, 'avg_power_w': 100, 'avg_speed_kmh': 20, 'gain_m': 0, 'kcal': 6,
          'completed': ok, 'samples': Uint8List(0),
        };
    await v3.insert('rides', linha('inteiro', rota.distanceM, 1));
    await v3.insert('rides', linha('metade', rota.distanceM / 2, 1));
    await v3.setVersion(3);
    await v3.close();

    final novo = await openAppDatabase(factory: databaseFactoryFfi, path: caminho);
    final store = SqliteRidesStore(novo);
    final inteiro = (await store.byId('inteiro'))!;
    expect(inteiro.laps, 1);
    expect(inteiro.loop, isTrue);
    expect(inteiro.track!.length, rota.points.length);
    expect((await store.byId('metade'))!.laps, 0);
    await novo.close();
    await dir.delete(recursive: true);
  });
}
