import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/power.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('sem nada salvo, devolve os padrões', () async {
    final s = await SqliteSettingsStore(db).load();
    expect(s.pesoKg, 75);
    expect(s.modoPotencia, PowerMode.auto);
    expect(s.cargaPadrao, 4);
    expect(s.metaSemanalKm, 60);
    expect(s.ultimaBikeId, isNull);
  });

  test('salva e lê de volta', () async {
    final store = SqliteSettingsStore(db);
    await store.save(const AppSettings().copyWith(
      pesoKg: 82,
      modoPotencia: PowerMode.estimada,
      fator: 0.3,
      cargaPadrao: 6,
      ultimaBikeId: 'AA:BB',
      ultimaBikeNome: 'FS-1234',
    ));
    final s = await store.load();
    expect(s.pesoKg, 82);
    expect(s.modoPotencia, PowerMode.estimada);
    expect(s.fator, 0.3);
    expect(s.cargaPadrao, 6);
    expect(s.ultimaBikeId, 'AA:BB');
    expect(s.ultimaBikeNome, 'FS-1234');
  });

  test('versão em memória', () async {
    final store = MemorySettingsStore();
    await store.save(const AppSettings(pesoKg: 90));
    expect((await store.load()).pesoKg, 90);
  });
}
