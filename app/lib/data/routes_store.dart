import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/geo.dart';
import '../domain/route_profile.dart';

class RouteRecord {
  const RouteRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.waypoints,
    required this.points,
    required this.distanceM,
    required this.gainM,
    required this.lossM,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<GeoPoint> waypoints;
  final List<ProfilePoint> points; // a cada 20 m, altitude suavizada
  final double distanceM;
  final double gainM;
  final double lossM;

  RouteRecord copyWith({String? name}) => RouteRecord(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        waypoints: waypoints,
        points: points,
        distanceM: distanceM,
        gainM: gainM,
        lossM: lossM,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'waypoints': jsonEncode([
          for (final w in waypoints) [w.lat, w.lon],
        ]),
        'points': jsonEncode([
          for (final p in points) [p.lat, p.lon, p.alt],
        ]),
        'distance_m': distanceM,
        'gain_m': gainM,
        'loss_m': lossM,
      };

  factory RouteRecord.fromRow(Map<String, Object?> r) {
    double n(Object? v) => (v as num).toDouble();
    final waypoints = jsonDecode(r['waypoints'] as String) as List;
    final points = jsonDecode(r['points'] as String) as List;
    return RouteRecord(
      id: r['id'] as String,
      name: r['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      waypoints: [
        for (final w in waypoints) GeoPoint(n((w as List)[0]), n(w[1])),
      ],
      points: [
        for (final p in points) ProfilePoint(n((p as List)[0]), n(p[1]), n(p[2])),
      ],
      distanceM: n(r['distance_m']),
      gainM: n(r['gain_m']),
      lossM: n(r['loss_m']),
    );
  }
}

abstract class RoutesStore {
  Future<void> upsert(RouteRecord route);
  Future<RouteRecord?> byId(String id);
  Future<List<RouteRecord>> all();
  Future<void> delete(String id);
}

class SqliteRoutesStore implements RoutesStore {
  SqliteRoutesStore(this._db);

  final Database _db;

  @override
  Future<void> upsert(RouteRecord route) =>
      _db.insert('routes', route.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<RouteRecord?> byId(String id) async {
    final rows = await _db.query('routes', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : RouteRecord.fromRow(rows.first);
  }

  @override
  Future<List<RouteRecord>> all() async {
    final rows = await _db.query('routes', orderBy: 'created_at DESC');
    return rows.map(RouteRecord.fromRow).toList();
  }

  @override
  Future<void> delete(String id) => _db.delete('routes', where: 'id = ?', whereArgs: [id]);
}

class MemoryRoutesStore implements RoutesStore {
  final _routes = <String, RouteRecord>{};

  @override
  Future<void> upsert(RouteRecord route) async => _routes[route.id] = route;

  @override
  Future<RouteRecord?> byId(String id) async => _routes[id];

  @override
  Future<List<RouteRecord>> all() async =>
      _routes.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> delete(String id) async => _routes.remove(id);
}
