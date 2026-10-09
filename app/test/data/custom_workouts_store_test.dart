import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/custom_workouts_store.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/domain/workout_blocks.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CustomWorkout meu(String id, DateTime criado, {String nome = 'Tiros de terça'}) => CustomWorkout(
  id: id,
  name: nome,
  blocks: [WorkoutBlock.novo(BlockKind.aquecer), WorkoutBlock.novo(BlockKind.serie)],
  createdAt: criado,
  updatedAt: criado,
);

/// Salva, lista (mais novo primeiro), atualiza e apaga: igual no banco e na memória.
Future<void> _confere(CustomWorkoutsStore store) async {
  await store.upsert(meu('meu-a', DateTime(2026, 10, 1)));
  await store.upsert(meu('meu-b', DateTime(2026, 10, 2), nome: 'Subidas'));
  expect((await store.all()).map((w) => w.id), ['meu-b', 'meu-a']);
  await store.upsert(meu('meu-a', DateTime(2026, 10, 1), nome: 'Tiros de quinta'));
  final todos = await store.all();
  expect(todos.length, 2);
  expect(todos.last.name, 'Tiros de quinta');
  expect(todos.last.blocks.map((b) => b.kind), [BlockKind.aquecer, BlockKind.serie]);
  await store.delete('meu-b');
  expect((await store.all()).map((w) => w.id), ['meu-a']);
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('no banco: salva, lista, atualiza e apaga', () async {
    final db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    addTearDown(db.close);
    await _confere(SqliteCustomWorkoutsStore(db));
  });

  test('na memória: igual ao banco', () => _confere(MemoryCustomWorkoutsStore()));

  test('banco da versão 6: ganha os treinos do usuário e o nome do treino nos pedais, sem perder nada', () async {
    final dir = await Directory.systemTemp.createTemp('pedal_v6');
    final caminho = '${dir.path}/v6.db';
    final antigo = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (d, v) async {
          await d.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          await d.execute('''
            CREATE TABLE rides (
              id TEXT PRIMARY KEY, route_id TEXT, mode TEXT NOT NULL, started_at INTEGER NOT NULL,
              moving_time_s REAL NOT NULL, distance_m REAL NOT NULL, avg_power_w REAL NOT NULL,
              avg_speed_kmh REAL NOT NULL, gain_m REAL NOT NULL, kcal REAL NOT NULL,
              completed INTEGER NOT NULL, samples BLOB NOT NULL,
              laps INTEGER NOT NULL DEFAULT 0, loop INTEGER NOT NULL DEFAULT 0,
              reversed INTEGER NOT NULL DEFAULT 0, trimmed_m REAL NOT NULL DEFAULT 0, track BLOB,
              workout_id TEXT, feeling INTEGER, ftp REAL
            )''');
          await d.execute('''
            CREATE TABLE routes (
              id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL,
              waypoints TEXT NOT NULL, points TEXT NOT NULL,
              distance_m REAL NOT NULL, gain_m REAL NOT NULL, loss_m REAL NOT NULL,
              color INTEGER NOT NULL DEFAULT 0, relief INTEGER NOT NULL DEFAULT 1
            )''');
          final pedal = RideRecord(
            id: 'velho',
            mode: RideMode.treino,
            startedAt: DateTime(2026, 10, 8, 19),
            movingTimeS: 1200,
            distanceM: 9000,
            avgPowerW: 150,
            avgSpeedKmh: 27,
            gainM: 0,
            kcal: 180,
            completed: true,
            laps: 1,
            workoutId: 'intervalos-5x1',
          );
          await d.insert('rides', pedal.toRow()..remove('workout_name'));
        },
      ),
    );
    await antigo.close();
    final novo = await openAppDatabase(factory: databaseFactoryFfi, path: caminho);
    final pedal = (await SqliteRidesStore(novo).byId('velho'))!;
    expect(pedal.workoutId, 'intervalos-5x1');
    expect(pedal.workoutName, isNull);
    expect(pedal.movingTimeS, 1200);
    expect(rideName(pedal), 'Intervalos 5 × 1 min'); // sem nome guardado, procura na biblioteca
    await SqliteCustomWorkoutsStore(novo).upsert(meu('meu-a', DateTime(2026, 10, 9)));
    expect((await SqliteCustomWorkoutsStore(novo).all()).single.name, 'Tiros de terça');
    await novo.close();
    await dir.delete(recursive: true);
  });

  test('qualquer treino pelo id: da biblioteca ou do usuário', () async {
    final store = MemoryCustomWorkoutsStore();
    await store.upsert(meu('meu-a', DateTime(2026, 10, 9)));
    final container = ProviderContainer(overrides: [customWorkoutsStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    container.listen(findWorkoutProvider, (_, _) {});
    await container.read(customWorkoutsProvider.future);
    final achar = container.read(findWorkoutProvider);
    expect(achar('intervalos-5x1')!.name, 'Intervalos 5 × 1 min');
    expect(achar('meu-a')!.name, 'Tiros de terça');
    expect(achar('meu-a')!.category, customWorkoutCategory);
    expect(achar('meu-zzz'), isNull);
  });
}
