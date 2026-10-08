/// Uma leitura da bike. Campos ausentes = a bike não mandou.
class BikeReading {
  const BikeReading({
    this.cadence,
    this.power,
    this.speedKmh,
    this.heartRate,
    this.resistance,
    required this.timestamp,
  });

  final double? cadence;
  final int? power;
  final double? speedKmh;
  final int? heartRate;

  /// Nível de resistência informado pelo painel, quando ele manda.
  final int? resistance;
  final DateTime timestamp;
}
