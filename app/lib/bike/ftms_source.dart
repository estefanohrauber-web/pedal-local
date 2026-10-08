import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../domain/ftms_control.dart';
import '../domain/ftms_parser.dart';
import 'bike_control.dart';
import 'bike_reading.dart';
import 'bike_source.dart';

/// O aparelho conectou, mas não tem o serviço FTMS. [diagnostic] lista o que ele tem.
class NoFtmsException implements Exception {
  const NoFtmsException(this.diagnostic);

  final String diagnostic;

  @override
  String toString() => 'Sem FTMS\n$diagnostic';
}

/// Bike real pelo Bluetooth, padrão FTMS.
class FtmsSource implements BikeSource {
  FtmsSource({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;
  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<bool>? _connSub;
  BikeConnection _state = BikeConnection.desconectada;
  bool _manual = false;
  FtmsControl? _control;

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
    _manual = false;
    _set(BikeConnection.conectando);
    try {
      await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 15));
      final services = await UniversalBle.discoverServices(deviceId);
      final hasFtms = services.any((s) => s.uuid.toLowerCase() == ftmsServiceUuid);
      if (!hasFtms) {
        final lista = services.map((s) => '  ${s.uuid}').join('\n');
        _manual = true;
        await UniversalBle.disconnect(deviceId);
        _set(BikeConnection.desconectada);
        throw NoFtmsException('Aparelho: $deviceName\nServiços:\n${lista.isEmpty ? '  (nenhum)' : lista}');
      }
      await _valueSub?.cancel();
      _valueSub = UniversalBle.characteristicValueStream(deviceId, indoorBikeDataUuid).listen(_onValue);
      await UniversalBle.subscribeNotifications(deviceId, ftmsServiceUuid, indoorBikeDataUuid);
      await _connSub?.cancel();
      _connSub = UniversalBle.connectionStream(deviceId).listen((connected) {
        if (!connected) _set(_manual ? BikeConnection.desconectada : BikeConnection.caiu);
      });
      _control = await _lerControle(services);
      _set(BikeConnection.conectada);
    } on NoFtmsException {
      rethrow;
    } catch (_) {
      _set(BikeConnection.desconectada);
      rethrow;
    }
  }

  /// Lê o que a bike aceita de comandos. Qualquer falha = sem controle (só dados).
  Future<FtmsControl?> _lerControle(List<BleService> services) async {
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
      await UniversalBle.subscribeIndications(deviceId, ftmsServiceUuid, controlPointUuid);
      return FtmsControl(deviceId, recursos, faixa);
    } catch (_) {
      return null;
    }
  }

  void _onValue(Uint8List bytes) {
    final d = parseIndoorBikeData(bytes);
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
    await _control?.release();
    _control = null;
    await _valueSub?.cancel();
    _valueSub = null;
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
    await _connSub?.cancel();
    await _readings.close();
    await _connection.close();
  }
}

/// Comandos FTMS pela característica Control Point: pede o controle uma vez e depois manda os alvos.
class FtmsControl implements BikeControl {
  FtmsControl(this._deviceId, this.features, this.resistanceRange);

  final String _deviceId;

  @override
  final FtmsFeatures features;

  @override
  final FtmsRange? resistanceRange;

  bool _comControle = false;

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
