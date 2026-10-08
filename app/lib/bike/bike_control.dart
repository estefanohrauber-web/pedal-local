import '../domain/ftms_control.dart';

/// Comandos para a bike, quando ela aceita (FTMS): segurar uma potência (ERG), mudar o
/// nível de resistência ou simular uma subida.
abstract interface class BikeControl {
  FtmsFeatures get features;
  FtmsRange? get resistanceRange;

  /// Faz a bike segurar [watts] sozinha, qualquer que seja o giro.
  Future<bool> setPower(int watts);
  Future<bool> setResistance(double level);

  /// Inclinação simulada (fração: 0,06 = 6 %).
  Future<bool> setGrade(double grade);

  /// Devolve a carga para o botão da bike (fim do treino).
  Future<void> release();
}
