import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createSimSource } from '../src/bike/sim-source.js';
import { assertNear } from './helpers.js';

const neutra = () => createSimSource({ random: () => 0.5, now: () => 1000 });

function amostrar(sim, n) {
  let s;
  for (let i = 0; i < n; i++) s = sim.sample();
  return s;
}

test('converge para a potência alvo com cadência plausível', () => {
  const s = amostrar(neutra(), 20);
  assertNear(s.power, 150, 1);
  assert.ok(s.cadence >= 70 && s.cadence <= 90, `${s.cadence}`);
  assert.equal(s.timestamp, 1000);
});

test('mais forte e mais fraco mudam o alvo', () => {
  const sim = neutra();
  sim.harder();
  sim.harder();
  assert.equal(sim.target, 200);
  assertNear(amostrar(sim, 20).power, 200, 1);
  for (let i = 0; i < 10; i++) sim.easier();
  assert.equal(sim.target, 0);
  const parado = amostrar(sim, 20);
  assert.equal(parado.power, 0);
  assert.equal(parado.cadence, 0);
  for (let i = 0; i < 30; i++) sim.harder();
  assert.equal(sim.target, 400);
});

test('connect e disconnect controlam o estado', async () => {
  const sim = createSimSource({ intervalMs: 5 });
  const recebidos = [];
  sim.onData((d) => recebidos.push(d));
  await sim.connect();
  assert.equal(sim.connected, true);
  await new Promise((r) => setTimeout(r, 30));
  sim.disconnect();
  assert.equal(sim.connected, false);
  assert.ok(recebidos.length > 0);
});
