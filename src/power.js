// Potência usada na simulação: a da bike, ou estimada pela cadência e pelo nível de carga.
export const DEFAULT_CALIBRATION = { base: 0.6, factor: 0.25 };
export const FALLBACK_AFTER_MS = 10000;

export function estimatePower(cadence, level, calibration = DEFAULT_CALIBRATION) {
  if (!(cadence > 0)) return 0;
  return Math.round(cadence * (calibration.base + calibration.factor * level));
}

// mode: 'auto' | 'bike' | 'estimada'
export function createPowerResolver({ mode = 'auto', calibration = DEFAULT_CALIBRATION } = {}) {
  let effective = mode === 'estimada' ? 'estimada' : 'bike';
  let missingSince = null;
  let switched = false;

  return {
    get effectiveMode() {
      return effective;
    },
    get switchedToEstimate() {
      return switched;
    },
    resolve({ cadence, power, timestamp }, level) {
      if (!(cadence > 0)) {
        missingSince = null;
        return 0;
      }
      const hasPower = power != null && power > 0;
      if (mode === 'auto' && effective === 'bike') {
        if (hasPower) missingSince = null;
        else if (missingSince == null) missingSince = timestamp;
        else if (timestamp - missingSince >= FALLBACK_AFTER_MS) {
          effective = 'estimada';
          switched = true;
        }
      }
      if (effective === 'estimada') return estimatePower(cadence, level, calibration);
      if (hasPower) return power;
      return mode === 'auto' ? estimatePower(cadence, level, calibration) : 0;
    },
  };
}
