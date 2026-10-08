import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/ride_samples.dart';
import '../domain/ride_session.dart';
import '../domain/route_profile.dart';
import '../domain/stats.dart';

enum RideMode { rota, fantasma, livre }

String rideModeLabel(RideMode mode) => switch (mode) {
      RideMode.rota => 'Rota',
      RideMode.fantasma => 'Contra o fantasma',
      RideMode.livre => 'Pedal livre',
    };

class RideRecord implements RideStat {
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
    this.laps = 0,
    this.loop = false,
    this.reversed = false,
    this.trimmedM = 0,
    this.track,
  });

  final String id;
  final String? routeId;
  final RideMode mode;
  @override
  final DateTime startedAt;
  @override
  final double movingTimeS;
  @override
  final double distanceM;
  final double avgPowerW;
  final double avgSpeedKmh;
  @override
  final double gainM;
  final double kcal;
  final bool completed;
  final List<RideSample> samples;

  /// Voltas completas (ida concluída = 1).
  final int laps;

  /// A rota pedalada era uma volta fechada.
  final bool loop;

  /// Pedalada no sentido contrário ao que foi desenhada.
  final bool reversed;

  /// Metros descartados ao fechar a volta pela margem.
  final double trimmedM;

  /// Caminho de uma volta, no sentido e começo pedalados (null no pedal livre).
  final List<ProfilePoint>? track;

  RideRecord copyWith({
    String? id,
    String? routeId,
    RideMode? mode,
    double? movingTimeS,
    double? distanceM,
    double? avgPowerW,
    double? avgSpeedKmh,
    double? gainM,
    double? kcal,
    bool? completed,
    List<RideSample>? samples,
    int? laps,
    bool? loop,
    bool? reversed,
    double? trimmedM,
    List<ProfilePoint>? track,
  }) =>
      RideRecord(
        id: id ?? this.id,
        routeId: routeId ?? this.routeId,
        mode: mode ?? this.mode,
        startedAt: startedAt,
        movingTimeS: movingTimeS ?? this.movingTimeS,
        distanceM: distanceM ?? this.distanceM,
        avgPowerW: avgPowerW ?? this.avgPowerW,
        avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
        gainM: gainM ?? this.gainM,
        kcal: kcal ?? this.kcal,
        completed: completed ?? this.completed,
        samples: samples ?? this.samples,
        laps: laps ?? this.laps,
        loop: loop ?? this.loop,
        reversed: reversed ?? this.reversed,
        trimmedM: trimmedM ?? this.trimmedM,
        track: track ?? this.track,
      );

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
        'laps': laps,
        'loop': loop ? 1 : 0,
        'reversed': reversed ? 1 : 0,
        'trimmed_m': trimmedM,
        'track': track == null ? null : packTrack(track!),
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
        laps: (r['laps'] as int?) ?? 0,
        loop: (r['loop'] as int?) == 1,
        reversed: (r['reversed'] as int?) == 1,
        trimmedM: (r['trimmed_m'] as num?)?.toDouble() ?? 0,
        track: r['track'] == null ? null : unpackTrack(r['track'] as Uint8List),
      );
}

abstract class RidesStore {
  Future<void> upsert(RideRecord ride);
  Future<RideRecord?> byId(String id);
  Future<List<RideRecord>> recent({int limit = 50});
  Future<void> delete(String id);

  /// Pedais de uma rota, mais novo primeiro, sem as amostras.
  Future<List<RideRecord>> forRoute(String routeId);

  /// Só os números de todos os pedais (para os totais).
  Future<List<RideStat>> stats();
}

const _listColumns = [
  'id', 'route_id', 'mode', 'started_at', 'moving_time_s', 'distance_m',
  'avg_power_w', 'avg_speed_kmh', 'gain_m', 'kcal', 'completed', 'laps', 'loop', 'reversed',
  'trimmed_m', 'track',
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

  @override
  Future<List<RideStat>> stats() async {
    final rows = await _db.query('rides', columns: ['started_at', 'distance_m', 'moving_time_s', 'gain_m']);
    return [
      for (final r in rows)
        RideStat(
          startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
          distanceM: (r['distance_m'] as num).toDouble(),
          movingTimeS: (r['moving_time_s'] as num).toDouble(),
          gainM: (r['gain_m'] as num).toDouble(),
        ),
    ];
  }

  @override
  Future<List<RideRecord>> forRoute(String routeId) async {
    final rows = await _db.query('rides',
        columns: _listColumns, where: 'route_id = ?', whereArgs: [routeId], orderBy: 'started_at DESC');
    return rows.map(RideRecord.fromRow).toList();
  }
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

  @override
  Future<List<RideRecord>> forRoute(String routeId) async =>
      (await recent(limit: 1 << 30)).where((r) => r.routeId == routeId).toList();

  @override
  Future<List<RideStat>> stats() async => _rides.values.toList();
}
