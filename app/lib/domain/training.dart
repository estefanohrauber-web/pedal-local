import 'dart:math' as math;

/// Uma zona de esforço, em fração do FTP (a potência que dá para manter por uma hora).
class TrainingZone {
  const TrainingZone(this.number, this.name, this.effort, this.from, this.to);

  final int number;
  final String name;

  /// Como o esforço se sente, para quem não quer olhar números.
  final String effort;
  final double from;
  final double to;
}

/// As 7 zonas usadas por Zwift, TrainerRoad e Peloton (modelo de Coggan).
const trainingZones = [
  TrainingZone(1, 'Recuperação', 'Muito leve', 0, 0.55),
  TrainingZone(2, 'Resistência', 'Leve', 0.55, 0.75),
  TrainingZone(3, 'Ritmo', 'Moderado', 0.75, 0.90),
  TrainingZone(4, 'Limiar', 'Forte', 0.90, 1.05),
  TrainingZone(5, 'VO2 máx', 'Muito forte', 1.05, 1.20),
  TrainingZone(6, 'Anaeróbico', 'Quase tudo', 1.20, 1.50),
  TrainingZone(7, 'Sprint', 'Tudo', 1.50, double.infinity),
];

TrainingZone zoneFor(double fraction) =>
    trainingZones.firstWhere((z) => fraction < z.to - 1e-9, orElse: () => trainingZones.last);

/// FTP de partida antes do teste: 2 W por kg, um valor comum para quem está começando.
double defaultFtp(double pesoKg) => (pesoKg * 2).roundToDouble();

/// O ramp test (Zwift, TrainerRoad) dá como FTP 75 % do melhor minuto.
const rampFtpFactor = 0.75;

/// Maior média de [seconds] amostras seguidas (uma por segundo). 0 se não houver tantas.
double bestAverage(List<double> powers, int seconds) {
  if (seconds <= 0 || powers.length < seconds) return 0;
  var soma = 0.0;
  for (var i = 0; i < seconds; i++) {
    soma += powers[i];
  }
  var melhor = soma;
  for (var i = seconds; i < powers.length; i++) {
    soma += powers[i] - powers[i - seconds];
    melhor = math.max(melhor, soma);
  }
  return melhor / seconds;
}

/// FTP do ramp test a partir das potências de 1 s.
double rampTestFtp(List<double> powers) => (bestAverage(powers, 60) * rampFtpFactor).roundToDouble();
