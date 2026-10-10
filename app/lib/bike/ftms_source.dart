import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../domain/ftms_control.dart';
import '../domain/ftms_parser.dart';
import 'bike_control.dart';
import 'bike_log.dart';
import 'bike_reading.dart';
import 'bike_source.dart';

/// O aparelho conectou, mas não tem o serviço FTMS. [diagnostic] lista o que ele tem.
class NoFtmsException implements Exception {
  const NoFtmsException(this.diagnostic);

  final String diagnostic;

  @override
  String toString() => 'Sem FTMS\n$diagnostic';
}

/// Bike real pelo Bluetooth, padrão FTMS. Anota no [log] o que acontece com a conexão e cada
/// pacote cru, para entender uma bike de verdade.
class FtmsSource implements BikeSource {
  FtmsSource({required this.deviceId, required this.deviceName, this.log});

  final String deviceId;
  final String deviceName;
  final BikeLog? log;
  final _montador = IndoorBikeAssembler();
  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<Uint8List>? _controlSub;
  final _extras = <StreamSubscription<Uint8List>>[];
  final _respostas = StreamController<ControlResponse>.broadcast();
  StreamSubscription<bool>? _connSub;
  BikeConnection _state = BikeConnection.desconectada;
  bool _manual = false;
  FtmsControl? _control;
  SessionStarter? _inicio;

  /// Muda a cada conexão e ao desconectar. O que uma conexão antiga ainda escutar (ou uma conexão
  /// interrompida no meio) fica quieto: não anota nem manda nada.
  int _geracao = 0;

  @override
  BikeControl? get control => _control;

  @override
  String get name => deviceName;

  @override
  bool get simulated => false;

  @override
  Stream<BikeReading> get readings => _readings.stream;

  @override
  Stream<BikeConnection> get connection => _connection.stream;

  @override
  BikeConnection get state => _state;

