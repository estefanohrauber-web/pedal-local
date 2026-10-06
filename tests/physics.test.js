import { test } from 'node:test';
import assert from 'node:assert/strict';
import { stepSpeed, DT, PHYSICS } from '../src/physics.js';

const kmh = (ms) => ms * 3.6;
const rider = { riderMassKg: 75 };

function simulate(v0, inputs, seconds, onStep = () => {}) {
  let v = v0;
  for (let t = 0; t < seconds; t += DT) {
    v = stepSpeed(v, inputs, DT);
    onStep(v);
  }
  return v;
}

test('plano, 150 W: entre 28 e 32 km/h', () => {
  const v = kmh(simulate(0, { ...rider, powerW: 150, grade: 0 }, 300));
  assert.ok(v >= 28 && v <= 32, `${v}`);
});

test('subida de 6 %, 150 W: entre 8 e 12 km/h', () => {
  const v = kmh(simulate(0, { ...rider, powerW: 150, grade: 0.06 }, 300));
  assert.ok(v >= 8 && v <= 12, `${v}`);
});

test('descida de 5 % sem pedalar: passa de 30 km/h', () => {
  const v = kmh(simulate(0, { ...rider, powerW: 0, grade: -0.05 }, 120));
  assert.ok(v > 30, `${v}`);
});

test('plano sem pedalar a partir de 30 km/h: abaixo de 12 km/h em 60 s', () => {
  const v = kmh(simulate(30 / 3.6, { ...rider, powerW: 0, grade: 0 }, 60));
  assert.ok(v < 12, `${v}`);
});

test('subida íngreme sem pedalar: para e nunca fica negativa', () => {
  let min = Infinity;
  const v = simulate(5, { ...rider, powerW: 0, grade: 0.15 }, 10, (x) => {
    min = Math.min(min, x);
  });
  assert.equal(v, 0);
  assert.ok(min >= 0);
});

test('velocidade máxima limitada', () => {
  const v = simulate(0, { ...rider, powerW: 0, grade: -0.2 }, 600);
  assert.ok(v <= PHYSICS.maxSpeedMs);
});
