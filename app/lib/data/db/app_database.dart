import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/ride_samples.dart';
import '../../domain/route_variant.dart';
import '../routes_store.dart';

const _schemaVersion = 6;

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
    color INTEGER NOT NULL DEFAULT 0,
    relief INTEGER NOT NULL DEFAULT 1
  )''');

/// Versão 3: cor de cada rota. As que já existiam ganham cores seguidas, pela ordem de criação.
Future<void> _addRouteColor(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE routes ADD COLUMN color INTEGER NOT NULL DEFAULT 0');
  final rows = await db.query('routes', columns: ['id'], orderBy: 'created_at');
  for (var i = 0; i < rows.length; i++) {
    await db.update('routes', {'color': i % routeColorCount}, where: 'id = ?', whereArgs: [rows[i]['id']]);
  }
}

/// Versão 4: voltas, sentido, corte da margem e o caminho pedalado. Pedais antigos de rota
/// recebem o caminho da rota (sentido original) e 1 volta se foram até o fim.
Future<void> _addRideLaps(DatabaseExecutor db) async {
  final temPedais = await db.query('sqlite_master', where: "type = 'table' AND name = 'rides'");
  if (temPedais.isEmpty) return;
  for (final coluna in [
    'laps INTEGER NOT NULL DEFAULT 0',
    'loop INTEGER NOT NULL DEFAULT 0',
    'reversed INTEGER NOT NULL DEFAULT 0',
    'trimmed_m REAL NOT NULL DEFAULT 0',
    'track BLOB',
  ]) {
    await db.execute('ALTER TABLE rides ADD COLUMN $coluna');
  }
  final pedais = await db.query('rides',
      columns: ['id', 'route_id', 'distance_m', 'completed'], where: 'route_id IS NOT NULL');
  for (final pedal in pedais) {
    final rotas = await db.query('routes', where: 'id = ?', whereArgs: [pedal['route_id']], limit: 1);
    if (rotas.isEmpty) continue;
    final rota = RouteRecord.fromRow(rotas.first);
    final foiAteOFim = pedal['completed'] == 1 && (pedal['distance_m'] as num) >= rota.distanceM - 1;
    await db.update(
      'rides',
      {'track': packTrack(rota.points), 'loop': isLoop(rota.points) ? 1 : 0, 'laps': foiAteOFim ? 1 : 0},
      where: 'id = ?',
      whereArgs: [pedal['id']],
    );
  }
}

/// Versão 5: qual treino foi feito, como foi (resposta do fim) e o FTP medido no teste.
Future<void> _addRideWorkout(DatabaseExecutor db) async {
  final temPedais = await db.query('sqlite_master', where: "type = 'table' AND name = 'rides'");
  if (temPedais.isEmpty) return;
  for (final coluna in ['workout_id TEXT', 'feeling INTEGER', 'ftp REAL']) {
    await db.execute('ALTER TABLE rides ADD COLUMN $coluna');
  }
}

/// Versão 6: versão do relevo de cada rota. As salvas antes ficam com 1 (sem pontes em reta) e
/// são refeitas quando houver internet.
Future<void> _addRouteRelief(DatabaseExecutor db) async {
  final colunas = await db.rawQuery('PRAGMA table_info(routes)');
  if (colunas.any((c) => c['name'] == 'relief')) return;
  await db.execute('ALTER TABLE routes ADD COLUMN relief INTEGER NOT NULL DEFAULT 1');
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
            samples BLOB NOT NULL,
            laps INTEGER NOT NULL DEFAULT 0,
            loop INTEGER NOT NULL DEFAULT 0,
            reversed INTEGER NOT NULL DEFAULT 0,
            trimmed_m REAL NOT NULL DEFAULT 0,
            track BLOB,
            workout_id TEXT,
            feeling INTEGER,
            ftp REAL
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
        if (oldVersion < 4) await _addRideLaps(db);
        if (oldVersion < 5) await _addRideWorkout(db);
        if (oldVersion >= 2 && oldVersion < 6) await _addRouteRelief(db);
      },
    ),
  );
}
