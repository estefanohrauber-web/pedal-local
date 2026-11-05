import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/ha_envio.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/ride_session.dart';

const endereco = 'http://192.168.3.70/api/webhook/pedalaqui-teste';

RideRecord pedal(String id, DateTime inicio, {double distancia = 3200}) => RideRecord(
  id: id,
  mode: RideMode.livre,
  startedAt: inicio,
  movingTimeS: 800,
  distanceM: distancia,
  avgPowerW: 120,
  avgSpeedKmh: 14.4,
  gainM: 0,
  kcal: 90,
  completed: true,
);

void main() {
  late MemorySettingsStore ajustes;
  late MemoryRidesStore pedais;
  late MemoryHaEnvioEstadoStore estado;
  late List<http.Request> pedidos;
  late Future<http.Response> Function(http.Request) responder;
  late DateTime agora;
  late HaEnvio envio;
  var mudou = 0;

  setUp(() async {
    ajustes = MemorySettingsStore(const AppSettings(nome: 'Estéfano', pesoKg: 78, haEndereco: endereco));
    pedais = MemoryRidesStore();
    await pedais.upsert(pedal('a', DateTime(2026, 11, 3, 19)));
    estado = MemoryHaEnvioEstadoStore();
    pedidos = [];
    responder = (_) async => http.Response('', 200);
    agora = DateTime(2026, 11, 4, 8);
    mudou = 0;
    envio = HaEnvio(
      ajustes: ajustes,
      pedais: pedais,
      rotas: MemoryRoutesStore(),
      estado: estado,
      client: MockClient((req) {
        pedidos.add(req);
        return responder(req);
      }),
      agora: () => agora,
      espera: const Duration(milliseconds: 20),
      prazo: const Duration(milliseconds: 100),
      aoMudar: () => mudou++,
    );
  });
  tearDown(() => envio.dispose());

  test('manda o retrato por POST, em JSON, no endereço do celular', () async {
    expect(await envio.enviarAgora(), HaResultado.enviado);
    final p = pedidos.single;
    expect(p.method, 'POST');
    expect(p.url.toString(), endereco);
    expect(p.headers['Content-Type'], startsWith('application/json'));
    final corpo = jsonDecode(p.body) as Map<String, dynamic>;
    expect(corpo['versao'], 1);
    expect(corpo['nome'], 'Estéfano');
    expect(corpo['peso_kg'], 78);
    expect(corpo['resumo'], {'pedais': 1, 'distancia_m': 3200, 'tempo_s': 800, 'subida_m': 0});
    expect(corpo['pedais'], hasLength(1));
    final e = await estado.load();
    expect(e.okEm, agora);
    expect(e.falhou, isFalse);
    expect(mudou, greaterThan(0), reason: 'avisa a tela dos Ajustes');
  });

  test('sem endereço (ou com um que não é http), não manda nada', () async {
    await ajustes.save(const AppSettings(haEndereco: '  '));
    expect(await envio.aoAbrir(), HaResultado.semEndereco);
    expect(await envio.enviarAgora(), HaResultado.semEndereco);
    await ajustes.save(const AppSettings(haEndereco: 'casa'));
    expect(await envio.enviarAgora(), HaResultado.falhou);
    expect(pedidos, isEmpty);
  });

  test('falha (sem Wi-Fi de casa, erro do HA ou demora) só marca; ao abrir, tenta de novo', () async {
    responder = (_) async => throw const SocketException('sem rede');
    expect(await envio.enviarAgora(), HaResultado.falhou);
    expect((await estado.load()).falhou, isTrue);
    expect((await estado.load()).tentativaEm, agora);

    responder = (_) async => http.Response('erro', 500);
    agora = agora.add(const Duration(minutes: 1));
    expect(await envio.aoAbrir(), HaResultado.falhou);

    responder = (_) => Completer<http.Response>().future; // nunca responde
    expect(await envio.aoAbrir(), HaResultado.falhou);

    responder = (_) async => http.Response('', 200);
    expect(await envio.aoAbrir(), HaResultado.enviado);
    final e = await estado.load();
    expect(e.falhou, isFalse);
    expect(e.okEm, agora);
    expect(pedidos, hasLength(4));
  });

  test('ao abrir: não repete o que já foi há menos de 1 dia; manda se mudou ou depois de 1 dia', () async {
    expect(await envio.aoAbrir(), HaResultado.enviado, reason: 'nunca mandou');
    agora = agora.add(const Duration(hours: 2));
    expect(await envio.aoAbrir(), HaResultado.jaEstava);
    expect(pedidos, hasLength(1));

    await pedais.upsert(pedal('b', DateTime(2026, 11, 4, 9)));
    expect(await envio.aoAbrir(), HaResultado.enviado, reason: 'pedal novo');
    expect(pedidos, hasLength(2));

    agora = agora.add(const Duration(hours: 23));
    expect(await envio.aoAbrir(), HaResultado.jaEstava);
    agora = agora.add(const Duration(hours: 2));
    expect(await envio.aoAbrir(), HaResultado.enviado, reason: 'mais de 1 dia');
    expect(pedidos, hasLength(3));
  });

  test('mudar o nome, o peso ou o endereço manda de novo', () async {
    await envio.enviarAgora();
    await ajustes.save((await ajustes.load()).copyWith(pesoKg: 79));
    expect(await envio.aoAbrir(), HaResultado.enviado);
    await ajustes.save((await ajustes.load()).copyWith(nome: 'Estéfano R.'));
    expect(await envio.aoAbrir(), HaResultado.enviado);
    await ajustes.save((await ajustes.load()).copyWith(haEndereco: '$endereco-2'));
    expect(await envio.aoAbrir(), HaResultado.enviado);
    expect(pedidos.last.url.toString(), '$endereco-2');
    // mudar outra coisa (que não vai no retrato) não manda
    await ajustes.save((await ajustes.load()).copyWith(metaSemanalKm: 100));
    expect(await envio.aoAbrir(), HaResultado.jaEstava);
    expect(pedidos, hasLength(4));
  });

  test('pedir junta vários pedidos seguidos num só envio', () async {
    envio.pedir();
    envio.pedir();
    await pedais.upsert(pedal('b', DateTime(2026, 11, 4, 9)));
    envio.pedir();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(pedidos, hasLength(1));
    expect((jsonDecode(pedidos.single.body) as Map)['pedais'], hasLength(2));
  });

  test('pedir sem endereço não deixa nada esperando', () async {
    await ajustes.save(const AppSettings());
    envio.pedir();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(pedidos, isEmpty);
  });

  test('dois envios ao mesmo tempo saem um depois do outro', () async {
    final segura = Completer<http.Response>();
    responder = (_) => pedidos.length == 1 ? segura.future : Future.value(http.Response('', 200));
    final primeiro = envio.enviarAgora();
    final segundo = envio.enviarAgora();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(pedidos, hasLength(1));
    segura.complete(http.Response('', 200));
    expect(await primeiro, HaResultado.enviado);
    expect(await segundo, HaResultado.enviado);
    expect(pedidos, hasLength(2));
  });

  test('o estado fica num arquivo do app e volta igual', () async {
    final pasta = await Directory.systemTemp.createTemp('ha_envio');
    addTearDown(() => pasta.delete(recursive: true));
    final arquivo = File('${pasta.path}/ha_envio.json');
    final store = ArquivoHaEnvioEstadoStore(() async => arquivo);
    expect((await store.load()).okEm, isNull, reason: 'sem arquivo ainda');
    final e = HaEnvioEstado(
      okEm: DateTime(2026, 11, 4, 8),
      tentativaEm: DateTime(2026, 11, 4, 9),
      falhou: true,
      assinatura: 'abc',
    );
    await store.save(e);
    final lido = await store.load();
    expect(lido.okEm, e.okEm);
    expect(lido.tentativaEm, e.tentativaEm);
    expect(lido.falhou, isTrue);
    expect(lido.assinatura, 'abc');
    await arquivo.writeAsString('{quebrado');
    expect((await store.load()).falhou, isFalse, reason: 'arquivo estragado = começa do zero');
  });

  group('detalhe de cada pedal', () {
    late MemoryHaDetalheEstadoStore estadoDetalhe;
    late HaEnvio comDetalhe;

    List<http.Request> doDetalhe() => [for (final p in pedidos) if (p.url.toString() == enderecoDetalhe) p];
    int inicio(http.Request p) => (jsonDecode(p.body) as Map<String, dynamic>)['inicio'] as int;
    int seg(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

    setUp(() async {
      await ajustes.save((await ajustes.load()).copyWith(haDetalheEndereco: enderecoDetalhe));
      // 'a' (do setUp de fora) não tem amostras; 'b' e 'c' têm
      await pedais.upsert(comAmostras('b', DateTime(2026, 11, 1, 7)));
      await pedais.upsert(comAmostras('c', DateTime(2026, 11, 2, 7)));
      estadoDetalhe = MemoryHaDetalheEstadoStore();
      comDetalhe = HaEnvio(
        ajustes: ajustes,
        pedais: pedais,
        rotas: MemoryRoutesStore(),
        estado: estado,
        estadoDetalhe: estadoDetalhe,
        client: MockClient((req) {
          pedidos.add(req);
          return responder(req);
        }),
        agora: () => agora,
        espera: const Duration(milliseconds: 20),
        prazo: const Duration(milliseconds: 100),
        intervalo: Duration.zero,
        aoMudar: () => mudou++,
      );
    });
    tearDown(() => comDetalhe.dispose());

    test('um pedido por pedal com amostras, do mais novo ao mais velho, no 2.º endereço', () async {
      await comDetalhe.mandarDetalhes();
      final d = doDetalhe();
      expect([for (final p in d) inicio(p)], [seg(DateTime(2026, 11, 2, 7)), seg(DateTime(2026, 11, 1, 7))]);
      expect(d.first.method, 'POST');
      expect(d.first.headers['Content-Type'], startsWith('application/json'));
      expect((jsonDecode(d.first.body) as Map)['amostras'], hasLength(120));
      expect(pedidos.where((p) => p.url.toString() == endereco), isEmpty, reason: 'o resumo só vai quando pedido');
      final e = await estadoDetalhe.load();
      expect(e.endereco, enderecoDetalhe);
      expect(e.enviados.keys, unorderedEquals(['a', 'b', 'c']), reason: "'a' sem amostras fica marcado para não olhar de novo");
      expect(e.faltam, 0);
      expect(e.okEm, agora);
      expect(e.falhou, isFalse);
    });

    test('não manda de novo o que já foi; manda o que mudou', () async {
      await comDetalhe.mandarDetalhes();
      pedidos.clear();
      await comDetalhe.mandarDetalhes();
      expect(pedidos, isEmpty);
      await pedais.upsert(comAmostras('b', DateTime(2026, 11, 1, 7), n: 150));
      await comDetalhe.mandarDetalhes();
      expect([for (final p in doDetalhe()) inicio(p)], [seg(DateTime(2026, 11, 1, 7))]);
    });

    test('endereço novo: manda tudo de novo para ele', () async {
      await comDetalhe.mandarDetalhes();
      pedidos.clear();
      const outro = 'http://192.168.3.70/api/webhook/outro';
      await ajustes.save((await ajustes.load()).copyWith(haDetalheEndereco: outro));
      await comDetalhe.mandarDetalhes();
      expect(pedidos.map((p) => p.url.toString()), [outro, outro]);
    });

    test('pedal apagado no app: manda “apagar” (só dos que tinham ido) e tira da lista', () async {
      await comDetalhe.mandarDetalhes();
      pedidos.clear();
      await pedais.delete('c');
      await pedais.delete('a'); // sem amostras: nunca foi, não há o que apagar
      await comDetalhe.mandarDetalhes();
      expect([for (final p in doDetalhe()) jsonDecode(p.body)], [
        {'versao': 1, 'inicio': seg(DateTime(2026, 11, 2, 7)), 'apagar': true},
      ]);
      expect((await estadoDetalhe.load()).enviados.keys, ['b']);
    });

    test('“apagar” que falhou fica para a próxima vez', () async {
      await comDetalhe.mandarDetalhes();
      await pedais.delete('c');
      responder = (_) async => http.Response('', 500);
      await comDetalhe.mandarDetalhes();
      var e = await estadoDetalhe.load();
      expect(e.falhou, isTrue);
      expect(e.faltam, 1);
      expect(e.enviados.keys, contains('c'));
      responder = (_) async => http.Response('', 200);
      pedidos.clear();
      await comDetalhe.mandarDetalhes();
      expect(doDetalhe(), hasLength(1));
      e = await estadoDetalhe.load();
      expect(e.enviados.keys, isNot(contains('c')));
      expect(e.faltam, 0);
    });

    test('falhou: para, marca o que falta e continua na próxima vez', () async {
      responder = (_) async => throw const SocketException('sem rede');
      await comDetalhe.mandarDetalhes();
      expect(doDetalhe(), hasLength(1), reason: 'na primeira falha, não insiste com os outros');
      var e = await estadoDetalhe.load();
      expect(e.falhou, isTrue);
      expect(e.faltam, 2);
      expect(e.okEm, isNull);
      responder = (_) async => http.Response('', 200);
      pedidos.clear();
      await comDetalhe.mandarDetalhes();
      expect(doDetalhe(), hasLength(2));
      e = await estadoDetalhe.load();
      expect(e.falhou, isFalse);
      expect(e.faltam, 0);
    });

    test('ao abrir o app, depois do resumo, manda o detalhe', () async {
      expect(await comDetalhe.aoAbrir(), HaResultado.enviado);
      await comDetalhe.mandarDetalhes(); // espera a passada que o aoAbrir começou
      expect(pedidos.first.url.toString(), endereco);
      expect(doDetalhe(), hasLength(2));
    });

    test('só com o endereço do detalhe, pedir também manda', () async {
      await ajustes.save((await ajustes.load()).copyWith(haEndereco: ''));
      comDetalhe.pedir();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await comDetalhe.mandarDetalhes();
      expect(pedidos.where((p) => p.url.toString() == endereco), isEmpty);
      expect(doDetalhe(), hasLength(2));
    });

    test('espera entre um pedal e o próximo', () async {
      await pedais.upsert(comAmostras('d', DateTime(2026, 11, 3, 7)));
      final devagar = HaEnvio(
        ajustes: ajustes,
        pedais: pedais,
        rotas: MemoryRoutesStore(),
        estado: estado,
        estadoDetalhe: MemoryHaDetalheEstadoStore(),
        client: MockClient((req) async {
          pedidos.add(req);
          return http.Response('', 200);
        }),
        intervalo: const Duration(milliseconds: 60),
      );
      addTearDown(devagar.dispose);
      final relogio = Stopwatch()..start();
      await devagar.mandarDetalhes();
      expect(doDetalhe(), hasLength(3));
      expect(relogio.elapsedMilliseconds, greaterThanOrEqualTo(120), reason: '2 pausas entre 3 pedais');
    });

    test('o estado do detalhe fica num arquivo do app e volta igual', () async {
      final pasta = await Directory.systemTemp.createTemp('ha_detalhe');
      addTearDown(() => pasta.delete(recursive: true));
      final arquivo = File('${pasta.path}/ha_detalhe.json');
      final store = ArquivoHaDetalheEstadoStore(() async => arquivo);
      expect((await store.load()).enviados, isEmpty, reason: 'sem arquivo ainda');
      await store.save(HaDetalheEstado(
        endereco: enderecoDetalhe,
        enviados: const {'b': 'v1|120|600'},
        okEm: DateTime(2026, 11, 5, 8),
        tentativaEm: DateTime(2026, 11, 5, 9),
        falhou: true,
        faltam: 3,
      ));
      final lido = await store.load();
      expect(lido.endereco, enderecoDetalhe);
      expect(lido.enviados, {'b': 'v1|120|600'});
      expect(lido.okEm, DateTime(2026, 11, 5, 8));
      expect(lido.tentativaEm, DateTime(2026, 11, 5, 9));
      expect(lido.falhou, isTrue);
      expect(lido.faltam, 3);
      await arquivo.writeAsString('{quebrado');
      expect((await store.load()).enviados, isEmpty, reason: 'arquivo estragado = começa do zero');
    });
  });
}

const enderecoDetalhe = 'http://192.168.3.70/api/webhook/pedalaqui-teste-pedal';

/// Um pedal livre com [n] amostras (uma por segundo, a 5 m/s).
RideRecord comAmostras(String id, DateTime inicio, {int n = 120}) => RideRecord(
  id: id,
  mode: RideMode.livre,
  startedAt: inicio,
  movingTimeS: n.toDouble(),
  distanceM: n * 5.0,
  avgPowerW: 130,
  avgSpeedKmh: 18,
  gainM: 0,
  kcal: 20,
  completed: true,
  samples: [
    for (var i = 0; i < n; i++)
      RideSample(t: i + 1.0, distance: (i + 1) * 5.0, speedKmh: 18, power: 130, cadence: 80),
  ],
);
