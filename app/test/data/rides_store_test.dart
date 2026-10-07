import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
