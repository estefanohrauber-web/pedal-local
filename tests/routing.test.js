import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchRoute, RouteError, OSRM_URL } from '../src/route/routing.js';
import { fakeFetch, jsonResponse } from './helpers.js';

const dois = [[-23.5, -46.6], [-23.51, -46.61]];

const rejeita = (promise, code) =>
  assert.rejects(promise, (e) => e instanceof RouteError && e.code === code);

test('monta a URL como lon,lat e devolve [lat, lon]', async () => {
  const fetchFn = fakeFetch(() =>
    jsonResponse({
      code: 'Ok',
      routes: [{ geometry: { coordinates: [[-46.6, -23.5], [-46.61, -23.51]] } }],
    }),
  );
  const linha = await fetchRoute(dois, fetchFn);
  assert.deepEqual(linha, dois);
  assert.equal(
    fetchFn.calls[0],
    `${OSRM_URL}-46.600000,-23.500000;-46.610000,-23.510000?overview=full&geometries=geojson`,
  );
});

test('menos de dois pontos', () =>
  rejeita(fetchRoute([[0, 0]], fakeFetch(() => jsonResponse({}))), 'poucos-pontos'));

test('sem conexão', () =>
  rejeita(
    fetchRoute(dois, async () => {
      throw new TypeError('Failed to fetch');
    }),
    'sem-conexao',
  ));

test('sem caminho entre os pontos', () =>
  rejeita(fetchRoute(dois, fakeFetch(() => jsonResponse({ code: 'NoRoute' }, 400))), 'sem-caminho'));

test('ponto longe de qualquer rua', () =>
  rejeita(fetchRoute(dois, fakeFetch(() => jsonResponse({ code: 'NoSegment' }, 400))), 'sem-caminho'));

test('serviço fora do ar', () =>
  rejeita(
    fetchRoute(
      dois,
      fakeFetch(() => ({
        ok: false,
        status: 502,
        json: async () => {
          throw new SyntaxError('html');
        },
      })),
    ),
    'servico',
  ));
