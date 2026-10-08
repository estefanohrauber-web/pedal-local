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

  test('guarda a cor da rota', () async {
    final store = SqliteRoutesStore(db);
    await store.upsert(rota('a', DateTime(2026)).copyWith(colorIndex: 3));
    expect((await store.byId('a'))!.colorIndex, 3);
    expect(rota('b', DateTime(2026)).colorIndex, 0);
  });

  test('próxima cor: a menos usada, empate fica com a primeira da lista', () {
    RouteRecord comCor(int i) => rota('r$i', DateTime(2026)).copyWith(colorIndex: i);
    expect(nextRouteColor(const []), 0);
    expect(nextRouteColor([comCor(0)]), 1);
    expect(nextRouteColor([comCor(0), comCor(2)]), 1);
    expect(nextRouteColor([for (var i = 0; i < routeColorCount; i++) comCor(i)]), 0);
    expect(nextRouteColor([for (var i = 0; i < routeColorCount; i++) comCor(i), comCor(0), comCor(1)]), 2);
  });

  test('banco da versão 2: rotas antigas ganham cores diferentes, pela ordem de criação', () async {
    final dir = await Directory.systemTemp.createTemp('pedal_v2');
    final caminho = '${dir.path}/v2.db';
    final antigo = await databaseFactoryFfi.openDatabase(caminho,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (d, v) async {
            await d.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            await d.execute('''
              CREATE TABLE routes (
                id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL,
                waypoints TEXT NOT NULL, points TEXT NOT NULL,
                distance_m REAL NOT NULL, gain_m REAL NOT NULL, loss_m REAL NOT NULL
              )''');
            for (final (id, dia) in [('terceira', 3), ('primeira', 1), ('segunda', 2)]) {
              final linha = rota(id, DateTime(2026, 10, dia)).toRow()..remove('color');
              await d.insert('routes', linha);
            }
          },
        ));
    await antigo.close();
    final novo = await openAppDatabase(factory: databaseFactoryFfi, path: caminho);
    final cores = {for (final r in await SqliteRoutesStore(novo).all()) r.id: r.colorIndex};
    expect(cores, {'primeira': 0, 'segunda': 1, 'terceira': 2});
    await novo.close();
    await dir.delete(recursive: true);
  });
}
