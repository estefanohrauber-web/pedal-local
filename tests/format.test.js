import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatNumber, formatKm, formatTime } from '../src/ui/format.js';

test('formatNumber usa vírgula e ponto do pt-BR', () => {
  assert.equal(formatNumber(1234.5, 1), '1.234,5');
  assert.equal(formatNumber(7.25, 0), '7');
});

test('formatNumber não mostra "-0"', () => {
  assert.equal(formatNumber(-0.2, 0), '0');
  assert.equal(formatNumber(-0.04, 1), '0,0');
});

test('formatKm', () => {
  assert.equal(formatKm(1234), '1,23 km');
});

test('formatTime', () => {
  assert.equal(formatTime(0), '0:00');
  assert.equal(formatTime(65.9), '1:05');
  assert.equal(formatTime(3725), '1:02:05');
});
