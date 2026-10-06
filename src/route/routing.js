// Traça o caminho pelas ruas entre os pontos tocados (OSRM, perfil bicicleta).
export const OSRM_URL = 'https://routing.openstreetmap.de/routed-bike/route/v1/driving/';

export class RouteError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'RouteError';
    this.code = code;
  }
}

const defaultFetch = (...args) => globalThis.fetch(...args);

export async function fetchRoute(waypoints, fetchFn = defaultFetch) {
  if (waypoints.length < 2) {
    throw new RouteError('poucos-pontos', 'Toque pelo menos dois pontos no mapa.');
  }
  const coords = waypoints.map(([lat, lon]) => `${lon.toFixed(6)},${lat.toFixed(6)}`).join(';');

  let res;
  try {
    res = await fetchFn(`${OSRM_URL}${coords}?overview=full&geometries=geojson`);
  } catch {
    throw new RouteError('sem-conexao', 'Sem conexão — não deu para traçar a rota.');
  }

  let data = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }
  const semCaminho =
    data?.code === 'NoRoute' || data?.code === 'NoSegment' || (data?.code === 'Ok' && !data.routes?.length);
  if (semCaminho) {
    throw new RouteError('sem-caminho', 'Não encontrei caminho entre esses pontos.');
  }
  if (!res.ok || data?.code !== 'Ok') {
    throw new RouteError('servico', 'O serviço de rotas não respondeu. Tente de novo em instantes.');
  }
  return data.routes[0].geometry.coordinates.map(([lon, lat]) => [lat, lon]);
}