  void _set(BikeConnection c) {
    _state = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect() async {
    final g = ++_geracao;
    _inicio?.stop();
    _manual = false;
    _montador.reset();
    _set(BikeConnection.conectando);
    log?.add('conectando a $deviceName ($deviceId)');
    UniversalBle.onConnectionChange = (id, ligada, erro) {
      if (id == deviceId) log?.add('conexão ${ligada ? 'ligada' : 'caiu'}${erro == null ? '' : ': $erro'}');
    };
    try {
      await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 15));
      final services = await UniversalBle.discoverServices(deviceId);
      if (g != _geracao) return; // desconectaram no meio
      log?.add('serviços: ${[
        for (final s in services) '${_curto(s.uuid)}(${s.characteristics.map((c) => _curto(c.uuid)).join(' ')})',
      ].join(', ')}');
      final hasFtms = services.any((s) => s.uuid.toLowerCase() == ftmsServiceUuid);
      if (!hasFtms) {
        final lista = services.map((s) => '  ${s.uuid}').join('\n');
        _manual = true;
        await UniversalBle.disconnect(deviceId);
        _set(BikeConnection.desconectada);
        throw NoFtmsException('Aparelho: $deviceName\nServiços:\n${lista.isEmpty ? '  (nenhum)' : lista}');
      }
      await _valueSub?.cancel();
      _valueSub = UniversalBle.characteristicValueStream(deviceId, indoorBikeDataUuid).listen((b) {
        if (g == _geracao) _onValue(b);
      });
      await UniversalBle.subscribeNotifications(deviceId, ftmsServiceUuid, indoorBikeDataUuid);
      await _connSub?.cancel();
      _connSub = UniversalBle.connectionStream(deviceId).listen((connected) {
        if (connected) return;
        _inicio?.stop();
        _set(_manual ? BikeConnection.desconectada : BikeConnection.caiu);
      });
      await _escutarAvisos(services, g);
      if (g != _geracao) return;
      final comecou = await _comecar(services, g);
      if (g != _geracao) return;
      _control = await _lerControle(services, comecou: comecou);
      final f = _control?.features;
      log?.add('controle: ${f == null ? 'não aceita' : [
          if (f.power) 'potência',
          if (f.resistance) 'resistência',
          if (f.simulation) 'simulação',
        ].join(', ')}');
      _set(BikeConnection.conectada);
    } on NoFtmsException {
      log?.add('sem FTMS');
      rethrow;
    } catch (e) {
      log?.add('falhou ao conectar: $e');
      _set(BikeConnection.desconectada);
      rethrow;
    }
  }

  /// UUID padrão do Bluetooth (0000xxxx-0000-1000-8000-00805f9b34fb) só com o xxxx.
  static String _curto(String uuid) {
    final u = uuid.toLowerCase();
    return u.startsWith('0000') && u.endsWith('-0000-1000-8000-00805f9b34fb') ? u.substring(4, 8) : u;
  }

  /// Pede o controle e manda a bike começar. Sem isso, a Winnek manda tudo zerado (giro, potência
  /// e até o tempo de pedal), como se ninguém estivesse pedalando. Recém-acordada, ela responde
  /// “ok” mas o painel não obedece: o app insiste até ela avisar que começou ou os dados chegarem.
  /// Devolve se a bike aceitou o último pedido. As respostas vão para o diário.
  Future<bool> _comecar(List<BleService> services, int g) async {
    final ftms = services.firstWhere((s) => s.uuid.toLowerCase() == ftmsServiceUuid);
    if (!ftms.characteristics.any((c) => c.uuid.toLowerCase() == controlPointUuid)) {
      log?.add('sem Control Point: não dá para mandar começar');
      return false;
    }
    try {
      await _controlSub?.cancel();
      _controlSub = UniversalBle.characteristicValueStream(deviceId, controlPointUuid).listen((bytes) {
        if (g != _geracao) return;
        final r = parseControlResponse(bytes);
        log?.add(r == null ? 'resposta crua ${emHex(bytes)}' : 'resposta: ${describeControlResponse(r)}');
        if (r != null && !_respostas.isClosed) _respostas.add(r);
      });
      await UniversalBle.subscribeIndications(deviceId, ftmsServiceUuid, controlPointUuid);
    } catch (e) {
      log?.add('erro ao preparar o começar: $e');
      return false;
    }
    var aceitou = false;
    late final SessionStarter inicio;
    inicio = SessionStarter(
      send: () async {
        if (g != _geracao) return inicio.stop();
        log?.add(
          inicio.tries == 1
              ? 'pedindo para a bike começar'
              : 'a bike ainda não confirmou: pedindo de novo (${inicio.tries}.ª vez)',
        );
        try {
          final r = await startSession(
            write: (c) => UniversalBle.write(deviceId, ftmsServiceUuid, controlPointUuid, c),
            responses: _respostas.stream,
          );
          if (r == null) log?.add('a bike não respondeu ao começar');
          aceitou = r?.ok ?? false;
        } catch (e) {
          if (g == _geracao) log?.add('erro ao mandar começar: $e');
        }
      },
    );
    _inicio = inicio;
    await inicio.start();
    return aceitou;
  }

  /// Só para o diário: os avisos de estado do FTMS e os canais próprios da FitShow (fff0 e ffe0),
  /// que é quem faz o Bluetooth da Winnek. Se o giro vier por lá, o diário mostra.
  Future<void> _escutarAvisos(List<BleService> services, int g) async {
    for (final s in _extras) {
      await s.cancel();
    }
    _extras.clear();
    for (final servico in services) {
      final s = _curto(servico.uuid);
      for (final c in servico.characteristics) {
        final ch = _curto(c.uuid);
        final String Function(Uint8List)? linha = switch ((s, ch)) {
          ('1826', '2ada') => (b) => 'estado da bike: ${describeMachineStatus(b)} (${emHex(b)})',
          ('1826', '2ad3') => (b) => 'fase do treino no painel: ${emHex(b)}',
          ('fff0' || 'ffe0', _) => (b) => 'fitshow $ch: ${emHex(b)}',
          _ => null,
        };
        final avisa = c.properties.contains(CharacteristicProperty.notify);
        if (linha == null || !(avisa || c.properties.contains(CharacteristicProperty.indicate))) continue;
        try {
          _extras.add(
            UniversalBle.characteristicValueStream(deviceId, c.uuid).listen((b) {
              if (g != _geracao) return;
              log?.add(linha(b));
              // O painel avisou que começou: não precisa mais insistir.
              if (ch == '2ada' && b.isNotEmpty && b[0] == 0x04) _inicio?.confirm();
            }),
          );
          if (avisa) {
            await UniversalBle.subscribeNotifications(deviceId, servico.uuid, c.uuid);
          } else {
            await UniversalBle.subscribeIndications(deviceId, servico.uuid, c.uuid);
          }
        } catch (e) {
          log?.add('não deu para escutar $s/$ch: $e');
        }
      }
    }
  }

  /// Lê o que a bike aceita de comandos. Qualquer falha = sem controle (só dados). [comecou] = a bike
  /// já aceitou o controle e o começar (não precisa pedir de novo antes do primeiro comando).
  Future<FtmsControl?> _lerControle(List<BleService> services, {bool comecou = false}) async {
    try {
      final ftms = services.firstWhere((s) => s.uuid.toLowerCase() == ftmsServiceUuid);
      final caracts = ftms.characteristics.map((c) => c.uuid.toLowerCase()).toSet();
      if (!caracts.contains(fitnessMachineFeatureUuid) || !caracts.contains(controlPointUuid)) return null;
      final recursos = parseFeatures(await UniversalBle.read(deviceId, ftmsServiceUuid, fitnessMachineFeatureUuid));
      if (!recursos.any) return null;
      FtmsRange? faixa;
      if (recursos.resistance && caracts.contains(supportedResistanceRangeUuid)) {
        faixa = parseResistanceRange(await UniversalBle.read(deviceId, ftmsServiceUuid, supportedResistanceRangeUuid));
      }
      if (!UniversalBle.isSubscribed(deviceId, controlPointUuid)) {
        await UniversalBle.subscribeIndications(deviceId, ftmsServiceUuid, controlPointUuid);
      }
      return FtmsControl(deviceId, recursos, faixa, comControle: comecou);
    } catch (e) {
      log?.add('controle: erro ao ler ($e)');
      return null;
    }
  }

  void _onValue(Uint8List bytes) {
    log?.packet(bytes);
    // A bike pode mandar uma leitura em pedaços (bit "More Data"): junta antes de usar.
    final d = _montador.add(parseIndoorBikeData(bytes), DateTime.now());
    // Giro, potência ou velocidade chegando = a bike começou de verdade: não precisa insistir.
    if ((d.cadence ?? 0) > 0 || (d.power ?? 0) > 0 || (d.speedKmh ?? 0) > 0) _inicio?.confirm();
    if (_readings.isClosed) return;
    _readings.add(BikeReading(
      cadence: d.cadence,
      power: d.power,
      speedKmh: d.speedKmh,
      heartRate: d.heartRate,
      resistance: d.resistance,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> disconnect() async {
    _manual = true;
    _geracao++;
    _inicio?.stop();
    _inicio = null;
    log?.add('desconectada pelo app');
    await _control?.release();
    _control = null;
    await _valueSub?.cancel();
    _valueSub = null;
    await _controlSub?.cancel();
    _controlSub = null;
    for (final s in _extras) {
      await s.cancel();
    }
    _extras.clear();
    try {
      await UniversalBle.disconnect(deviceId);
    } catch (_) {
      // já estava desconectada
    }
    _set(BikeConnection.desconectada);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await log?.flush();
    await _connSub?.cancel();
    await _readings.close();
    await _connection.close();
    await _respostas.close();
  }
}

/// Comandos FTMS pela característica Control Point: pede o controle uma vez e depois manda os alvos.
class FtmsControl implements BikeControl {
  FtmsControl(this._deviceId, this.features, this.resistanceRange, {this._comControle = false});

  final String _deviceId;

  @override
  final FtmsFeatures features;

  @override
  final FtmsRange? resistanceRange;

  bool _comControle;

  Future<bool> _send(Uint8List comando) async {
    try {
      if (!_comControle) {
        await UniversalBle.write(_deviceId, ftmsServiceUuid, controlPointUuid, requestControlCommand());
        await UniversalBle.write(_deviceId, ftmsServiceUuid, controlPointUuid, startCommand());
        _comControle = true;
      }
      await UniversalBle.write(_deviceId, ftmsServiceUuid, controlPointUuid, comando);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setPower(int watts) async => features.power && await _send(targetPowerCommand(watts));

  @override
  Future<bool> setResistance(double level) async {
    if (!features.resistance) return false;
    final r = resistanceRange;
    return _send(targetResistanceCommand(r == null ? level : level.clamp(r.min, r.max).toDouble()));
  }

  @override
  Future<bool> setGrade(double grade) async => features.simulation && await _send(simulationCommand(grade));

  @override
  Future<void> release() async {
    if (!_comControle) return;
    _comControle = false;
    try {
      await UniversalBle.write(_deviceId, ftmsServiceUuid, controlPointUuid, resetCommand());
    } catch (_) {}
  }
}
