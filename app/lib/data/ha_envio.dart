import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ha_detalhe.dart';
import 'ha_retrato.dart';
import 'providers.dart';
import 'rides_store.dart';
import 'routes_store.dart';
import 'services/app_http.dart';
import 'settings_store.dart';

/// Como terminou uma tentativa de mandar os pedais para o Home Assistant.
enum HaResultado {
  /// Sem endereço nos Ajustes: este celular não manda.
  semEndereco,

  /// Mandou, e o Home Assistant respondeu que recebeu.
  enviado,

  /// Nada mudou desde o último envio (de menos de 1 dia): não precisou mandar.
  jaEstava,

  /// Não deu (fora do Wi-Fi de casa, Home Assistant desligado, endereço errado…). Fica marcado,
  /// e a próxima vez tenta de novo.
  falhou,
}

/// O que se sabe do último envio (fica num arquivo do app, fora do banco).
class HaEnvioEstado {
  const HaEnvioEstado({this.okEm, this.tentativaEm, this.falhou = false, this.assinatura});

  /// Quando o último envio deu certo.
  final DateTime? okEm;

  /// Quando foi a última tentativa (certa ou não).
  final DateTime? tentativaEm;

  /// A última tentativa falhou.
  final bool falhou;

  /// Resumo do que foi no último envio certo (endereço + JSON), para saber se algo mudou.
  final String? assinatura;

  Map<String, Object?> toJson() => {
    'okEm': okEm?.millisecondsSinceEpoch,
    'tentativaEm': tentativaEm?.millisecondsSinceEpoch,
    'falhou': falhou,
    'assinatura': assinatura,
  };

  factory HaEnvioEstado.fromJson(Map<String, dynamic> m) {
    DateTime? data(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    return HaEnvioEstado(
      okEm: data(m['okEm']),
      tentativaEm: data(m['tentativaEm']),
      falhou: m['falhou'] == true,
      assinatura: m['assinatura'] as String?,
    );
  }
}

abstract class HaEnvioEstadoStore {
  Future<HaEnvioEstado> load();
  Future<void> save(HaEnvioEstado estado);
}

/// O estado num arquivo JSON do app. Sem arquivo (ou estragado), começa do zero.
class ArquivoHaEnvioEstadoStore implements HaEnvioEstadoStore {
  ArquivoHaEnvioEstadoStore(this._arquivo);

  final Future<File> Function() _arquivo;

