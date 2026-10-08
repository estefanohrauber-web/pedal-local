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
    expect(s.nome, isNull);
    expect(s.margemVolta, 0.03);
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
      nome: 'Ana',
      margemVolta: 0.05,
    ));
    final s = await store.load();
    expect(s.pesoKg, 82);
    expect(s.modoPotencia, PowerMode.estimada);
    expect(s.fator, 0.3);
    expect(s.cargaPadrao, 6);
    expect(s.ultimaBikeId, 'AA:BB');
    expect(s.ultimaBikeNome, 'FS-1234');
    expect(s.nome, 'Ana');
    expect(s.margemVolta, 0.05);
  });

  test('treinos: FTP, plano, intensidade e controle da bike', () async {
    final store = SqliteSettingsStore(db);
    final padrao = await store.load();
    expect(padrao.ftp, isNull);
    expect(padrao.planoId, isNull);
    expect(padrao.intensidade, 1);
    expect(padrao.controleBike, isTrue);
    final inicio = DateTime(2026, 10, 8, 9);
    await store.save(padrao.copyWith(ftp: 187, planoId: 'comecando', planoInicio: inicio, intensidade: 1.03, controleBike: false));
    final s = await store.load();
    expect(s.ftp, 187);
    expect(s.planoId, 'comecando');
    expect(s.planoInicio, inicio);
    expect(s.intensidade, 1.03);
    expect(s.controleBike, isFalse);
    final semPlano = s.copyWith(semPlano: true);
    expect(semPlano.planoId, isNull);
    expect(semPlano.planoInicio, isNull);
    expect(semPlano.ftp, 187);
  });

  test('versão em memória', () async {
    final store = MemorySettingsStore();
    await store.save(const AppSettings(pesoKg: 90));
    expect((await store.load()).pesoKg, 90);
  });
}
