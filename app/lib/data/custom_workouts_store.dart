import 'package:sqflite/sqflite.dart';

import '../domain/workout_blocks.dart';

/// Os treinos montados pelo usuário.
abstract class CustomWorkoutsStore {
  /// Todos, o mais novo primeiro.
  Future<List<CustomWorkout>> all();
  Future<void> upsert(CustomWorkout workout);
  Future<void> delete(String id);
}

class SqliteCustomWorkoutsStore implements CustomWorkoutsStore {
  SqliteCustomWorkoutsStore(this._db);

  final Database _db;

  @override
  Future<List<CustomWorkout>> all() async {
    final rows = await _db.query('custom_workouts', orderBy: 'created_at DESC');
    return rows.map(CustomWorkout.fromRow).toList();
  }

  @override
  Future<void> upsert(CustomWorkout workout) =>
      _db.insert('custom_workouts', workout.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> delete(String id) => _db.delete('custom_workouts', where: 'id = ?', whereArgs: [id]);
}

class MemoryCustomWorkoutsStore implements CustomWorkoutsStore {
  final _treinos = <String, CustomWorkout>{};

  @override
  Future<List<CustomWorkout>> all() async =>
      _treinos.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> upsert(CustomWorkout workout) async => _treinos[workout.id] = workout;

  @override
  Future<void> delete(String id) async => _treinos.remove(id);
}
