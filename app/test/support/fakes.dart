import 'dart:async';

import 'package:pedal_local/bike/bike_control.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/voice.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/domain/ftms_control.dart';

class FakeBikeSource implements BikeSource {
  FakeBikeSource({this.name = 'Bike de teste'});

  @override
  final String name;

  @override
  bool get simulated => false;

  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  BikeConnection _state = BikeConnection.desconectada;

  @override
  BikeControl? control;
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

/// Controle de teste: guarda os comandos recebidos.
class FakeBikeControl implements BikeControl {
  FakeBikeControl([this.features = const FtmsFeatures(power: true)]);

  @override
  final FtmsFeatures features;

  @override
  FtmsRange? get resistanceRange => null;

  final powers = <int>[];
  final grades = <double>[];
  int releases = 0;

  @override
  Future<bool> setPower(int watts) async {
    if (!features.power) return false;
    powers.add(watts);
    return true;
  }

  @override
  Future<bool> setResistance(double level) async => false;

  @override
  Future<bool> setGrade(double grade) async {
    if (!features.simulation) return false;
    grades.add(grade);
    return true;
  }

  @override
  Future<void> release() async => releases++;
}

/// Voz de teste: guarda o que foi falado.
class FakeVoice implements Voice {
  FakeVoice({this.voices = const []});

  final spoken = <String>[];
  int stops = 0;

  /// Vozes que o “celular” tem.
  final List<VoiceOption> voices;

  /// Ids passados para [choose], em ordem.
  final chosen = <String?>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<List<VoiceOption>> options() async => voices;

  @override
  Future<void> choose(String? id) async => chosen.add(id);
}

/// Deixa timers de zero segundos e eventos de stream acontecerem.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
