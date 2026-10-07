import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/ride_samples.dart';
import '../domain/ride_session.dart';

enum RideMode { rota, fantasma, livre }

String rideModeLabel(RideMode mode) => switch (mode) {
      RideMode.rota => 'Rota',
      RideMode.fantasma => 'Contra o fantasma',
      RideMode.livre => 'Pedal livre',
    };

class RideRecord {
  const RideRecord({
    required this.id,
    this.routeId,
    required this.mode,
    required this.startedAt,
    required this.movingTimeS,
    required this.distanceM,
    required this.avgPowerW,
    required this.avgSpeedKmh,
    required this.gainM,
    required this.kcal,
    required this.completed,
    this.samples = const [],
  });

  final String id;
  final String? routeId;
  final RideMode mode;
  final DateTime startedAt;
  final double movingTimeS;
  final double distanceM;
  final double avgPowerW;
  final double avgSpeedKmh;
  final double gainM;
  final double kcal;
  final bool completed;
  final List<RideSample> samples;

  Map<String, Object?> toRow() => {
        'id': id,
        'route_id': routeId,
        'mode': mode.name,
        'started_at': startedAt.millisecondsSinceEpoch,
        'moving_time_s': movingTimeS,
        'distance_m': distanceM,
        'avg_power_w': avgPowerW,
        'avg_speed_kmh': avgSpeedKmh,
        'gain_m': gainM,
        'kcal': kcal,
        'completed': completed ? 1 : 0,
        'samples': packSamples(samples),
      };

  factory RideRecord.fromRow(Map<String, Object?> r) => RideRecord(
        id: r['id'] as String,
        routeId: r['route_id'] as String?,
        mode: RideMode.values.byName(r['mode'] as String),
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        movingTimeS: (r['moving_time_s'] as num).toDouble(),
        distanceM: (r['distance_m'] as num).toDouble(),
        avgPowerW: (r['avg_power_w'] as num).toDouble(),
        avgSpeedKmh: (r['avg_speed_kmh'] as num).toDouble(),
        gainM: (r['gain_m'] as num).toDouble(),
        kcal: (r['kcal'] as num).toDouble(),
        completed: (r['completed'] as int) == 1,
        samples: r['samples'] == null ? const [] : unpackSamples(r['samples'] as Uint8List),
      );
}

abstract class RidesStore {
  Future<void> upsert(RideRecord ride);
  Future<RideRecord?> byId(String id);
  Future<List<RideRecord>> recent({int limit = 50});
  Future<void> delete(String id);
}

const _listColumns = [
  'id', 'route_id', 'mode', 'started_at', 'moving_time_s', 'distance_m',
  'avg_power_w', 'avg_speed_kmh', 'gain_m', 'kcal', 'completed',
];

class SqliteRidesStore implements RidesStore {
  SqliteRidesStore(this._db);

  final Database _db;

  @override
  Future<void> upsert(RideRecord ride) =>
      _db.insert('rides', ride.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<RideRecord?> byId(String id) async {
    final rows = await _db.query('rides', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : RideRecord.fromRow(rows.first);
  }

  @override
  Future<List<RideRecord>> recent({int limit = 50}) async {
    final rows = await _db.query('rides', columns: _listColumns, orderBy: 'started_at DESC', limit: limit);
    return rows.map(RideRecord.fromRow).toList();
  }

  @override
  Future<void> delete(String id) => _db.delete('rides', where: 'id = ?', whereArgs: [id]);
}

class MemoryRidesStore implements RidesStore {
  final _rides = <String, RideRecord>{};

  @override
  Future<void> upsert(RideRecord ride) async => _rides[ride.id] = ride;

  @override
  Future<RideRecord?> byId(String id) async => _rides[id];

  @override
  Future<List<RideRecord>> recent({int limit = 50}) async {
    final lista = _rides.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return lista.take(limit).toList();
  }

  @override
  Future<void> delete(String id) async => _rides.remove(id);
}
