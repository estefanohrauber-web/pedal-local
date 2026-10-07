import 'dart:async';

import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/wake_lock.dart';

class FakeBikeSource implements BikeSource {
  FakeBikeSource({this.name = 'Bike de teste'});

  @override
  final String name;

  @override
  bool get simulated => false;

  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  BikeConnection _state = BikeConnection.desconectada;
  int connectCalls = 0;
  int failNext = 0;
  Exception? failWith;
  bool disposed = false;

  @override
  Stream<BikeReading> get readings => _readings.stream;

  @override
  Stream<BikeConnection> get connection => _connection.stream;

  @override
  BikeConnection get state => _state;

  void emitConnection(BikeConnection c) {
    _state = c;
    _connection.add(c);
  }

  void emitReading(BikeReading r) => _readings.add(r);

  @override
  Future<void> connect() async {
    connectCalls++;
    final f = failWith;
    if (f != null) throw f;
    if (failNext > 0) {
      failNext--;
      emitConnection(BikeConnection.desconectada);
      throw Exception('falhou');
    }
    emitConnection(BikeConnection.conectada);
  }

  @override
  Future<void> disconnect() async => emitConnection(BikeConnection.desconectada);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _readings.close();
    await _connection.close();
  }
}

class FakeWakeLock implements WakeLock {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

/// Deixa timers de zero segundos e eventos de stream acontecerem.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
