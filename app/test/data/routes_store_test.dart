import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RouteRecord rota(String id, DateTime criada, {String nome = 'Volta do bairro'}) => RouteRecord(
      id: id,
      name: nome,
      createdAt: criada,
      waypoints: const [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)],
      points: const [ProfilePoint(-23.5, -46.6, 760.5), ProfilePoint(-23.5001, -46.6001, 761)],
      distanceM: 8400,
      gainM: 96,
      lossM: 90,
    );

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('salva e lê a rota com pontos e altitudes', () async {
    final store = SqliteRoutesStore(db);
    await store.upsert(rota('a', DateTime(2026, 10, 8, 9)));
    final r = (await store.byId('a'))!;
    expect(r.name, 'Volta do bairro');
    expect(r.createdAt, DateTime(2026, 10, 8, 9));
    expect(r.waypoints, const [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)]);
    expect(r.points.length, 2);
    expect(r.points.first.alt, 760.5);
    expect(r.distanceM, 8400);
    expect(await store.byId('zzz'), isNull);
  });

  test('all: mais nova primeiro; apagar remove', () async {
    final store = SqliteRoutesStore(db);
    await store.upsert(rota('velha', DateTime(2026, 10, 1)));
    await store.upsert(rota('nova', DateTime(2026, 10, 8)));
    expect((await store.all()).map((r) => r.id), ['nova', 'velha']);
    await store.delete('velha');
    expect((await store.all()).map((r) => r.id), ['nova']);
  });

  test('copyWith troca o nome', () {
    expect(rota('a', DateTime(2026)).copyWith(name: 'Ladeira').name, 'Ladeira');
  });

  test('versão em memória', () async {
    final store = MemoryRoutesStore();
    await store.upsert(rota('velha', DateTime(2026, 10, 1)));
    await store.upsert(rota('nova', DateTime(2026, 10, 8)));
    expect((await store.all()).map((r) => r.id), ['nova', 'velha']);
  });

  test('banco da versão 1 ganha a tabela de rotas e mantém os pedais', () async {
    final dir = await Directory.systemTemp.createTemp('pedal_v1');
    final caminho = '${dir.path}/v1.db';
    final antigo = await databaseFactoryFfi.openDatabase(caminho,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async {
            await d.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            await d.execute("INSERT INTO settings VALUES ('pesoKg', '82')");
          },
        ));
    await antigo.close();
    final novo = await openAppDatabase(factory: databaseFactoryFfi, path: caminho);
    expect(await novo.query('settings'), [
      {'key': 'pesoKg', 'value': '82'},
    ]);
    await SqliteRoutesStore(novo).upsert(rota('a', DateTime(2026)));
    expect((await SqliteRoutesStore(novo).all()).length, 1);
    await novo.close();
    await dir.delete(recursive: true);
  });
}
