// Perfil de relevo: inclinação por trecho, totais e consultas por distância percorrida.
import { cumulativeDistances, segmentIndex, pointAt } from './geo.js';

export const MAX_GRADE = 0.2;
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));

export function smoothElevations(alts, window = 5) {
  const half = Math.floor(window / 2);
  return alts.map((_, i) => {
    let sum = 0;
    let n = 0;
    for (let j = Math.max(0, i - half); j <= Math.min(alts.length - 1, i + half); j++) {
      sum += alts[j];
      n++;
    }
    return sum / n;
  });
}

// pontos: [[lat, lon, altitude], ...] já reamostrados e suavizados.
export function createProfile(pontos) {
  const latlons = pontos.map((p) => [p[0], p[1]]);
  const alts = pontos.map((p) => p[2] ?? 0);
  const cum = cumulativeDistances(latlons);
  const distance = cum[cum.length - 1] ?? 0;
  const grades = [];
  let gain = 0;
  let loss = 0;
  for (let i = 0; i < pontos.length - 1; i++) {
    const run = cum[i + 1] - cum[i];
    const rise = alts[i + 1] - alts[i];
    grades.push(run > 0 ? clamp(rise / run, -MAX_GRADE, MAX_GRADE) : 0);
    if (rise > 0) gain += rise;
    else loss -= rise;
  }

  function elevationAt(d) {
    if (alts.length < 2) return alts[0] ?? 0;
    const x = clamp(d, 0, distance);
    const i = segmentIndex(cum, x);
    const seg = cum[i + 1] - cum[i];
    const t = seg > 0 ? (x - cum[i]) / seg : 0;
    return alts[i] + (alts[i + 1] - alts[i]) * t;
  }

  return {
    distance,
    gain,
    loss,
    cum,
    alts,
    elevationAt,
    gradeAt(d) {
      return grades.length ? grades[segmentIndex(cum, clamp(d, 0, distance))] : 0;
    },
    lookahead(d, span = 200) {
      const start = clamp(d, 0, distance);
      const end = Math.min(distance, start + span);
      return end - start > 1 ? (elevationAt(end) - elevationAt(start)) / (end - start) : 0;
    },
    positionAt(d) {
      return latlons.length ? pointAt(latlons, cum, d) : [0, 0];
    },
  };
}
