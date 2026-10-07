import 'package:sqflite/sqflite.dart';

import '../domain/power.dart';

class AppSettings {
  const AppSettings({
    this.pesoKg = 75,
    this.modoPotencia = PowerMode.auto,
    this.base = 0.6,
    this.fator = 0.25,
    this.cargaPadrao = 4,
    this.metaSemanalKm = 60,
    this.ultimaBikeId,
    this.ultimaBikeNome,
  });

  final double pesoKg;
  final PowerMode modoPotencia;
  final double base;
  final double fator;
  final int cargaPadrao;
  final double metaSemanalKm;
  final String? ultimaBikeId;
  final String? ultimaBikeNome;

  AppSettings copyWith({
    double? pesoKg,
    PowerMode? modoPotencia,
    double? base,
    double? fator,
    int? cargaPadrao,
    double? metaSemanalKm,
    String? ultimaBikeId,
    String? ultimaBikeNome,
  }) =>
      AppSettings(
        pesoKg: pesoKg ?? this.pesoKg,
        modoPotencia: modoPotencia ?? this.modoPotencia,
        base: base ?? this.base,
        fator: fator ?? this.fator,
        cargaPadrao: cargaPadrao ?? this.cargaPadrao,
        metaSemanalKm: metaSemanalKm ?? this.metaSemanalKm,
        ultimaBikeId: ultimaBikeId ?? this.ultimaBikeId,
        ultimaBikeNome: ultimaBikeNome ?? this.ultimaBikeNome,
      );

  Map<String, String> toMap() => {
        'pesoKg': '$pesoKg',
        'modoPotencia': modoPotencia.name,
        'base': '$base',
        'fator': '$fator',
        'cargaPadrao': '$cargaPadrao',
        'metaSemanalKm': '$metaSemanalKm',
        if (ultimaBikeId != null) 'ultimaBikeId': ultimaBikeId!,
        if (ultimaBikeNome != null) 'ultimaBikeNome': ultimaBikeNome!,
      };

  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    double dbl(String k, double padrao) => double.tryParse(m[k] ?? '') ?? padrao;
    return AppSettings(
      pesoKg: dbl('pesoKg', d.pesoKg),
      modoPotencia: PowerMode.values.asNameMap()[m['modoPotencia']] ?? d.modoPotencia,
      base: dbl('base', d.base),
      fator: dbl('fator', d.fator),
      cargaPadrao: int.tryParse(m['cargaPadrao'] ?? '') ?? d.cargaPadrao,
      metaSemanalKm: dbl('metaSemanalKm', d.metaSemanalKm),
      ultimaBikeId: m['ultimaBikeId'],
      ultimaBikeNome: m['ultimaBikeNome'],
    );
  }
}

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SqliteSettingsStore implements SettingsStore {
  SqliteSettingsStore(this._db);

  final Database _db;

  @override
  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    return AppSettings.fromMap({for (final r in rows) r['key'] as String: r['value'] as String});
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _db.transaction((txn) async {
      await txn.delete('settings');
      final batch = txn.batch();
      settings.toMap().forEach((k, v) => batch.insert('settings', {'key': k, 'value': v}));
      await batch.commit(noResult: true);
    });
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}
