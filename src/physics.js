// Modelo físico simples de ciclismo: velocidade virtual a partir de potência e inclinação.
export const PHYSICS = {
  g: 9.81,
  rho: 1.225, // densidade do ar (kg/m³)
  cda: 0.32, // área frontal × coeficiente de arrasto (m²)
  crr: 0.005, // resistência ao rolamento
  bikeMassKg: 10,
  maxSpeedMs: 25, // 90 km/h
};

export const DT = 0.25;

export function stepSpeed(speedMs, { powerW, grade, riderMassKg }, dt = DT, c = PHYSICS) {
  const m = riderMassKg + c.bikeMassKg;
  const theta = Math.atan(grade);
  const resist =
    m * c.g * (Math.sin(theta) + c.crr * Math.cos(theta)) +
    0.5 * c.rho * c.cda * speedMs * speedMs;
  const drive = powerW / Math.max(speedMs, 1);
  const accel = (drive - resist) / m;
  return Math.min(c.maxSpeedMs, Math.max(0, speedMs + accel * dt));
}
