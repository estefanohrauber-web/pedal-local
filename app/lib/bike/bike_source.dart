import 'bike_reading.dart';

enum BikeConnection { desconectada, conectando, conectada, caiu }

/// Fonte de dados da bike: real (FTMS) ou simulada.
abstract class BikeSource {
  String get name;
  bool get simulated;
  Stream<BikeReading> get readings;
  Stream<BikeConnection> get connection;
  BikeConnection get state;
  Future<void> connect();
  Future<void> disconnect();

  /// Desconecta e fecha os streams; a fonte não pode mais ser usada.
  Future<void> dispose();
}
