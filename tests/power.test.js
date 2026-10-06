import { test } from 'node:test';
import assert from 'node:assert/strict';
import { estimatePower, createPowerResolver } from '../src/power.js';

test('estimatePower: nível 4 a 80 rpm ≈ 128 W', () => {
  assert.equal(estimatePower(80, 4), 128);
});

test('estimatePower: sem cadência = 0', () => {
  assert.equal(estimatePower(0, 4), 0);
  assert.equal(estimatePower(null, 4), 0);
});

test('estimatePower: calibração personalizada', () => {
  assert.equal(estimatePower(80, 4, { base: 1, factor: 0 }), 80);
});

test('modo bike: usa a potência recebida, 0 se não vier', () => {
  const r = createPowerResolver({ mode: 'bike' });
  assert.equal(r.resolve({ cadence: 80, power: 150, timestamp: 0 }, 4), 150);
  assert.equal(r.resolve({ cadence: 80, power: null, timestamp: 1000 }, 4), 0);
});

test('modo estimada: ignora a potência da bike', () => {
  const r = createPowerResolver({ mode: 'estimada' });
  assert.equal(r.resolve({ cadence: 80, power: 300, timestamp: 0 }, 4), 128);
  assert.equal(r.effectiveMode, 'estimada');
});

test('auto com potência válida: usa a da bike', () => {
  const r = createPowerResolver();
  assert.equal(r.resolve({ cadence: 80, power: 150, timestamp: 0 }, 4), 150);
  assert.equal(r.effectiveMode, 'bike');
});

test('auto sem potência por 10 s: troca para estimada de vez', () => {
  const r = createPowerResolver();
  for (let t = 0; t <= 9000; t += 1000) {
    assert.equal(r.resolve({ cadence: 80, power: null, timestamp: t }, 4), 128);
  }
  assert.equal(r.switchedToEstimate, false);
  r.resolve({ cadence: 80, power: 0, timestamp: 10000 }, 4);
  assert.equal(r.switchedToEstimate, true);
  assert.equal(r.effectiveMode, 'estimada');
  assert.equal(r.resolve({ cadence: 80, power: 300, timestamp: 11000 }, 4), 128);
});

test('auto: parar de pedalar zera a contagem dos 10 s', () => {
  const r = createPowerResolver();
  for (let t = 0; t <= 5000; t += 1000) r.resolve({ cadence: 80, power: null, timestamp: t }, 4);
  assert.equal(r.resolve({ cadence: 0, power: null, timestamp: 6000 }, 4), 0);
  for (let t = 7000; t <= 15000; t += 1000) r.resolve({ cadence: 80, power: null, timestamp: t }, 4);
  assert.equal(r.switchedToEstimate, false);
  r.resolve({ cadence: 80, power: null, timestamp: 17000 }, 4);
  assert.equal(r.switchedToEstimate, true);
});