  @override
  Future<HaEnvioEstado> load() async {
    try {
      final arquivo = await _arquivo();
      if (!await arquivo.exists()) return const HaEnvioEstado();
      return HaEnvioEstado.fromJson(jsonDecode(await arquivo.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const HaEnvioEstado();
    }
  }

  @override
  Future<void> save(HaEnvioEstado estado) async {
    await (await _arquivo()).writeAsString(jsonEncode(estado.toJson()), flush: true);
  }
}

class MemoryHaEnvioEstadoStore implements HaEnvioEstadoStore {
  HaEnvioEstado _estado = const HaEnvioEstado();

  @override
  Future<HaEnvioEstado> load() async => _estado;

  @override
  Future<void> save(HaEnvioEstado estado) async => _estado = estado;
}

/// O que já foi do detalhe dos pedais (fica num arquivo do app, fora do banco).
class HaDetalheEstado {
  const HaDetalheEstado({
    this.endereco,
    this.enviados = const {},
    this.okEm,
    this.tentativaEm,
    this.falhou = false,
    this.faltam = 0,
  });

  /// O endereço para onde foram os [enviados] (mudou = manda tudo de novo).
  final String? endereco;

  /// Pedal (id) → resumo do que foi ([assinaturaDetalhe]); mudou = manda de novo.
  final Map<String, String> enviados;

  /// Quando um detalhe foi pela última vez.
  final DateTime? okEm;
  final DateTime? tentativaEm;
  final bool falhou;

  /// Quantos pedais ainda faltavam mandar na última passada.
  final int faltam;

  Map<String, Object?> toJson() => {
    'endereco': endereco,
    'enviados': enviados,
    'okEm': okEm?.millisecondsSinceEpoch,
    'tentativaEm': tentativaEm?.millisecondsSinceEpoch,
    'falhou': falhou,
    'faltam': faltam,
  };

  factory HaDetalheEstado.fromJson(Map<String, dynamic> m) {
    DateTime? data(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    final enviados = m['enviados'];
    return HaDetalheEstado(
      endereco: m['endereco'] as String?,
      enviados: enviados is Map ? {for (final e in enviados.entries) '${e.key}': '${e.value}'} : const {},
      okEm: data(m['okEm']),
      tentativaEm: data(m['tentativaEm']),
      falhou: m['falhou'] == true,
      faltam: m['faltam'] is int ? m['faltam'] as int : 0,
    );
  }
}

abstract class HaDetalheEstadoStore {
  Future<HaDetalheEstado> load();
  Future<void> save(HaDetalheEstado estado);
}

/// O estado do detalhe num arquivo JSON do app. Sem arquivo (ou estragado), começa do zero.
class ArquivoHaDetalheEstadoStore implements HaDetalheEstadoStore {
  ArquivoHaDetalheEstadoStore(this._arquivo);

  final Future<File> Function() _arquivo;

  @override
  Future<HaDetalheEstado> load() async {
    try {
      final arquivo = await _arquivo();
      if (!await arquivo.exists()) return const HaDetalheEstado();
      return HaDetalheEstado.fromJson(jsonDecode(await arquivo.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const HaDetalheEstado();
    }
  }

  @override
  Future<void> save(HaDetalheEstado estado) async {
    await (await _arquivo()).writeAsString(jsonEncode(estado.toJson()), flush: true);
  }
}

class MemoryHaDetalheEstadoStore implements HaDetalheEstadoStore {
  HaDetalheEstado _estado = const HaDetalheEstado();

  @override
  Future<HaDetalheEstado> load() async => _estado;

  @override
  Future<void> save(HaDetalheEstado estado) async => _estado = estado;
}

/// Resumo do que muda num pedal já salvo (ele cresce enquanto é gravado e muda ao fechar a
/// volta). Igual = o detalhe que foi continua valendo.
String assinaturaDetalhe(RideRecord r) => [
  'v$haDetalheVersao',
  r.movingTimeS.round(),
  r.distanceM.round(),
  r.laps,
  r.completed,
  r.trimmedM.round(),
  r.routeId ?? '',
].join('|');

/// Manda o retrato de todos os pedais para o Home Assistant da casa (pedalaqui-ha.md).
///
/// Cada envio manda tudo de novo e substitui o anterior. Manda depois de salvar ou apagar um
/// pedal e de mudar o nome ou o peso ([pedir]) e ao abrir o app ([aoAbrir]); em todos, só se algo
/// mudou, se o último falhou ou se já faz 1 dia. Falhar não incomoda ninguém: fica marcado e a
/// próxima vez tenta de novo.
///
/// Depois de cada vez, manda também o detalhe dos pedais que ainda não foram ([mandarDetalhes]),
/// para o 2.º endereço: um pedido por pedal, do mais novo ao mais velho, com uma pausa entre eles.
class HaEnvio {
  HaEnvio({
    required this.ajustes,
    required this.pedais,
    required this.rotas,
    required this.estado,
    required this.client,
    HaDetalheEstadoStore? estadoDetalhe,
    DateTime Function()? agora,
    this.espera = const Duration(seconds: 2),
    this.prazo = const Duration(seconds: 10),
    this.intervalo = const Duration(milliseconds: 500),
    this.aoMudar,
  }) : estadoDetalhe = estadoDetalhe ?? MemoryHaDetalheEstadoStore(),
       agora = agora ?? clock.now;

  final SettingsStore ajustes;
  final RidesStore pedais;
  final RoutesStore rotas;
  final HaEnvioEstadoStore estado;
  final HaDetalheEstadoStore estadoDetalhe;
  final http.Client client;
  final DateTime Function() agora;

  /// Pausa entre um detalhe e o próximo (uns 2 por segundo, para não pesar no Home Assistant).
  final Duration intervalo;

  /// Quanto [pedir] espera para juntar pedidos seguidos (cada tecla do nome) num envio só.
  final Duration espera;

  /// Quanto espera a resposta do Home Assistant antes de desistir.
  final Duration prazo;

  /// Chamado quando o estado do envio muda (a tela dos Ajustes mostra).
  final void Function()? aoMudar;

  Timer? _timer;
  int _pedidos = 0;
  bool _fechado = false;
  Future<HaResultado> _fila = Future.value(HaResultado.semEndereco);

  /// Depois de salvar ou apagar um pedal, ou de mudar um ajuste: manda daqui a pouco.
  void pedir() {
    _timer?.cancel();
    _timer = null;
    final este = ++_pedidos;
    // Sem endereço, nem fica esperando.
    ajustes.load().then((s) {
      if (_fechado || este != _pedidos || (_endereco(s).isEmpty && _enderecoDetalhe(s).isEmpty)) return;
      _timer = Timer(espera, () {
        _timer = null;
        unawaited(_rodar(forcar: false));
      });
    }, onError: (Object _) {});
  }

  /// Ao abrir o app.
  Future<HaResultado> aoAbrir() => _rodar(forcar: false);

  /// Manda agora, mesmo que nada tenha mudado (o botão dos Ajustes).
  Future<HaResultado> enviarAgora() => _rodar(forcar: true);

  void dispose() {
    _fechado = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Um envio de cada vez, na ordem em que foram pedidos; depois, o detalhe do que faltar.
  Future<HaResultado> _rodar({required bool forcar}) {
    final vez = _fila.then((_) => _uma(forcar: forcar));
    _fila = vez;
    unawaited(vez.then((_) {
      if (!_fechado) unawaited(mandarDetalhes());
    }));
    return vez;
  }

  Future<void>? _detalhe;
  bool _maisUmaPassada = false;

  /// Manda o detalhe dos pedais que ainda não foram (ou que mudaram). Se já estiver mandando,
  /// dá mais uma passada no fim (e devolve a mesma espera).
  Future<void> mandarDetalhes() {
    final atual = _detalhe;
    if (atual != null) {
      _maisUmaPassada = true;
      return atual;
    }
    return _detalhe = _lacoDetalhes();
  }

  Future<void> _lacoDetalhes() async {
    try {
      do {
        _maisUmaPassada = false;
        await _passadaDetalhes();
      } while (_maisUmaPassada && !_fechado);
    } catch (_) {
      // banco ou arquivo fora do ar: a próxima vez tenta de novo
    } finally {
      _detalhe = null;
    }
  }

  Future<void> _passadaDetalhes() async {
    final s = await ajustes.load();
    final endereco = _enderecoDetalhe(s);
    if (endereco.isEmpty) return;
    final antes = await estadoDetalhe.load();
    final uri = _uri(endereco);
    if (uri == null) {
      await _guardarDetalhe(HaDetalheEstado(
        endereco: antes.endereco,
        enviados: antes.enviados,
        okEm: antes.okEm,
        tentativaEm: agora(),
        falhou: true,
        faltam: antes.faltam,
      ));
      return;
    }
    final mesmo = antes.endereco == endereco;
    final enviados = mesmo ? {...antes.enviados} : <String, String>{};
    final lista = await pedais.recent(limit: 1 << 30); // sem as amostras
    final existem = {for (final r in lista) r.id};
    final sumiram = enviados.keys.where((id) => !existem.contains(id)).toList();
    for (final id in sumiram) {
      enviados.remove(id);
    }
    final faltam = [for (final r in lista) if (enviados[r.id] != assinaturaDetalhe(r)) r];
    var okEm = mesmo ? antes.okEm : null;
    HaDetalheEstado estadoAgora(int restam, {bool falhou = false}) => HaDetalheEstado(
      endereco: endereco,
      enviados: Map.unmodifiable(enviados),
      okEm: okEm,
      tentativaEm: agora(),
      falhou: falhou,
      faltam: restam,
    );
    if (faltam.isEmpty) {
      if (!mesmo || sumiram.isNotEmpty || antes.falhou || antes.faltam != 0) await _guardarDetalhe(estadoAgora(0));
      return;
    }
    Map<String, String>? nomes;
    var mandou = false;
    for (var i = 0; i < faltam.length; i++) {
      if (_fechado) return;
      final completo = await pedais.byId(faltam[i].id);
      if (completo == null) continue;
      if (completo.samples.length < 2) {
        // sem amostras (pedal antigo ou curto demais): não há o que mostrar
        enviados[completo.id] = assinaturaDetalhe(completo);
        continue;
      }
      if (mandou) await Future<void>.delayed(intervalo);
      if (_fechado) return;
      nomes ??= {for (final r in await rotas.all()) r.id: r.name};
      final corpo = corpoDetalheHa(completo, nomeRota: completo.routeId == null ? null : nomes[completo.routeId]);
      var recebeu = false;
      try {
        final resposta = await client.post(uri, headers: appJsonHeaders, body: corpo).timeout(prazo);
        recebeu = resposta.statusCode >= 200 && resposta.statusCode < 300;
      } catch (_) {
        // sem rede, Home Assistant desligado ou demorou demais
      }
      if (!recebeu) {
        await _guardarDetalhe(estadoAgora(faltam.length - i, falhou: true));
        return;
      }
      mandou = true;
      enviados[completo.id] = assinaturaDetalhe(completo);
      okEm = agora();
      await _guardarDetalhe(estadoAgora(faltam.length - i - 1));
    }
    await _guardarDetalhe(estadoAgora(0));
  }

  Future<void> _guardarDetalhe(HaDetalheEstado novo) async {
    try {
      await estadoDetalhe.save(novo);
    } catch (_) {
      // sem arquivo: manda de novo depois, sem problema
    }
    aoMudar?.call();
  }

  Future<HaResultado> _uma({required bool forcar}) async {
    try {
      return await _tentar(forcar: forcar);
    } catch (_) {
      return HaResultado.falhou;
    }
  }

  Future<HaResultado> _tentar({required bool forcar}) async {
    final s = await ajustes.load();
    final endereco = _endereco(s);
    if (endereco.isEmpty) return HaResultado.semEndereco;
    final antes = await estado.load();
    final uri = _uri(endereco);
    if (uri == null) return _falhou(antes);
    final corpo = corpoHa(
      nome: s.nome,
      pesoKg: s.pesoKg,
      pedais: await pedais.recent(limit: 1 << 30),
      rotas: await rotas.all(),
    );
    final assinatura = assinaturaHa('$endereco\n$corpo');
    final ok = antes.okEm;
    final emDia =
        !antes.falhou && ok != null && antes.assinatura == assinatura && agora().difference(ok) < const Duration(days: 1);
    if (emDia && !forcar) return HaResultado.jaEstava;
    var recebeu = false;
    try {
      final resposta = await client.post(uri, headers: appJsonHeaders, body: corpo).timeout(prazo);
      recebeu = resposta.statusCode >= 200 && resposta.statusCode < 300;
    } catch (_) {
      // sem rede, Home Assistant desligado ou demorou demais
    }
    if (!recebeu) return _falhou(antes);
    final quando = agora();
    await _guardar(HaEnvioEstado(okEm: quando, tentativaEm: quando, assinatura: assinatura));
    return HaResultado.enviado;
  }

  Future<HaResultado> _falhou(HaEnvioEstado antes) async {
    await _guardar(HaEnvioEstado(okEm: antes.okEm, tentativaEm: agora(), falhou: true, assinatura: antes.assinatura));
    return HaResultado.falhou;
  }

  Future<void> _guardar(HaEnvioEstado novo) async {
    try {
      await estado.save(novo);
    } catch (_) {
      // sem arquivo: na próxima abertura manda de novo, sem problema
    }
    aoMudar?.call();
  }

  static String _endereco(AppSettings s) => s.haEndereco?.trim() ?? '';

  static String _enderecoDetalhe(AppSettings s) => s.haDetalheEndereco?.trim() ?? '';

  /// O endereço, se for um http(s) com servidor.
  static Uri? _uri(String endereco) {
    final uri = Uri.tryParse(endereco);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) return null;
    return uri;
  }
}

/// Resumo curto de um texto (FNV-1a de 32 bits e o tamanho): igual = mesmo conteúdo.
String assinaturaHa(String texto) {
  final bytes = utf8.encode(texto);
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h = ((h ^ b) * 0x01000193) & 0xffffffff;
  }
  return '${bytes.length}-${h.toRadixString(16)}';
}

/// O estado fica em `files/ha_envio.json` (o banco não muda).
final haEnvioEstadoStoreProvider = Provider<HaEnvioEstadoStore>(
  (ref) => ArquivoHaEnvioEstadoStore(
    () async => File(p.join((await getApplicationSupportDirectory()).path, 'ha_envio.json')),
  ),
);

/// O último envio, para os Ajustes mostrarem.
final haEnvioEstadoProvider = FutureProvider<HaEnvioEstado>((ref) => ref.watch(haEnvioEstadoStoreProvider).load());

/// O que já foi do detalhe fica em `files/ha_detalhe.json`.
final haDetalheEstadoStoreProvider = Provider<HaDetalheEstadoStore>(
  (ref) => ArquivoHaDetalheEstadoStore(
    () async => File(p.join((await getApplicationSupportDirectory()).path, 'ha_detalhe.json')),
  ),
);

/// O detalhe dos pedais, para os Ajustes mostrarem.
final haDetalheEstadoProvider = FutureProvider<HaDetalheEstado>(
  (ref) => ref.watch(haDetalheEstadoStoreProvider).load(),
);

final haEnvioProvider = Provider<HaEnvio>((ref) {
  final envio = HaEnvio(
    ajustes: ref.watch(settingsStoreProvider),
    pedais: ref.watch(ridesStoreProvider),
    rotas: ref.watch(routesStoreProvider),
    estado: ref.watch(haEnvioEstadoStoreProvider),
    estadoDetalhe: ref.watch(haDetalheEstadoStoreProvider),
    client: ref.watch(httpClientProvider),
    aoMudar: () {
      if (!ref.mounted) return;
      ref
        ..invalidate(haEnvioEstadoProvider)
        ..invalidate(haDetalheEstadoProvider);
    },
  );
  ref.onDispose(envio.dispose);
  return envio;
});
