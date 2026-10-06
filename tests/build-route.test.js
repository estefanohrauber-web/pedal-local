import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildRoute } from '../src/route/build-route.js';
import { OSRM_URL } from '../src/route/routing.js';
import { northLine, fakeFetch, jsonResponse } from './helpers.js';

const [a, b] = northLine(2, 100);
const osrm = () =>
  jsonResponse({
    code: 'Ok',
    routes: [{ geometry: { coordinates: [[a[1], a[0]], [b[1], b[0]]] } }],
  });

test('monta rota com pontos a cada 20 m e altimetria suavizada', async () => {
  const fetchFn = fakeFetch((url) => {
    if (url.startsWith(OSRM_URL)) return osrm();
    const k = new URL(url).searchParams.get('latitude').split(',').length;
    return jsonResponse({ elevation: Array.from({ length: k }, (_, i) => i * 2) });
  });
  const { route, semAltimetria } = await buildRoute({
    waypoints: [a, b],
    fetchFn,
    now: () => new Date('2026-10-06T12:00:00Z'),
  });
  assert.equal(semAltimetria, false);
  assert.equal(route.pontos.length, 6);
  assert.equal(route.distanciaM, 100);
  assert.equal(route.criadaEm, '2026-10-06T12:00:00.000Z');
  assert.equal(route.ganhoM, 6);
  assert.equal(route.perdaM, 0);
  assert.equal(route.nome, '');
  assert.deepEqual(route.waypoints, [a, b]);
});

test('sem altimetria: rota plana com aviso', async () => {
  const fetchFn = fakeFetch((url) => (url.startsWith(OSRM_URL) ? osrm() : jsonResponse({}, 500)));
  const { route, semAltimetria } = await buildRoute({ waypoints: [a, b], fetchFn });
  assert.equal(semAltimetria, true);
  assert.ok(route.pontos.every((p) => p[2] === 0));
});

test('erro de rota sobe para quem chamou', async () => {
  await assert.rejects(buildRoute({ waypoints: [a], fetchFn: fakeFetch(osrm) }), {
    code: 'poucos-pontos',
  });
});
