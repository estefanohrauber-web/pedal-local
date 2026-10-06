import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRide } from '../src/ride.js';
import { assertNear } from './helpers.js';

function fakeProfile({ distance = 5000, grade = () => 0, ahead = () => 0 } = {}) {
  return { distance, gradeAt: grade, lookahead: ahead, positionAt: (d) => [d, 0] };
}

function pedal(ride, seconds, alerts = []) {
  for (let i = 0; i < seconds; i++) alerts.push(...ride.advance(1));
  return alerts;
}

function novaSessao(opcoes) {
  const ride = createRide({ profile: fakeProfile(opcoes), riderMassKg: 75 });
  ride.start();
  return ride;
}

test('antes de começar não anda', () => {
  const ride = createRide({ profile: fakeProfile(), riderMassKg: 75 });
  ride.setInputs({ powerW: 200, cadenceRpm: 85 });
  ride.advance(10);
  assert.equal(ride.state, 'pronto');
  assert.equal(ride.snapshot().distance, 0);
});

test('pedalando no plano avança e ganha velocidade', () => {
  const ride = novaSessao();
  ride.setInputs({ powerW: 150, cadenceRpm: 80 });
  pedal(ride, 60);
  const s = ride.snapshot();
  assert.equal(s.state, 'pedalando');
  assert.ok(s.distance > 300, `${s.distance}`);
  assert.ok(s.speedKmh > 20, `${s.speedKmh}`);
  assert.equal(s.cadence, 80);
  assert.deepEqual(s.position, [s.distance, 0]);
});

test('chega ao fim e conclui', () => {
  const ride = novaSessao({ distance: 100 });
  ride.setInputs({ powerW: 150, cadenceRpm: 80 });
  pedal(ride, 120);
  assert.equal(ride.state, 'concluido');
  assert.equal(ride.snapshot().distance, 100);
});

test('pausar zera a velocidade e congela a distância', () => {
  const ride = novaSessao();
  ride.setInputs({ powerW: 150, cadenceRpm: 80 });
  pedal(ride, 30);
  ride.pause();
  const d = ride.snapshot().distance;
  pedal(ride, 10);
  assert.equal(ride.state, 'pausado');
  assert.equal(ride.snapshot().distance, d);
  assert.equal(ride.snapshot().speedKmh, 0);
  ride.resume();
  pedal(ride, 5);
  assert.ok(ride.snapshot().distance > d);
});

test('aviso de subida só repete depois de passar o trecho', () => {
  const ahead = (d) => (d < 300 ? 0.06 : d < 600 ? 0 : 0.06);
  const ride = novaSessao({ distance: 2000, ahead });
  ride.setInputs({ powerW: 200, cadenceRpm: 85 });
  const alerts = pedal(ride, 400);
  assert.deepEqual(alerts.map((a) => a.tipo), ['subida', 'subida']);
  assert.equal(alerts[0].inclinacao, 0.06);
});

test('aviso de descida', () => {
  const ride = novaSessao({ ahead: () => -0.05 });
  ride.setInputs({ powerW: 100, cadenceRpm: 70 });
  const alerts = pedal(ride, 30);
  assert.deepEqual(alerts.map((a) => a.tipo), ['descida']);
});

test('potência e velocidade médias', () => {
  const ride = novaSessao();
  ride.setInputs({ powerW: 150, cadenceRpm: 80 });
  pedal(ride, 60);
  const s = ride.snapshot();
  assertNear(s.avgPower, 150, 1e-9);
  assert.ok(s.avgSpeedKmh > 15 && s.avgSpeedKmh < s.speedKmh, `${s.avgSpeedKmh}`);
});
