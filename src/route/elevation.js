// Altitude de cada ponto (Open-Meteo Elevation API, até 100 coordenadas por chamada).
export const ELEVATION_URL = 'https://api.open-meteo.com/v1/elevation';
export const ELEVATION_BATCH = 100;

const defaultFetch = (...args) => globalThis.fetch(...args);

export async function fetchElevations(points, fetchFn = defaultFetch) {
  const out = [];
  for (let i = 0; i < points.length; i += ELEVATION_BATCH) {
    const lote = points.slice(i, i + ELEVATION_BATCH);
    const lat = lote.map((p) => p[0].toFixed(5)).join(',');
    const lon = lote.map((p) => p[1].toFixed(5)).join(',');
    const res = await fetchFn(`${ELEVATION_URL}?latitude=${lat}&longitude=${lon}`);
    if (!res.ok) throw new Error(`Altimetria indisponível (HTTP ${res.status})`);
    const data = await res.json();
    if (!Array.isArray(data?.elevation) || data.elevation.length !== lote.length) {
      throw new Error('Altimetria: resposta inválida');
    }
    out.push(...data.elevation);
  }
  return out;
}
