import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseIndoorBikeData } from '../src/bike/ftms-parser.js';

const pkt = (...bytes) => new Uint8Array(bytes);

test('velocidade e cadência', () => {
  // flags 0x0004: bit 0 = 0 (velocidade presente), bit 2 (cadência)
  const r = parseIndoorBikeData(pkt(0x04, 0x00, 0xc4, 0x09, 0xa0, 0x00));
  assert.deepEqual(r, { speed: 25, cadence: 80, power: null, heartRate: null });
});

test('velocidade, cadência e potência', () => {
  const r = parseIndoorBikeData(pkt(0x44, 0x00, 0xc4, 0x09, 0xa0, 0x00, 0x96, 0x00));
  assert.deepEqual(r, { speed: 25, cadence: 80, power: 150, heartRate: null });
});

test('pula os campos opcionais antes da potência', () => {
  // flags 0x007E: vel. média, cadência, cad. média, distância, resistência, potência
  const r = parseIndoorBikeData(
    pkt(
      0x7e, 0x00,
      0xc4, 0x09, // velocidade 25,00 km/h
      0x10, 0x27, // velocidade média (ignorada)
      0xb4, 0x00, // cadência 90 rpm
      0x00, 0x00, // cadência média
      0x10, 0x27, 0x00, // distância 10000 m
      0x05, 0x00, // resistência 5
      0xc8, 0x00, // potência 200 W
    ),
  );
  assert.deepEqual(r, { speed: 25, cadence: 90, power: 200, heartRate: null });
});

test('bit 0 ligado: sem velocidade', () => {
  // flags 0x0045: More Data, cadência, potência
  const r = parseIndoorBikeData(pkt(0x45, 0x00, 0xa0, 0x00, 0x96, 0x00));
  assert.deepEqual(r, { speed: null, cadence: 80, power: 150, heartRate: null });
});

test('potência negativa (sint16)', () => {
  const r = parseIndoorBikeData(pkt(0x45, 0x00, 0xa0, 0x00, 0xf6, 0xff));
  assert.equal(r.power, -10);
});

test('frequência cardíaca depois da energia', () => {
  // flags 0x0304: velocidade, cadência, energia (5 bytes), FC
  const r = parseIndoorBikeData(pkt(0x04, 0x03, 0xc4, 0x09, 0xa0, 0x00, 1, 0, 2, 0, 3, 142));
  assert.equal(r.cadence, 80);
  assert.equal(r.heartRate, 142);
});

test('pacote cortado não quebra', () => {
  const r = parseIndoorBikeData(pkt(0x44, 0x00, 0xc4, 0x09, 0xa0));
  assert.deepEqual(r, { speed: 25, cadence: null, power: null, heartRate: null });
});

test('aceita DataView', () => {
  const bytes = pkt(0x04, 0x00, 0xc4, 0x09, 0xa0, 0x00);
  assert.equal(parseIndoorBikeData(new DataView(bytes.buffer)).cadence, 80);
});
