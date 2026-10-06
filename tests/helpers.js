// Utilitários compartilhados pelos testes.
import assert from 'node:assert/strict';

export const M_PER_DEG_LAT = (6371000 * Math.PI) / 180;

// Linha reta para o norte com `count` pontos espaçados `spacingM` metros.
export function northLine(count, spacingM, altitudes = null, start = [-23.5, -46.6]) {
  return Array.from({ length: count }, (_, i) => {
    const p = [start[0] + (i * spacingM) / M_PER_DEG_LAT, start[1]];
    if (altitudes) p.push(altitudes[i]);
    return p;
  });
}

export function assertNear(actual, expected, tol, message) {
  assert.ok(
    Math.abs(actual - expected) <= tol,
    message ?? `esperado ${expected} ± ${tol}, veio ${actual}`,
  );
}

export const jsonResponse = (data, status = 200) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => data,
});

// fetch falso: registra as URLs chamadas e delega a resposta ao handler.
export function fakeFetch(handler) {
  const calls = [];
  const fn = async (url) => {
    calls.push(url);
    return handler(url);
  };
  fn.calls = calls;
  return fn;
}
