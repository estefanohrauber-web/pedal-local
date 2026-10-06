// Pontos tocados no mapa → rota pronta para salvar (o nome é dado depois).
import { fetchRoute } from './routing.js';
import { fetchElevations } from './elevation.js';
import { resample } from './geo.js';
import { smoothElevations, createProfile } from './profile.js';

export const SAMPLE_STEP_M = 20;

const defaultFetch = (...args) => globalThis.fetch(...args);
const round = (x, casas) => Math.round(x * 10 ** casas) / 10 ** casas;

export async function buildRoute({ waypoints, fetchFn = defaultFetch, now = () => new Date() }) {
  const linha = await fetchRoute(waypoints, fetchFn);
  const amostras = resample(linha, SAMPLE_STEP_M);

  let alts;
  let semAltimetria = false;
  try {
    alts = smoothElevations(await fetchElevations(amostras, fetchFn));
  } catch {
    alts = amostras.map(() => 0);
    semAltimetria = true;
  }

  const pontos = amostras.map(([lat, lon], i) => [round(lat, 6), round(lon, 6), round(alts[i], 1)]);
  const perfil = createProfile(pontos);
  const data = now();
  return {
    semAltimetria,
    route: {
      id: `r${data.getTime().toString(36)}${Math.random().toString(36).slice(2, 6)}`,
      nome: '',
      criadaEm: data.toISOString(),
      waypoints,
      pontos,
      distanciaM: Math.round(perfil.distance),
      ganhoM: Math.round(perfil.gain),
      perdaM: Math.round(perfil.loss),
    },
  };
}
