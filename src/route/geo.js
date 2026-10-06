// Funções geográficas puras sobre polilinhas [[lat, lon], ...].
const EARTH_RADIUS_M = 6371000;
const toRad = (deg) => (deg * Math.PI) / 180;

export function haversine(a, b) {
  const dLat = toRad(b[0] - a[0]);
  const dLon = toRad(b[1] - a[1]);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a[0])) * Math.cos(toRad(b[0])) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function cumulativeDistances(points) {
  const out = [0];
  for (let i = 1; i < points.length; i++) {
    out.push(out[i - 1] + haversine(points[i - 1], points[i]));
  }
  return out;
}

// Índice i do trecho [i, i+1] que contém a distância d (cum é crescente).
export function segmentIndex(cum, d) {
  let lo = 0;
  let hi = cum.length - 2;
  if (hi < 0) return 0;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (cum[mid] <= d) lo = mid;
    else hi = mid - 1;
  }
  return lo;
}

export function pointAt(points, cum, d) {
  if (points.length === 1) return [points[0][0], points[0][1]];
  const total = cum[cum.length - 1];
  const dist = Math.min(Math.max(d, 0), total);
  const i = segmentIndex(cum, dist);
  const seg = cum[i + 1] - cum[i];
  const t = seg > 0 ? (dist - cum[i]) / seg : 0;
  const a = points[i];
  const b = points[i + 1];
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}

// Pontos a cada `step` metros; o último trecho fica entre step/2 e 1,5·step.
export function resample(points, step = 20) {
  if (points.length < 2) return points.map((p) => [p[0], p[1]]);
  const cum = cumulativeDistances(points);
  const total = cum[cum.length - 1];
  const out = [];
  for (let d = 0; d < total - step / 2; d += step) out.push(pointAt(points, cum, d));
  const last = points[points.length - 1];
  out.push([last[0], last[1]]);
  return out;
}
