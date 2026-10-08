import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../routes_store.dart';

const _schemaVersion = 3;

Future<void> _createRoutes(DatabaseExecutor db) => db.execute('''
  CREATE TABLE routes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    waypoints TEXT NOT NULL,
    points TEXT NOT NULL,
    distance_m REAL NOT NULL,
    gain_m REAL NOT NULL,
    loss_m REAL NOT NULL,
    color INTEGER NOT NULL DEFAULT 0
  )''');

/// Versão 3: cor de cada rota. As que já existiam ganham cores seguidas, pela ordem de criação.
Future<void> _addRouteColor(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE routes ADD COLUMN color INTEGER NOT NULL DEFAULT 0');
  final rows = await db.query('routes', columns: ['id'], orderBy: 'created_at');
  for (var i = 0; i < rows.length; i++) {
    await db.update('routes', {'color': i % routeColorCount}, where: 'id = ?', whereArgs: [rows[i]['id']]);
  }
}

/// Abre (ou cria/atualiza) o banco do app. Nos testes, passe `databaseFactoryFfi` e `inMemoryDatabasePath`.
Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? p.join(await f.getDatabasesPath(), 'pedal_local.db');
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: _schemaVersion,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('''
          CREATE TABLE rides (
            id TEXT PRIMARY KEY,
            route_id TEXT,
            mode TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            moving_time_s REAL NOT NULL,
            distance_m REAL NOT NULL,
            avg_power_w REAL NOT NULL,
            avg_speed_kmh REAL NOT NULL,
            gain_m REAL NOT NULL,
            kcal REAL NOT NULL,
            completed INTEGER NOT NULL,
            samples BLOB NOT NULL
          )''');
        await db.execute('CREATE INDEX rides_started ON rides(started_at DESC)');
        await _createRoutes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createRoutes(db);
        } else if (oldVersion < 3) {
          await _addRouteColor(db);
        }
      },
    ),
  );
}
