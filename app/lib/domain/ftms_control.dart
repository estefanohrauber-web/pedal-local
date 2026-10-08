import 'dart:typed_data';

/// Características do FTMS para saber o que a bike aceita e mandar comandos.
const fitnessMachineFeatureUuid = '00002acc-0000-1000-8000-00805f9b34fb';
const supportedResistanceRangeUuid = '00002ad6-0000-1000-8000-00805f9b34fb';
const supportedPowerRangeUuid = '00002ad8-0000-1000-8000-00805f9b34fb';
const controlPointUuid = '00002ad9-0000-1000-8000-00805f9b34fb';

/// O que a bike aceita receber do app (Target Setting Features da característica 0x2ACC).
class FtmsFeatures {
  const FtmsFeatures({this.power = false, this.resistance = false, this.simulation = false});

  /// Segura uma potência alvo sozinha (modo ERG).
  final bool power;

  /// Muda o nível de resistência.
  final bool resistance;

  /// Simula uma inclinação (endurece na subida).
  final bool simulation;

  bool get any => power || resistance || simulation;
}

/// Lê a característica Fitness Machine Feature: 4 bytes de recursos + 4 de alvos aceitos.
FtmsFeatures parseFeatures(Uint8List bytes) {
  if (bytes.length < 8) return const FtmsFeatures();
  final alvos = ByteData.sublistView(bytes).getUint32(4, Endian.little);
  return FtmsFeatures(
    resistance: alvos & (1 << 2) != 0,
    power: alvos & (1 << 3) != 0,
    simulation: alvos & (1 << 13) != 0,
  );
}

/// Faixa aceita: mínimo, máximo e passo.
class FtmsRange {
  const FtmsRange(this.min, this.max, this.step);

  final double min;
  final double max;
  final double step;
}

/// Faixa de resistência (0x2AD6): sint16, sint16, uint16, em décimos.
FtmsRange? parseResistanceRange(Uint8List bytes) {
  if (bytes.length < 6) return null;
  final b = ByteData.sublistView(bytes);
  return FtmsRange(b.getInt16(0, Endian.little) / 10, b.getInt16(2, Endian.little) / 10, b.getUint16(4, Endian.little) / 10);
}

/// Faixa de potência (0x2AD8): sint16, sint16, uint16, em watts.
FtmsRange? parsePowerRange(Uint8List bytes) {
  if (bytes.length < 6) return null;
  final b = ByteData.sublistView(bytes);
  return FtmsRange(
    b.getInt16(0, Endian.little).toDouble(),
    b.getInt16(2, Endian.little).toDouble(),
    b.getUint16(4, Endian.little).toDouble(),
  );
}

// Comandos do Fitness Machine Control Point (0x2AD9).
Uint8List requestControlCommand() => Uint8List.fromList([0x00]);
Uint8List resetCommand() => Uint8List.fromList([0x01]);
Uint8List startCommand() => Uint8List.fromList([0x07]);

Uint8List _comInt16(int opcode, int valor) {
  final b = ByteData(3)
    ..setUint8(0, opcode)
    ..setInt16(1, valor, Endian.little);
  return b.buffer.asUint8List();
}

/// Potência alvo (watts): a bike ajusta a carga para segurar essa potência.
Uint8List targetPowerCommand(int watts) => _comInt16(0x05, watts.clamp(0, 2000));

/// Nível de resistência alvo, em décimos (sint16, como a maioria das bikes FTMS lê).
Uint8List targetResistanceCommand(double level) => _comInt16(0x04, (level * 10).round());

/// Simulação de subida: vento 0, inclinação em centésimos de %, Crr 0,004 e área 0,51.
Uint8List simulationCommand(double grade) {
  final b = ByteData(7)
    ..setUint8(0, 0x11)
    ..setInt16(1, 0, Endian.little)
    ..setInt16(3, (grade * 100 * 100).round().clamp(-4000, 4000), Endian.little)
    ..setUint8(5, 40)
    ..setUint8(6, 51);
  return b.buffer.asUint8List();
}

/// Resposta da bike a um comando: [0x80, comando, resultado]; resultado 1 = deu certo.
class ControlResponse {
  const ControlResponse(this.opcode, this.result);

  final int opcode;
  final int result;

  bool get ok => result == 1;
}

ControlResponse? parseControlResponse(Uint8List bytes) {
  if (bytes.length < 3 || bytes[0] != 0x80) return null;
  return ControlResponse(bytes[1], bytes[2]);
}
