import 'dart:math' as math;

/// Constantes do modelo físico (as mesmas do protótipo web).
class PhysicsConstants {
  const PhysicsConstants({
    this.g = 9.81,
    this.rho = 1.225,
    this.cda = 0.32,
    this.crr = 0.005,
    this.bikeMassKg = 10,
    this.maxSpeedMs = 25,
  });

  final double g;
  final double rho; // densidade do ar (kg/m³)
  final double cda; // área frontal × coeficiente de arrasto (m²)
  final double crr; // resistência ao rolamento
  final double bikeMassKg;
  final double maxSpeedMs; // 90 km/h
}

const physics = PhysicsConstants();
const physicsDt = 0.25;

/// Nova velocidade (m/s) depois de [dt] segundos com [powerW] numa [grade] (fração).
double stepSpeed(
  double speedMs, {
  required double powerW,
  required double grade,
  required double riderMassKg,
  double dt = physicsDt,
  PhysicsConstants c = physics,
}) {
  final m = riderMassKg + c.bikeMassKg;
  final theta = math.atan(grade);
  final resist = m * c.g * (math.sin(theta) + c.crr * math.cos(theta)) +
      0.5 * c.rho * c.cda * speedMs * speedMs;
  final drive = powerW / math.max(speedMs, 1.0);
  final accel = (drive - resist) / m;
  var next = (speedMs + accel * dt).clamp(0.0, c.maxSpeedMs).toDouble();
  // Pedalando, o boneco nunca para: com pouca força num morro forte, ele sobe devagar, na
  // velocidade em que a força dá conta do morro (força ÷ peso morro acima). Sem isto, abaixo de
  // 1 m/s a conta acima trata a força como se a bike já andasse a 1 m/s e o boneco empacava em 0.
  if (powerW > 0) {
    final morro = m * c.g * (math.sin(theta) + c.crr * math.cos(theta));
    if (morro > 0) {
      final devagar = powerW / morro;
      if (devagar < 1.0 && next < devagar) next = devagar;
    }
  }
  return next;
}
