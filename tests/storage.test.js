import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createStorage, DEFAULT_CONFIG, KEYS } from '../src/storage.js';

function memoryBackend() {
  const m = new Map();
  return {
    m,
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: (k) => m.delete(k),
  };
}

const quebrado = {
  getItem() {
    throw new Error('bloqueado');
  },
  setItem() {
    throw new Error('bloqueado');
  },
  removeItem() {
    throw new Error('bloqueado');
  },
};

test('salva e lista rotas, mais nova primeiro', () => {
  const s = createStorage(memoryBackend());
  assert.equal(s.available, true);
  s.saveRoute({ id: 'a', nome: 'A' });
  s.saveRoute({ id: 'b', nome: 'B' });
  assert.deepEqual(s.listRoutes().map((r) => r.id), ['b', 'a']);
  assert.equal(s.getRoute('a').nome, 'A');
  assert.equal(s.getRoute('zzz'), null);
});

test('salvar com o mesmo id substitui', () => {
  const s = createStorage(memoryBackend());
  s.saveRoute({ id: 'a', nome: 'A' });
  s.saveRoute({ id: 'a', nome: 'A2' });
  assert.deepEqual(s.listRoutes(), [{ id: 'a', nome: 'A2' }]);
});

test('apaga rota', () => {
  const s = createStorage(memoryBackend());
  s.saveRoute({ id: 'a', nome: 'A' });
  s.deleteRoute('a');
  assert.deepEqual(s.listRoutes(), []);
});

test('config: padrão e mesclagem', () => {
  const s = createStorage(memoryBackend());
  assert.deepEqual(s.loadConfig(), DEFAULT_CONFIG);
  s.saveConfig({ pesoKg: 90 });
  assert.deepEqual(s.loadConfig(), { ...DEFAULT_CONFIG, pesoKg: 90 });
});

test('JSON corrompido vira lista vazia', () => {
  const backend = memoryBackend();
  backend.setItem(KEYS.rotas, '{oops');
  assert.deepEqual(createStorage(backend).listRoutes(), []);
});

test('sem localStorage: funciona só na memória', () => {
  const s = createStorage(quebrado);
  assert.equal(s.available, false);
  s.saveRoute({ id: 'a', nome: 'A' });
  assert.equal(s.listRoutes().length, 1);
});

test('sem backend nenhum', () => {
  const s = createStorage(null);
  assert.equal(s.available, false);
  assert.deepEqual(s.listRoutes(), []);
});
