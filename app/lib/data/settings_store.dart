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
    this.nome,
    this.margemVolta = 0.03,
    this.voz = true,
    this.vozId,
    this.ftp,
    this.planoId,
    this.planoInicio,
    this.intensidade = 1,
    this.controleBike = true,
  });

  final double pesoKg;
  final PowerMode modoPotencia;
  final double base;
  final double fator;
  final int cargaPadrao;
  final double metaSemanalKm;
  final String? ultimaBikeId;
  final String? ultimaBikeNome;

  /// Como a pessoa quer ser chamada (vazio = sem nome).
  final String? nome;

  /// Quanto pode passar da volta (fração dela) e ainda fechar a volta ao encerrar.
  final double margemVolta;

  /// Avisos falados durante o pedal.
  final bool voz;

  /// Voz escolhida nos Ajustes (motor|nome|idioma); null = a automática.
  final String? vozId;

  /// FTP (W) do teste ou digitado; null = ainda não sabe (usa 2 W/kg).
  final double? ftp;

  /// Plano de treino em andamento e quando começou.
  final String? planoId;
  final DateTime? planoInicio;

  /// Ajuste das metas dos treinos pela resposta “como foi?” (1 = como escrito).
  final double intensidade;

  /// Deixar a bike ajustar a carga sozinha nos treinos, quando ela aceita.
  final bool controleBike;

  AppSettings copyWith({
    double? pesoKg,
    PowerMode? modoPotencia,
    double? base,
    double? fator,
    int? cargaPadrao,
    double? metaSemanalKm,
    String? ultimaBikeId,
    String? ultimaBikeNome,
    String? nome,
    double? margemVolta,
    bool? voz,
    String? vozId,
    bool vozAutomatica = false,
    double? ftp,
    String? planoId,
    DateTime? planoInicio,
    bool semPlano = false,
    double? intensidade,
    bool? controleBike,
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
        nome: nome ?? this.nome,
        margemVolta: margemVolta ?? this.margemVolta,
        voz: voz ?? this.voz,
        vozId: vozAutomatica ? null : (vozId ?? this.vozId),
        ftp: ftp ?? this.ftp,
        planoId: semPlano ? null : (planoId ?? this.planoId),
        planoInicio: semPlano ? null : (planoInicio ?? this.planoInicio),
        intensidade: intensidade ?? this.intensidade,
        controleBike: controleBike ?? this.controleBike,
      );

  Map<String, String> toMap() => {
        'pesoKg': '$pesoKg',
        'modoPotencia': modoPotencia.name,
        'base': '$base',
        'fator': '$fator',
        'cargaPadrao': '$cargaPadrao',
        'metaSemanalKm': '$metaSemanalKm',
        'ultimaBikeId': ?ultimaBikeId,
        'ultimaBikeNome': ?ultimaBikeNome,
        'nome': ?nome,
        'margemVolta': '$margemVolta',
        'voz': voz ? '1' : '0',
        'vozId': ?vozId,
        'ftp': ?ftp?.toString(),
        'planoId': ?planoId,
        'planoInicio': ?planoInicio?.millisecondsSinceEpoch.toString(),
        'intensidade': '$intensidade',
        'controleBike': controleBike ? '1' : '0',
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
      nome: m['nome'],
      margemVolta: dbl('margemVolta', d.margemVolta),
      voz: m['voz'] != '0',
      vozId: m['vozId'],
      ftp: double.tryParse(m['ftp'] ?? ''),
      planoId: m['planoId'],
      planoInicio: int.tryParse(m['planoInicio'] ?? '') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(int.parse(m['planoInicio']!)),
      intensidade: dbl('intensidade', d.intensidade),
      controleBike: m['controleBike'] != '0',
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
