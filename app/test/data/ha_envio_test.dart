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
}
