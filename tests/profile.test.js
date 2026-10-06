import { test } from 'node:test';
import assert from 'node:assert/strict';
import { smoothElevations, createProfile, MAX_GRADE } from '../src/route/profile.js';
import { northLine, assertNear } from './helpers.js';

test('smoothElevations: média móvel centrada', () => {
  const out = smoothElevations([0, 0, 10, 0, 0], 3);
  [0, 10 / 3, 10 / 3, 10 / 3, 0].forEach((v, i) => assertNear(out[i], v, 1e-9));
});

test('smoothElevations: altitude constante não muda', () => {
  assert.deepEqual(smoothElevations([5, 5, 5, 5, 5, 5]), [5, 5, 5, 5, 5, 5]);
});

// 5 % nos primeiros 100 m, depois plano.
const ALTS = [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5];
const perfil = () => createProfile(northLine(11, 20, ALTS));

test('createProfile: totais', () => {
  const p = perfil();
  assertNear(p.distance, 200, 0.05);
  assertNear(p.gain, 5, 1e-9);
  assert.equal(p.loss, 0);
});

test('createProfile: inclinação por trecho', () => {
  const p = perfil();
  assertNear(p.gradeAt(10), 0.05, 1e-4);
  assertNear(p.gradeAt(150), 0, 1e-9);
  assertNear(p.gradeAt(999), 0, 1e-9);
});

test('createProfile: lookahead é a inclinação média à frente', () => {
  const p = perfil();
  assertNear(p.lookahead(0, 100), 0.05, 1e-4);
  assertNear(p.lookahead(50, 100), 0.025, 1e-4);
  assertNear(p.lookahead(100, 100), 0, 1e-4);
  assert.equal(p.lookahead(200, 200), 0);
});

test('createProfile: altitude e posição interpoladas', () => {
  const p = perfil();
  assertNear(p.elevationAt(30), 1.5, 1e-4);
  const pts = northLine(11, 20);
  const pos = p.positionAt(40);
  assertNear(pos[0], pts[2][0], 1e-9);
  assertNear(pos[1], pts[2][1], 1e-9);
});

test('createProfile: inclinação limitada a ±20 %', () => {
  assert.equal(createProfile(northLine(2, 20, [0, 10])).gradeAt(5), MAX_GRADE);
  assert.equal(createProfile(northLine(2, 20, [10, 0])).gradeAt(5), -MAX_GRADE);
});

test('createProfile: rota de um ponto só não quebra', () => {
  const p = createProfile(northLine(1, 20, [7]));
  assert.equal(p.distance, 0);
  assert.equal(p.gradeAt(0), 0);
  assert.equal(p.lookahead(0), 0);
  assert.equal(p.elevationAt(0), 7);
});
