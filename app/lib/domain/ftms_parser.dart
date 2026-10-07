import 'dart:typed_data';

/// Serviço Fitness Machine (FTMS) e característica Indoor Bike Data, em UUID de 128 bits.
const ftmsServiceUuid = '00001826-0000-1000-8000-00805f9b34fb';
const indoorBikeDataUuid = '00002ad2-0000-1000-8000-00805f9b34fb';

class IndoorBikeData {
  const IndoorBikeData({this.speedKmh, this.cadence, this.power, this.heartRate});

  final double? speedKmh;
  final double? cadence;
  final int? power;
  final int? heartRate;

  @override
  bool operator ==(Object other) =>
      other is IndoorBikeData &&
      other.speedKmh == speedKmh &&
      other.cadence == cadence &&
      other.power == power &&
      other.heartRate == heartRate;

  @override
  int get hashCode => Object.hash(speedKmh, cadence, power, heartRate);

  @override
  String toString() => 'IndoorBikeData(speed: $speedKmh, cadence: $cadence, power: $power, hr: $heartRate)';
}

/// Decodifica Indoor Bike Data (0x2AD2). Os campos vêm na ordem da especificação e cada
/// flag diz se o campo está presente. O bit 0 é invertido: 0 = velocidade presente.
IndoorBikeData parseIndoorBikeData(Uint8List bytes) {
  if (bytes.length < 2) return const IndoorBikeData();
  final view = ByteData.sublistView(bytes);
  final flags = view.getUint16(0, Endian.little);
  bool has(int bit) => (flags & (1 << bit)) != 0;

  double? speed;
  double? cadence;
  int? power;
  int? heartRate;

  // (presente, tamanho em bytes, leitura — null = só pular)
  final fields = <(bool, int, void Function(int)?)>[
    (!has(0), 2, (at) => speed = view.getUint16(at, Endian.little) / 100),
    (has(1), 2, null), // velocidade média
    (has(2), 2, (at) => cadence = view.getUint16(at, Endian.little) / 2),
    (has(3), 2, null), // cadência média
    (has(4), 3, null), // distância total
    (has(5), 2, null), // nível de resistência
    (has(6), 2, (at) => power = view.getInt16(at, Endian.little)),
    (has(7), 2, null), // potência média
    (has(8), 5, null), // energia: total, por hora, por minuto
    (has(9), 1, (at) => heartRate = view.getUint8(at)),
  ];

  var offset = 2;
  for (final (present, size, read) in fields) {
    if (!present) continue;
    if (offset + size > bytes.length) break;
    read?.call(offset);
    offset += size;
  }
  return IndoorBikeData(speedKmh: speed, cadence: cadence, power: power, heartRate: heartRate);
}
