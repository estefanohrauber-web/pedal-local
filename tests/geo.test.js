import { test } from 'node:test';
import assert from 'node:assert/strict';
import { haversine, cumulativeDistances, pointAt, resample } from '../src/route/geo.js';
import { northLine, assertNear, M_PER_DEG_LAT } from './helpers.js';

test('haversine: 1 grau de latitude ≈ 111,2 km', () => {
  assertNear(haversine([0, 0], [1, 0]), 111195, 1);
});

test('haversine: mesmo ponto = 0', () => {
  assert.equal(haversine([-23.5, -46.6], [-23.5, -46.6]), 0);
});

test('cumulativeDistances acumula os trechos', () => {
  const cum = cumulativeDistances(northLine(3, 20));
  assert.equal(cum.length, 3);
  assert.equal(cum[0], 0);
  assertNear(cum[1], 20, 0.01);
  assertNear(cum[2], 40, 0.01);
});

test('pointAt interpola no meio e limita nas pontas', () => {
  const pts = northLine(2, 100);
  const cum = cumulativeDistances(pts);
  const meio = pointAt(pts, cum, 50);
  assertNear(meio[0], pts[0][0] + 50 / M_PER_DEG_LAT, 1e-9);
  const depois = pointAt(pts, cum, 500);
  assertNear(depois[0], pts[1][0], 1e-9);
  assertNear(depois[1], pts[1][1], 1e-9);
  assert.deepEqual(pointAt(pts, cum, -5), pts[0]);
});

test('resample: linha de 100 m vira 6 pontos a cada 20 m', () => {
  const out = resample(northLine(2, 100), 20);
  assert.equal(out.length, 6);
  const cum = cumulativeDistances(out);
  for (let i = 1; i < out.length; i++) assertNear(cum[i] - cum[i - 1], 20, 0.01);
});

test('resample: linha curta mantém início e fim', () => {
  const pts = northLine(2, 15);
  const out = resample(pts, 20);
  assert.equal(out.length, 2);
  assert.deepEqual(out[0], pts[0]);
  assert.deepEqual(out[1], pts[1]);
});

test('resample: último trecho nunca fica minúsculo', () => {
  const out = resample(northLine(2, 101), 20);
  const cum = cumulativeDistances(out);
  assert.ok(cum.at(-1) - cum.at(-2) >= 10);
});
