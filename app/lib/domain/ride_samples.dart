import 'dart:typed_data';

import 'ride_session.dart';

const _fields = 6; // t, distância, velocidade, potência, cadência, FC

/// Amostras em float32 compactados, para guardar no banco.
Uint8List packSamples(List<RideSample> samples) {
  final data = Float32List(samples.length * _fields);
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i];
    final o = i * _fields;
    data[o] = s.t;
    data[o + 1] = s.distance;
    data[o + 2] = s.speedKmh;
    data[o + 3] = s.power;
    data[o + 4] = s.cadence;
    data[o + 5] = s.heartRate ?? double.nan;
  }
  return data.buffer.asUint8List();
}

List<RideSample> unpackSamples(Uint8List bytes) {
  final copy = Uint8List.fromList(bytes); // garante alinhamento de 4 bytes
  final data = copy.buffer.asFloat32List(0, copy.lengthInBytes ~/ 4);
  return [
    for (var o = 0; o + _fields <= data.length; o += _fields)
      RideSample(
        t: data[o],
        distance: data[o + 1],
        speedKmh: data[o + 2],
        power: data[o + 3],
        cadence: data[o + 4],
        heartRate: data[o + 5].isNaN ? null : data[o + 5],
      ),
  ];
}
