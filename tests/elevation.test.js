import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchElevations } from '../src/route/elevation.js';
import { fakeFetch, jsonResponse } from './helpers.js';

const latCount = (url) => new URL(url).searchParams.get('latitude').split(',').length;

test('busca em lotes de 100 e mantém a ordem', async () => {
  let n = 0;
  const fetchFn = fakeFetch((url) => {
    const k = latCount(url);
    const base = n;
    n += k;
    return jsonResponse({ elevation: Array.from({ length: k }, (_, i) => base + i) });
  });
  const pts = Array.from({ length: 150 }, (_, i) => [-23.5 + i * 1e-4, -46.6]);
  const alts = await fetchElevations(pts, fetchFn);
  assert.equal(fetchFn.calls.length, 2);
  assert.equal(latCount(fetchFn.calls[0]), 100);
  assert.deepEqual(alts, Array.from({ length: 150 }, (_, i) => i));
});

test('resposta com tamanho errado falha', async () => {
  await assert.rejects(
    fetchElevations([[0, 0], [0, 1]], fakeFetch(() => jsonResponse({ elevation: [1] }))),
  );
});

test('HTTP de erro falha', async () => {
  await assert.rejects(fetchElevations([[0, 0]], fakeFetch(() => jsonResponse({}, 429))));
});
