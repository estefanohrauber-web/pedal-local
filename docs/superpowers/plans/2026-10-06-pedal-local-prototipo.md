# Pedal Local — Plano de Implementação do Protótipo Web

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web app (Chrome Android) que conecta numa bike ergométrica via Bluetooth, deixa a pessoa traçar uma rota real no bairro e simula subidas e descidas pela velocidade virtual.

**Architecture:** HTML + CSS + JavaScript com módulos ES, sem build. Unidades puras (geo, perfil, física, potência, parser FTMS, sessão, rotas com `fetch` injetável, armazenamento com backend injetável, formatação) testadas com `node --test`. Camada de navegador fina (Web Bluetooth, Leaflet, canvas, DOM) em `src/ui/` e `src/bike/ftms-source.js`, verificada manualmente.

**Tech Stack:** JavaScript ES2022, Node 24 (`node --test`, sem dependências), Leaflet 1.9.4 via unpkg, OpenStreetMap tiles, OSRM (routing.openstreetmap.de, perfil bike), Open-Meteo Elevation API, Web Bluetooth, Screen Wake Lock API.

Spec: `docs/superpowers/specs/2026-10-06-pedal-local-design.md`

## Global Constraints

- Interface em português do Brasil; unidades km/h, m, %, W, rpm.
- Sem etapa de build e sem dependências npm; bibliotecas só por CDN (Leaflet).
- Reamostragem da rota a cada **20 m**; suavização por média móvel de **5 amostras**; inclinação limitada a **±20 %**.
- Física: passo **0,25 s**; g = 9,81; ρ = 1,225; CdA = 0,32; Crr = 0,005; bike 10 kg; peso padrão 75 kg; teto 25 m/s.
- Estimador: `P = cadência × (base + fator × nível)`, base 0,6, fator 0,25, nível 1–10; modo auto troca para estimada após **10 s** seguidos com cadência > 0 e potência nula/zero.
- Avisos: lookahead **200 m**; subida ≥ 4 %; descida ≤ −3 %.
- `localStorage` com chaves `pedal-local:rotas` e `pedal-local:config`, sempre em `try/catch`.
- Testes: `node --test` na raiz do projeto.

## Notas de execução

- Cada bloco de código é precedido por `<!-- file: caminho -->` indicando o arquivo exato.
- Ajuste em relação à spec: no modo `auto`, enquanto ainda não trocou de vez para estimada, uma leitura sem potência usa a estimativa naquele instante (evita a bike “travada” nos primeiros 10 s). A troca definitiva e o aviso seguem a regra de 10 s.
- Adição em relação à spec: botão “Procurar todos os aparelhos” e diagnóstico que lista os serviços Bluetooth da bike quando ela não expõe FTMS — substitui o teste com nRF Connect.
- Adição: `src/route/build-route.js` (compõe roteamento + altimetria + perfil), `src/ui/settings.js`, `src/ui/format.js`, `serve.js` (servidor local) e `README.md`.

---

### Task 1: Base do projeto e funções geográficas

**Files:**
- Create: `package.json`, `.gitignore`, `tests/helpers.js`, `src/route/geo.js`
- Test: `tests/geo.test.js`

**Interfaces:**
- Produces: `haversine(a, b) → metros`; `cumulativeDistances(points) → number[]`; `segmentIndex(cum, d) → índice`; `pointAt(points, cum, d) → [lat, lon]`; `resample(points, step = 20) → [[lat, lon]]`. Helpers de teste: `M_PER_DEG_LAT`, `northLine(count, spacingM, altitudes?, start?)`, `assertNear(actual, expected, tol)`, `jsonResponse(data, status?)`, `fakeFetch(handler)` (com `.calls`).

- [ ] **Step 1: Criar base do projeto**

<!-- file: package.json -->
```json
{
  "name": "pedal-local",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "Protótipo: pedalar rotas reais do seu bairro numa bike ergométrica.",
  "scripts": {
    "test": "node --test",
    "serve": "node serve.js"
  }
}
```

<!-- file: .gitignore -->
```text
node_modules/
.DS_Store
Thumbs.db
```

<!-- file: tests/helpers.js -->
```js
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
```

- [ ] **Step 2: Escrever o teste que falha**

<!-- file: tests/geo.test.js -->
```js
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
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `Cannot find module '.../src/route/geo.js'`

- [ ] **Step 4: Implementar**

<!-- file: src/route/geo.js -->
```js
// Funções geográficas puras sobre polilinhas [[lat, lon], ...].
const EARTH_RADIUS_M = 6371000;
const toRad = (deg) => (deg * Math.PI) / 180;

export function haversine(a, b) {
  const dLat = toRad(b[0] - a[0]);
  const dLon = toRad(b[1] - a[1]);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a[0])) * Math.cos(toRad(b[0])) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function cumulativeDistances(points) {
  const out = [0];
  for (let i = 1; i < points.length; i++) {
    out.push(out[i - 1] + haversine(points[i - 1], points[i]));
  }
  return out;
}

// Índice i do trecho [i, i+1] que contém a distância d (cum é crescente).
export function segmentIndex(cum, d) {
  let lo = 0;
  let hi = cum.length - 2;
  if (hi < 0) return 0;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (cum[mid] <= d) lo = mid;
    else hi = mid - 1;
  }
  return lo;
}

export function pointAt(points, cum, d) {
  if (points.length === 1) return [points[0][0], points[0][1]];
  const total = cum[cum.length - 1];
  const dist = Math.min(Math.max(d, 0), total);
  const i = segmentIndex(cum, dist);
  const seg = cum[i + 1] - cum[i];
  const t = seg > 0 ? (dist - cum[i]) / seg : 0;
  const a = points[i];
  const b = points[i + 1];
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
}

// Pontos a cada `step` metros; o último trecho fica entre step/2 e 1,5·step.
export function resample(points, step = 20) {
  if (points.length < 2) return points.map((p) => [p[0], p[1]]);
  const cum = cumulativeDistances(points);
  const total = cum[cum.length - 1];
  const out = [];
  for (let d = 0; d < total - step / 2; d += step) out.push(pointAt(points, cum, d));
  const last = points[points.length - 1];
  out.push([last[0], last[1]]);
  return out;
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `node --test`
Expected: PASS (7 testes)

- [ ] **Step 6: Commit**

```bash
git add package.json .gitignore tests/helpers.js tests/geo.test.js src/route/geo.js
git commit -m "feat: base do projeto e funções geográficas"
```

---

### Task 2: Perfil de relevo

**Files:**
- Create: `src/route/profile.js`
- Test: `tests/profile.test.js`

**Interfaces:**
- Consumes: `cumulativeDistances`, `segmentIndex`, `pointAt` (Task 1).
- Produces: `MAX_GRADE = 0.2`; `smoothElevations(alts, window = 5) → number[]`; `createProfile(pontos)` onde `pontos = [[lat, lon, alt], ...]`, retornando `{ distance, gain, loss, cum, alts, gradeAt(d), lookahead(d, span = 200), elevationAt(d), positionAt(d) → [lat, lon] }`. Inclinações em fração (0.05 = 5 %).

- [ ] **Step 1: Escrever o teste que falha**

<!-- file: tests/profile.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `Cannot find module '.../src/route/profile.js'`

- [ ] **Step 3: Implementar**

<!-- file: src/route/profile.js -->
```js
// Perfil de relevo: inclinação por trecho, totais e consultas por distância percorrida.
import { cumulativeDistances, segmentIndex, pointAt } from './geo.js';

export const MAX_GRADE = 0.2;
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, x));

export function smoothElevations(alts, window = 5) {
  const half = Math.floor(window / 2);
  return alts.map((_, i) => {
    let sum = 0;
    let n = 0;
    for (let j = Math.max(0, i - half); j <= Math.min(alts.length - 1, i + half); j++) {
      sum += alts[j];
      n++;
    }
    return sum / n;
  });
}

// pontos: [[lat, lon, altitude], ...] já reamostrados e suavizados.
export function createProfile(pontos) {
  const latlons = pontos.map((p) => [p[0], p[1]]);
  const alts = pontos.map((p) => p[2] ?? 0);
  const cum = cumulativeDistances(latlons);
  const distance = cum[cum.length - 1] ?? 0;
  const grades = [];
  let gain = 0;
  let loss = 0;
  for (let i = 0; i < pontos.length - 1; i++) {
    const run = cum[i + 1] - cum[i];
    const rise = alts[i + 1] - alts[i];
    grades.push(run > 0 ? clamp(rise / run, -MAX_GRADE, MAX_GRADE) : 0);
    if (rise > 0) gain += rise;
    else loss -= rise;
  }

  function elevationAt(d) {
    if (alts.length < 2) return alts[0] ?? 0;
    const x = clamp(d, 0, distance);
    const i = segmentIndex(cum, x);
    const seg = cum[i + 1] - cum[i];
    const t = seg > 0 ? (x - cum[i]) / seg : 0;
    return alts[i] + (alts[i + 1] - alts[i]) * t;
  }

  return {
    distance,
    gain,
    loss,
    cum,
    alts,
    elevationAt,
    gradeAt(d) {
      return grades.length ? grades[segmentIndex(cum, clamp(d, 0, distance))] : 0;
    },
    lookahead(d, span = 200) {
      const start = clamp(d, 0, distance);
      const end = Math.min(distance, start + span);
      return end - start > 1 ? (elevationAt(end) - elevationAt(start)) / (end - start) : 0;
    },
    positionAt(d) {
      return latlons.length ? pointAt(latlons, cum, d) : [0, 0];
    },
  };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/route/profile.js tests/profile.test.js
git commit -m "feat: perfil de relevo com inclinação, lookahead e totais"
```

---

### Task 3: Física da velocidade virtual

**Files:**
- Create: `src/physics.js`
- Test: `tests/physics.test.js`

**Interfaces:**
- Produces: `PHYSICS` (constantes), `DT = 0.25`, `stepSpeed(speedMs, { powerW, grade, riderMassKg }, dt = DT, c = PHYSICS) → speedMs`.

- [ ] **Step 1: Escrever o teste que falha**

<!-- file: tests/physics.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `Cannot find module '.../src/physics.js'`

- [ ] **Step 3: Implementar**

<!-- file: src/physics.js -->
```js
// Modelo físico simples de ciclismo: velocidade virtual a partir de potência e inclinação.
export const PHYSICS = {
  g: 9.81,
  rho: 1.225, // densidade do ar (kg/m³)
  cda: 0.32, // área frontal × coeficiente de arrasto (m²)
  crr: 0.005, // resistência ao rolamento
  bikeMassKg: 10,
  maxSpeedMs: 25, // 90 km/h
};

export const DT = 0.25;

export function stepSpeed(speedMs, { powerW, grade, riderMassKg }, dt = DT, c = PHYSICS) {
  const m = riderMassKg + c.bikeMassKg;
  const theta = Math.atan(grade);
  const resist =
    m * c.g * (Math.sin(theta) + c.crr * Math.cos(theta)) +
    0.5 * c.rho * c.cda * speedMs * speedMs;
  const drive = powerW / Math.max(speedMs, 1);
  const accel = (drive - resist) / m;
  return Math.min(c.maxSpeedMs, Math.max(0, speedMs + accel * dt));
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/physics.js tests/physics.test.js
git commit -m "feat: física da velocidade virtual"
```

---

### Task 4: Estimador de potência

**Files:**
- Create: `src/power.js`
- Test: `tests/power.test.js`

**Interfaces:**
- Produces: `DEFAULT_CALIBRATION = { base: 0.6, factor: 0.25 }`, `FALLBACK_AFTER_MS = 10000`, `estimatePower(cadence, level, calibration?) → W inteiro`, `createPowerResolver({ mode: 'auto'|'bike'|'estimada', calibration }) → { effectiveMode, switchedToEstimate, resolve({ cadence, power, timestamp }, level) → W }`.

- [ ] **Step 1: Escrever o teste que falha**

<!-- file: tests/power.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `Cannot find module '.../src/power.js'`

- [ ] **Step 3: Implementar**

<!-- file: src/power.js -->
```js
// Potência usada na simulação: a da bike, ou estimada pela cadência e pelo nível de carga.
export const DEFAULT_CALIBRATION = { base: 0.6, factor: 0.25 };
export const FALLBACK_AFTER_MS = 10000;

export function estimatePower(cadence, level, calibration = DEFAULT_CALIBRATION) {
  if (!(cadence > 0)) return 0;
  return Math.round(cadence * (calibration.base + calibration.factor * level));
}

// mode: 'auto' | 'bike' | 'estimada'
export function createPowerResolver({ mode = 'auto', calibration = DEFAULT_CALIBRATION } = {}) {
  let effective = mode === 'estimada' ? 'estimada' : 'bike';
  let missingSince = null;
  let switched = false;

  return {
    get effectiveMode() {
      return effective;
    },
    get switchedToEstimate() {
      return switched;
    },
    resolve({ cadence, power, timestamp }, level) {
      if (!(cadence > 0)) {
        missingSince = null;
        return 0;
      }
      const hasPower = power != null && power > 0;
      if (mode === 'auto' && effective === 'bike') {
        if (hasPower) missingSince = null;
        else if (missingSince == null) missingSince = timestamp;
        else if (timestamp - missingSince >= FALLBACK_AFTER_MS) {
          effective = 'estimada';
          switched = true;
        }
      }
      if (effective === 'estimada') return estimatePower(cadence, level, calibration);
      if (hasPower) return power;
      return mode === 'auto' ? estimatePower(cadence, level, calibration) : 0;
    },
  };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/power.js tests/power.test.js
git commit -m "feat: estimador de potência com troca automática"
```

---

### Task 5: Leitura dos dados FTMS

**Files:**
- Create: `src/bike/ftms-parser.js`
- Test: `tests/ftms-parser.test.js`

**Interfaces:**
- Produces: `parseIndoorBikeData(DataView | ArrayBuffer | Uint8Array) → { speed: km/h|null, cadence: rpm|null, power: W|null, heartRate: bpm|null }`.

- [ ] **Step 1: Escrever o teste que falha**

<!-- file: tests/ftms-parser.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `Cannot find module '.../src/bike/ftms-parser.js'`

- [ ] **Step 3: Implementar**

<!-- file: src/bike/ftms-parser.js -->
```js
// Decodifica a característica Indoor Bike Data (0x2AD2) do serviço Fitness Machine (FTMS).
// Os campos vêm na ordem da especificação e cada flag indica se o campo está presente.
// O bit 0 é invertido: 0 significa que a velocidade instantânea está presente.
export function parseIndoorBikeData(input) {
  const view = toDataView(input);
  const result = { speed: null, cadence: null, power: null, heartRate: null };
  if (view.byteLength < 2) return result;

  const flags = view.getUint16(0, true);
  const has = (bit) => (flags & (1 << bit)) !== 0;
  let offset = 2;

  // [presente, tamanho em bytes, leitura (null = só pular)]
  const fields = [
    [!has(0), 2, () => (result.speed = view.getUint16(offset, true) / 100)],
    [has(1), 2, null], // velocidade média
    [has(2), 2, () => (result.cadence = view.getUint16(offset, true) / 2)],
    [has(3), 2, null], // cadência média
    [has(4), 3, null], // distância total
    [has(5), 2, null], // nível de resistência
    [has(6), 2, () => (result.power = view.getInt16(offset, true))],
    [has(7), 2, null], // potência média
    [has(8), 5, null], // energia: total, por hora, por minuto
    [has(9), 1, () => (result.heartRate = view.getUint8(offset))],
  ];

  for (const [present, size, read] of fields) {
    if (!present) continue;
    if (offset + size > view.byteLength) break;
    if (read) read();
    offset += size;
  }
  return result;
}

function toDataView(input) {
  if (input instanceof DataView) return input;
  if (input instanceof ArrayBuffer) return new DataView(input);
  return new DataView(input.buffer, input.byteOffset, input.byteLength);
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/bike/ftms-parser.js tests/ftms-parser.test.js
git commit -m "feat: parser de Indoor Bike Data (FTMS)"
```

---

### Task 6: Sessão de pedal

**Files:**
- Create: `src/ride.js`
- Test: `tests/ride.test.js`

**Interfaces:**
- Consumes: `stepSpeed`, `DT` (Task 3); um perfil com `{ distance, gradeAt(d), lookahead(d, span), positionAt(d) }` (Task 2).
- Produces: `ALERT_LOOKAHEAD_M = 200`, `CLIMB_ALERT = 0.04`, `DESCENT_ALERT = -0.03`, `createRide({ profile, riderMassKg }) → { state, start(), pause(), resume(), setInputs({ powerW, cadenceRpm }), advance(seconds) → [{ tipo: 'subida'|'descida', inclinacao }], snapshot() }`. `snapshot()` → `{ state, distance, total, speedKmh, power, cadence, grade, position, movingTime, avgPower, avgSpeedKmh }`. Estados: `'pronto' | 'pedalando' | 'pausado' | 'concluido'`.

- [ ] **Step 1: Escrever o teste que falha**

<!-- file: tests/ride.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `Cannot find module '.../src/ride.js'`

- [ ] **Step 3: Implementar**

<!-- file: src/ride.js -->
```js
// Sessão de pedal sobre um perfil de rota.
// Estados: pronto → pedalando ⇄ pausado → concluido.
import { stepSpeed, DT } from './physics.js';

export const ALERT_LOOKAHEAD_M = 200;
export const CLIMB_ALERT = 0.04;
export const DESCENT_ALERT = -0.03;

export function createRide({ profile, riderMassKg }) {
  let state = 'pronto';
  let speed = 0;
  let distance = 0;
  let movingTime = 0;
  let energyJ = 0;
  let power = 0;
  let cadence = 0;
  // Um aviso só volta a disparar depois que o trecho à frente deixa de ser subida/descida.
  const armed = { subida: true, descida: true };

  function checkAlert() {
    const g = profile.lookahead(distance, ALERT_LOOKAHEAD_M);
    if (g < CLIMB_ALERT / 2) armed.subida = true;
    if (g > DESCENT_ALERT / 2) armed.descida = true;
    if (armed.subida && g >= CLIMB_ALERT) {
      armed.subida = false;
      return { tipo: 'subida', inclinacao: g };
    }
    if (armed.descida && g <= DESCENT_ALERT) {
      armed.descida = false;
      return { tipo: 'descida', inclinacao: g };
    }
    return null;
  }

  return {
    get state() {
      return state;
    },
    start() {
      if (state === 'pronto') state = 'pedalando';
    },
    pause() {
      if (state === 'pedalando') {
        state = 'pausado';
        speed = 0;
      }
    },
    resume() {
      if (state === 'pausado') state = 'pedalando';
    },
    setInputs({ powerW, cadenceRpm }) {
      power = Math.max(0, powerW || 0);
      cadence = cadenceRpm || 0;
    },
    advance(seconds) {
      const alerts = [];
      let remaining = seconds;
      while (state === 'pedalando' && remaining > 1e-9) {
        const dt = Math.min(DT, remaining);
        remaining -= dt;
        const grade = profile.gradeAt(distance);
        speed = stepSpeed(speed, { powerW: power, grade, riderMassKg }, dt);
        distance += speed * dt;
        if (speed > 0 || power > 0) {
          movingTime += dt;
          energyJ += power * dt;
        }
        if (distance >= profile.distance) {
          distance = profile.distance;
          state = 'concluido';
          break;
        }
        const alert = checkAlert();
        if (alert) alerts.push(alert);
      }
      return alerts;
    },
    snapshot() {
      return {
        state,
        distance,
        total: profile.distance,
        speedKmh: speed * 3.6,
        power,
        cadence,
        grade: profile.gradeAt(distance),
        position: profile.positionAt(distance),
        movingTime,
        avgPower: movingTime > 0 ? energyJ / movingTime : 0,
        avgSpeedKmh: movingTime > 0 ? (distance / movingTime) * 3.6 : 0,
      };
    },
  };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/ride.js tests/ride.test.js
git commit -m "feat: sessão de pedal com avisos de subida e descida"
```

---

### Task 7: Rota pelas ruas e altimetria

**Files:**
- Create: `src/route/routing.js`, `src/route/elevation.js`, `src/route/build-route.js`
- Test: `tests/routing.test.js`, `tests/elevation.test.js`, `tests/build-route.test.js`

**Interfaces:**
- Consumes: `resample` (Task 1), `smoothElevations`, `createProfile` (Task 2).
- Produces: `OSRM_URL`, `RouteError(code, message)` com `code ∈ 'poucos-pontos' | 'sem-conexao' | 'sem-caminho' | 'servico'`, `fetchRoute(waypoints, fetchFn?) → [[lat, lon]]`; `ELEVATION_URL`, `ELEVATION_BATCH = 100`, `fetchElevations(points, fetchFn?) → number[]`; `SAMPLE_STEP_M = 20`, `buildRoute({ waypoints, fetchFn?, now? }) → { route, semAltimetria }` com `route = { id, nome: '', criadaEm, waypoints, pontos: [[lat, lon, alt]], distanciaM, ganhoM, perdaM }`.

- [ ] **Step 1: Escrever os testes que falham**

<!-- file: tests/routing.test.js -->
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchRoute, RouteError, OSRM_URL } from '../src/route/routing.js';
import { fakeFetch, jsonResponse } from './helpers.js';

const dois = [[-23.5, -46.6], [-23.51, -46.61]];

const rejeita = (promise, code) =>
  assert.rejects(promise, (e) => e instanceof RouteError && e.code === code);

test('monta a URL como lon,lat e devolve [lat, lon]', async () => {
  const fetchFn = fakeFetch(() =>
    jsonResponse({
      code: 'Ok',
      routes: [{ geometry: { coordinates: [[-46.6, -23.5], [-46.61, -23.51]] } }],
    }),
  );
  const linha = await fetchRoute(dois, fetchFn);
  assert.deepEqual(linha, dois);
  assert.equal(
    fetchFn.calls[0],
    `${OSRM_URL}-46.600000,-23.500000;-46.610000,-23.510000?overview=full&geometries=geojson`,
  );
});

test('menos de dois pontos', () =>
  rejeita(fetchRoute([[0, 0]], fakeFetch(() => jsonResponse({}))), 'poucos-pontos'));

test('sem conexão', () =>
  rejeita(
    fetchRoute(dois, async () => {
      throw new TypeError('Failed to fetch');
    }),
    'sem-conexao',
  ));

test('sem caminho entre os pontos', () =>
  rejeita(fetchRoute(dois, fakeFetch(() => jsonResponse({ code: 'NoRoute' }, 400))), 'sem-caminho'));

test('ponto longe de qualquer rua', () =>
  rejeita(fetchRoute(dois, fakeFetch(() => jsonResponse({ code: 'NoSegment' }, 400))), 'sem-caminho'));

test('serviço fora do ar', () =>
  rejeita(
    fetchRoute(
      dois,
      fakeFetch(() => ({
        ok: false,
        status: 502,
        json: async () => {
          throw new SyntaxError('html');
        },
      })),
    ),
    'servico',
  ));
```

<!-- file: tests/elevation.test.js -->
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fetchElevations } from '../src/route/elevation.js';
import { fakeFetch, jsonResponse } from './helpers.js';

const latCount = (url) => new URL(url).searchParams.get('latitude').split(',').length;

test('busca em lotes de 100 e mantém a ordem', async () => {
  let n = 0;
  const fetchFn = fakeFetch((url) => {
    const k = latCount(url);
    const base = n;
    n += k;
    return jsonResponse({ elevation: Array.from({ length: k }, (_, i) => base + i) });
  });
  const pts = Array.from({ length: 150 }, (_, i) => [-23.5 + i * 1e-4, -46.6]);
  const alts = await fetchElevations(pts, fetchFn);
  assert.equal(fetchFn.calls.length, 2);
  assert.equal(latCount(fetchFn.calls[0]), 100);
  assert.deepEqual(alts, Array.from({ length: 150 }, (_, i) => i));
});

test('resposta com tamanho errado falha', async () => {
  await assert.rejects(
    fetchElevations([[0, 0], [0, 1]], fakeFetch(() => jsonResponse({ elevation: [1] }))),
  );
});

test('HTTP de erro falha', async () => {
  await assert.rejects(fetchElevations([[0, 0]], fakeFetch(() => jsonResponse({}, 429))));
});
```

<!-- file: tests/build-route.test.js -->
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildRoute } from '../src/route/build-route.js';
import { OSRM_URL } from '../src/route/routing.js';
import { northLine, fakeFetch, jsonResponse } from './helpers.js';

const [a, b] = northLine(2, 100);
const osrm = () =>
  jsonResponse({
    code: 'Ok',
    routes: [{ geometry: { coordinates: [[a[1], a[0]], [b[1], b[0]]] } }],
  });

test('monta rota com pontos a cada 20 m e altimetria suavizada', async () => {
  const fetchFn = fakeFetch((url) => {
    if (url.startsWith(OSRM_URL)) return osrm();
    const k = new URL(url).searchParams.get('latitude').split(',').length;
    return jsonResponse({ elevation: Array.from({ length: k }, (_, i) => i * 2) });
  });
  const { route, semAltimetria } = await buildRoute({
    waypoints: [a, b],
    fetchFn,
    now: () => new Date('2026-10-06T12:00:00Z'),
  });
  assert.equal(semAltimetria, false);
  assert.equal(route.pontos.length, 6);
  assert.equal(route.distanciaM, 100);
  assert.equal(route.criadaEm, '2026-10-06T12:00:00.000Z');
  assert.equal(route.ganhoM, 6);
  assert.equal(route.perdaM, 0);
  assert.equal(route.nome, '');
  assert.deepEqual(route.waypoints, [a, b]);
});

test('sem altimetria: rota plana com aviso', async () => {
  const fetchFn = fakeFetch((url) => (url.startsWith(OSRM_URL) ? osrm() : jsonResponse({}, 500)));
  const { route, semAltimetria } = await buildRoute({ waypoints: [a, b], fetchFn });
  assert.equal(semAltimetria, true);
  assert.ok(route.pontos.every((p) => p[2] === 0));
});

test('erro de rota sobe para quem chamou', async () => {
  await assert.rejects(buildRoute({ waypoints: [a], fetchFn: fakeFetch(osrm) }), {
    code: 'poucos-pontos',
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — módulos `routing.js`, `elevation.js`, `build-route.js` não encontrados

- [ ] **Step 3: Implementar**

<!-- file: src/route/routing.js -->
```js
// Traça o caminho pelas ruas entre os pontos tocados (OSRM, perfil bicicleta).
export const OSRM_URL = 'https://routing.openstreetmap.de/routed-bike/route/v1/driving/';

export class RouteError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'RouteError';
    this.code = code;
  }
}

const defaultFetch = (...args) => globalThis.fetch(...args);

export async function fetchRoute(waypoints, fetchFn = defaultFetch) {
  if (waypoints.length < 2) {
    throw new RouteError('poucos-pontos', 'Toque pelo menos dois pontos no mapa.');
  }
  const coords = waypoints.map(([lat, lon]) => `${lon.toFixed(6)},${lat.toFixed(6)}`).join(';');

  let res;
  try {
    res = await fetchFn(`${OSRM_URL}${coords}?overview=full&geometries=geojson`);
  } catch {
    throw new RouteError('sem-conexao', 'Sem conexão — não deu para traçar a rota.');
  }

  let data = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }
  const semCaminho =
    data?.code === 'NoRoute' || data?.code === 'NoSegment' || (data?.code === 'Ok' && !data.routes?.length);
  if (semCaminho) {
    throw new RouteError('sem-caminho', 'Não encontrei caminho entre esses pontos.');
  }
  if (!res.ok || data?.code !== 'Ok') {
    throw new RouteError('servico', 'O serviço de rotas não respondeu. Tente de novo em instantes.');
  }
  return data.routes[0].geometry.coordinates.map(([lon, lat]) => [lat, lon]);
}
```

<!-- file: src/route/elevation.js -->
```js
// Altitude de cada ponto (Open-Meteo Elevation API, até 100 coordenadas por chamada).
export const ELEVATION_URL = 'https://api.open-meteo.com/v1/elevation';
export const ELEVATION_BATCH = 100;

const defaultFetch = (...args) => globalThis.fetch(...args);

export async function fetchElevations(points, fetchFn = defaultFetch) {
  const out = [];
  for (let i = 0; i < points.length; i += ELEVATION_BATCH) {
    const lote = points.slice(i, i + ELEVATION_BATCH);
    const lat = lote.map((p) => p[0].toFixed(5)).join(',');
    const lon = lote.map((p) => p[1].toFixed(5)).join(',');
    const res = await fetchFn(`${ELEVATION_URL}?latitude=${lat}&longitude=${lon}`);
    if (!res.ok) throw new Error(`Altimetria indisponível (HTTP ${res.status})`);
    const data = await res.json();
    if (!Array.isArray(data?.elevation) || data.elevation.length !== lote.length) {
      throw new Error('Altimetria: resposta inválida');
    }
    out.push(...data.elevation);
  }
  return out;
}
```

<!-- file: src/route/build-route.js -->
```js
// Pontos tocados no mapa → rota pronta para salvar (o nome é dado depois).
import { fetchRoute } from './routing.js';
import { fetchElevations } from './elevation.js';
import { resample } from './geo.js';
import { smoothElevations, createProfile } from './profile.js';

export const SAMPLE_STEP_M = 20;

const defaultFetch = (...args) => globalThis.fetch(...args);
const round = (x, casas) => Math.round(x * 10 ** casas) / 10 ** casas;

export async function buildRoute({ waypoints, fetchFn = defaultFetch, now = () => new Date() }) {
  const linha = await fetchRoute(waypoints, fetchFn);
  const amostras = resample(linha, SAMPLE_STEP_M);

  let alts;
  let semAltimetria = false;
  try {
    alts = smoothElevations(await fetchElevations(amostras, fetchFn));
  } catch {
    alts = amostras.map(() => 0);
    semAltimetria = true;
  }

  const pontos = amostras.map(([lat, lon], i) => [round(lat, 6), round(lon, 6), round(alts[i], 1)]);
  const perfil = createProfile(pontos);
  const data = now();
  return {
    semAltimetria,
    route: {
      id: `r${data.getTime().toString(36)}${Math.random().toString(36).slice(2, 6)}`,
      nome: '',
      criadaEm: data.toISOString(),
      waypoints,
      pontos,
      distanciaM: Math.round(perfil.distance),
      ganhoM: Math.round(perfil.gain),
      perdaM: Math.round(perfil.loss),
    },
  };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/route/routing.js src/route/elevation.js src/route/build-route.js tests/routing.test.js tests/elevation.test.js tests/build-route.test.js
git commit -m "feat: traçado pelas ruas e altimetria da rota"
```

---

### Task 8: Armazenamento e formatação

**Files:**
- Create: `src/storage.js`, `src/ui/format.js`
- Test: `tests/storage.test.js`, `tests/format.test.js`

**Interfaces:**
- Produces: `KEYS`, `DEFAULT_CONFIG = { pesoKg: 75, modoPotencia: 'auto', base: 0.6, fator: 0.25 }`, `createStorage(backend?) → { available, listRoutes(), getRoute(id), saveRoute(route), deleteRoute(id), loadConfig(), saveConfig(cfg) }`. `formatNumber(n, casas = 0)`, `formatKm(m, casas = 2)`, `formatTime(segundos)`.

- [ ] **Step 1: Escrever os testes que falham**

<!-- file: tests/storage.test.js -->
```js
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
```

<!-- file: tests/format.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `storage.js` e `format.js` não encontrados

- [ ] **Step 3: Implementar**

<!-- file: src/storage.js -->
```js
// Rotas e configurações no localStorage; se ele estiver bloqueado, guarda só na memória.
export const KEYS = { rotas: 'pedal-local:rotas', config: 'pedal-local:config' };
export const DEFAULT_CONFIG = { pesoKg: 75, modoPotencia: 'auto', base: 0.6, fator: 0.25 };

function globalStorage() {
  try {
    return globalThis.localStorage ?? null;
  } catch {
    return null;
  }
}

function probe(backend) {
  try {
    backend.setItem('pedal-local:teste', '1');
    backend.removeItem('pedal-local:teste');
    return true;
  } catch {
    return false;
  }
}

export function createStorage(backend = globalStorage()) {
  const available = !!backend && probe(backend);
  const memory = new Map();

  function read(key, fallback) {
    try {
      const raw = available ? backend.getItem(key) : memory.get(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch {
      return fallback;
    }
  }

  function write(key, value) {
    const raw = JSON.stringify(value);
    memory.set(key, raw);
    if (!available) return false;
    try {
      backend.setItem(key, raw);
      return true;
    } catch {
      return false;
    }
  }

  const listRoutes = () => read(KEYS.rotas, []);

  return {
    available,
    listRoutes,
    getRoute: (id) => listRoutes().find((r) => r.id === id) ?? null,
    saveRoute(route) {
      return write(KEYS.rotas, [route, ...listRoutes().filter((r) => r.id !== route.id)]);
    },
    deleteRoute(id) {
      return write(KEYS.rotas, listRoutes().filter((r) => r.id !== id));
    },
    loadConfig: () => ({ ...DEFAULT_CONFIG, ...read(KEYS.config, {}) }),
    saveConfig: (config) => write(KEYS.config, config),
  };
}
```

<!-- file: src/ui/format.js -->
```js
// Formatação de números, distâncias e tempo no padrão brasileiro.
const formatters = new Map();

function formatter(casas) {
  if (!formatters.has(casas)) {
    formatters.set(
      casas,
      new Intl.NumberFormat('pt-BR', { minimumFractionDigits: casas, maximumFractionDigits: casas }),
    );
  }
  return formatters.get(casas);
}

export function formatNumber(n, casas = 0) {
  const valor = Math.abs(n) < 0.5 / 10 ** casas ? 0 : n;
  return formatter(casas).format(valor);
}

export const formatKm = (metros, casas = 2) => `${formatNumber(metros / 1000, casas)} km`;

export function formatTime(segundos) {
  const s = Math.floor(segundos);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = String(s % 60).padStart(2, '0');
  return h ? `${h}:${String(m).padStart(2, '0')}:${r}` : `${m}:${r}`;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/storage.js src/ui/format.js tests/storage.test.js tests/format.test.js
git commit -m "feat: armazenamento local e formatação pt-BR"
```

---

### Task 9: Fontes da bike (simulada e FTMS)

**Files:**
- Create: `src/bike/sim-source.js`, `src/bike/ftms-source.js`
- Test: `tests/sim-source.test.js`

**Interfaces:**
- Consumes: `parseIndoorBikeData` (Task 5).
- Produces (interface comum de fonte): `{ name, simulated, deviceName, connected, connect() → Promise, disconnect(), onData(cb({ cadence, power, speed, heartRate, timestamp })), onDisconnect(cb) }`. Simulada também tem `harder()`, `easier()`, `target`, `sample()`. FTMS: `FTMS_SERVICE`, `INDOOR_BIKE_DATA`, `OPTIONAL_SERVICES`, `NoFtmsError` (mensagem = diagnóstico com nome e serviços), `isBluetoothAvailable()`, `createFtmsSource({ acceptAllDevices })`. `onDisconnect` só dispara em queda inesperada, nunca em `disconnect()` manual.

- [ ] **Step 1: Escrever o teste que falha**

<!-- file: tests/sim-source.test.js -->
```js
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `node --test`
Expected: FAIL — `sim-source.js` não encontrado

- [ ] **Step 3: Implementar a fonte simulada**

<!-- file: src/bike/sim-source.js -->
```js
// Bike falsa: gera cadência e potência a cada segundo para testar sem a bike real.
export function createSimSource({ intervalMs = 1000, random = Math.random, now = Date.now } = {}) {
  let timer = null;
  let aoReceber = () => {};
  let target = 150;
  let power = 0;

  function sample() {
    power = Math.max(0, power + (target - power) * 0.4 + (random() - 0.5) * 12);
    if (target === 0 && power < 15) power = 0;
    const cadence =
      power === 0 ? 0 : Math.round(Math.min(105, Math.max(55, 65 + power / 12 + (random() - 0.5) * 4)));
    return { cadence, power: Math.round(power), speed: null, heartRate: null, timestamp: now() };
  }

  return {
    name: 'Simulada',
    simulated: true,
    deviceName: 'Bike simulada',
    get connected() {
      return timer !== null;
    },
    get target() {
      return target;
    },
    async connect() {
      if (!timer) timer = setInterval(() => aoReceber(sample()), intervalMs);
    },
    disconnect() {
      clearInterval(timer);
      timer = null;
    },
    onData(cb) {
      aoReceber = cb;
    },
    onDisconnect() {
      // A bike simulada nunca cai sozinha.
    },
    harder() {
      target = Math.min(400, target + 25);
    },
    easier() {
      target = Math.max(0, target - 25);
    },
    sample,
  };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `node --test`
Expected: PASS

- [ ] **Step 5: Implementar a fonte FTMS (só navegador, verificada manualmente na Task 11)**

<!-- file: src/bike/ftms-source.js -->
```js
// Conexão com a bike pelo Web Bluetooth usando o padrão FTMS (Fitness Machine Service).
import { parseIndoorBikeData } from './ftms-parser.js';

export const FTMS_SERVICE = 0x1826;
export const INDOOR_BIKE_DATA = 0x2ad2;
// Serviços que pedimos permissão para enxergar; também aparecem no diagnóstico.
// FTMS, Cycling Speed and Cadence, Cycling Power, Device Information, Heart Rate, FitShow (FFF0/FFE0).
export const OPTIONAL_SERVICES = [0x1826, 0x1816, 0x1818, 0x180a, 0x180d, 0xfff0, 0xffe0];

export class NoFtmsError extends Error {
  constructor(message) {
    super(message);
    this.name = 'NoFtmsError';
  }
}

export const isBluetoothAvailable = () =>
  typeof navigator !== 'undefined' && 'bluetooth' in navigator;

export function createFtmsSource({ acceptAllDevices = false } = {}) {
  let device = null;
  let characteristic = null;
  let manual = false;
  let aoReceber = () => {};
  let aoDesconectar = () => {};

  const onValue = (event) =>
    aoReceber({ ...parseIndoorBikeData(event.target.value), timestamp: Date.now() });
  const onGattDisconnected = () => {
    if (!manual) aoDesconectar();
  };

  async function escolherAparelho() {
    const opcoes = acceptAllDevices
      ? { acceptAllDevices: true, optionalServices: OPTIONAL_SERVICES }
      : {
          filters: [{ services: [FTMS_SERVICE] }, { namePrefix: 'FS-' }],
          optionalServices: OPTIONAL_SERVICES,
        };
    device = await navigator.bluetooth.requestDevice(opcoes);
    device.addEventListener('gattserverdisconnected', onGattDisconnected);
  }

  async function diagnostico(server) {
    let servicos = [];
    try {
      servicos = await server.getPrimaryServices();
    } catch {
      servicos = [];
    }
    const lista = servicos.map((s) => `  ${s.uuid}`).join('\n') || '  (nenhum serviço visível)';
    return `Aparelho: ${device.name ?? '(sem nome)'}\nServiços:\n${lista}`;
  }

  return {
    name: 'FTMS',
    simulated: false,
    get deviceName() {
      return device?.name || 'Bike';
    },
    get connected() {
      return !!device?.gatt?.connected;
    },
    async connect() {
      manual = false;
      if (!device) await escolherAparelho();
      const server = await device.gatt.connect();
      let service;
      try {
        service = await server.getPrimaryService(FTMS_SERVICE);
      } catch {
        const texto = await diagnostico(server);
        manual = true;
        device.gatt.disconnect();
        throw new NoFtmsError(texto);
      }
      characteristic?.removeEventListener('characteristicvaluechanged', onValue);
      characteristic = await service.getCharacteristic(INDOOR_BIKE_DATA);
      characteristic.addEventListener('characteristicvaluechanged', onValue);
      await characteristic.startNotifications();
    },
    disconnect() {
      manual = true;
      characteristic?.removeEventListener('characteristicvaluechanged', onValue);
      if (device?.gatt?.connected) device.gatt.disconnect();
    },
    onData(cb) {
      aoReceber = cb;
    },
    onDisconnect(cb) {
      aoDesconectar = cb;
    },
  };
}
```

- [ ] **Step 6: Commit**

```bash
git add src/bike/sim-source.js src/bike/ftms-source.js tests/sim-source.test.js
git commit -m "feat: fontes da bike simulada e FTMS"
```

---

### Task 10: Interface (telas, mapa, gráfico)

**Files:**
- Create: `index.html`, `styles.css`, `src/app.js`, `src/ui/home.js`, `src/ui/settings.js`, `src/ui/elevation-chart.js`, `src/ui/route-editor.js`, `src/ui/ride-screen.js`

**Interfaces:**
- Consumes: tudo das Tasks 1–9; `window.L` (Leaflet carregado por `<script>` antes do módulo).
- Produces: `initHome({ storage, onConnect, onConnectAny, onSimulated, onNewRoute, onRide, onSettings }) → { renderRoutes(), setBikeStatus(texto, conectada), showDiagnostic(texto|null) }`; `initSettings({ storage, onChange }) → { open(config) }`; `drawElevationChart(canvas, profile, markerDistance?)`; `openRouteEditor({ storage, onDone })`; `openRideScreen({ route, source, config, onExit })`.

- [ ] **Step 1: HTML**

<!-- file: index.html -->
```html
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
    <meta name="theme-color" content="#0f1417" />
    <title>Pedal Local</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="" />
    <link rel="stylesheet" href="styles.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
    <script type="module" src="src/app.js"></script>
  </head>
  <body>
    <main>
      <section id="tela-inicio" class="tela">
        <header class="topo">
          <h1>Pedal Local</h1>
          <button id="btn-config" type="button" class="icone" aria-label="Configurações">⚙</button>
        </header>

        <div class="cartao">
          <p class="rotulo">Bike</p>
          <p id="status-bike" class="status">Desconectada</p>
          <div class="acoes">
            <button id="btn-conectar" type="button" class="primario">Conectar bike</button>
            <button id="btn-simulada" type="button">Usar bike simulada</button>
          </div>
          <button id="btn-todos" type="button" class="link">Não aparece? Procurar todos os aparelhos</button>
          <pre id="diagnostico" hidden></pre>
        </div>

        <div class="cartao">
          <div class="linha">
            <p class="rotulo">Minhas rotas</p>
            <button id="btn-nova-rota" type="button" class="primario">Nova rota</button>
          </div>
          <ul id="lista-rotas" class="lista"></ul>
          <p id="sem-rotas" class="vazio">
            Nenhuma rota ainda. Toque em “Nova rota” e desenhe um caminho no seu bairro.
          </p>
        </div>

        <p id="aviso-armazenamento" class="aviso" hidden>
          Este navegador não deixa salvar dados: as rotas somem ao fechar a página.
        </p>
      </section>

      <section id="tela-rota" class="tela" hidden>
        <header class="topo">
          <button id="rota-voltar" type="button" class="icone" aria-label="Voltar">←</button>
          <h1>Nova rota</h1>
        </header>
        <div id="mapa-rota" class="mapa"></div>
        <p id="rota-dica" class="dica"></p>
        <div class="acoes">
          <button id="rota-desfazer" type="button">Desfazer</button>
          <button id="rota-fechar" type="button">Fechar volta</button>
          <button id="rota-calcular" type="button" class="primario">Calcular</button>
        </div>
        <p id="rota-msg" hidden></p>
        <div id="rota-resultado" class="cartao" hidden>
          <p id="rota-resumo"></p>
          <canvas id="rota-grafico" class="grafico" aria-label="Perfil de relevo da rota"></canvas>
          <label>Nome da rota<input id="rota-nome" type="text" maxlength="60" placeholder="Volta do bairro" /></label>
          <button id="rota-salvar" type="button" class="primario">Salvar rota</button>
        </div>
      </section>

      <section id="tela-pedal" class="tela" hidden>
        <header class="topo">
          <h1 id="pedal-nome">Pedal</h1>
          <button id="btn-sair" type="button">Sair</button>
        </header>
        <div id="pedal-aviso" class="banner" hidden></div>
        <div id="mapa-pedal" class="mapa mapa-pedal"></div>
        <div class="metricas">
          <div class="metrica destaque"><span id="m-vel">0,0</span><small>km/h</small></div>
          <div class="metrica"><span id="m-pot">0</span><small>watts</small></div>
          <div class="metrica"><span id="m-rpm">0</span><small>rpm</small></div>
          <div class="metrica"><span id="m-incl">0,0</span><small>% inclinação</small></div>
          <div class="metrica"><span id="m-dist">0,00</span><small>km de <span id="m-total">–</span></small></div>
          <div class="metrica"><span id="m-tempo">0:00</span><small>tempo</small></div>
        </div>
        <canvas id="pedal-grafico" class="grafico" aria-label="Perfil de relevo com a sua posição"></canvas>
        <div class="controles">
          <div class="carga">
            <button id="carga-menos" type="button" aria-label="Diminuir carga">−</button>
            <span>Carga no botão da bike: <b id="carga-nivel">4</b></span>
            <button id="carga-mais" type="button" aria-label="Aumentar carga">+</button>
          </div>
          <div id="controles-sim" class="acoes" hidden>
            <button id="sim-fraco" type="button">Simular: mais fraco</button>
            <button id="sim-forte" type="button">Simular: mais forte</button>
          </div>
          <div class="acoes">
            <button id="btn-pausa" type="button">Pausar</button>
            <button id="btn-reconectar" type="button" class="primario" hidden>Reconectar</button>
          </div>
        </div>
        <p id="pedal-modo" class="dica"></p>

        <div id="resumo" class="sobreposicao" hidden>
          <div class="cartao">
            <h2>Rota concluída!</h2>
            <div class="resumo-grid">
              <div><small>Distância</small><b id="r-dist"></b></div>
              <div><small>Tempo</small><b id="r-tempo"></b></div>
              <div><small>Potência média</small><b id="r-pot"></b></div>
              <div><small>Velocidade média</small><b id="r-vel"></b></div>
              <div><small>Subida total</small><b id="r-subida"></b></div>
            </div>
            <button id="resumo-voltar" type="button" class="primario">Voltar ao início</button>
          </div>
        </div>
      </section>
    </main>

    <dialog id="dialogo-config">
      <form method="dialog" id="form-config">
        <h2>Configurações</h2>
        <label>Seu peso (kg)<input name="pesoKg" type="number" min="30" max="200" step="1" required /></label>
        <label>
          Potência
          <select name="modoPotencia">
            <option value="auto">Automática (usa a da bike; se não vier, estima)</option>
            <option value="bike">Sempre a da bike</option>
            <option value="estimada">Sempre estimada pela carga</option>
          </select>
        </label>
        <details>
          <summary>Calibração da estimativa</summary>
          <p class="dica">Potência = RPM × (base + fator × carga)</p>
          <label>Base<input name="base" type="number" step="0.05" min="0" /></label>
          <label>Fator<input name="fator" type="number" step="0.05" min="0" /></label>
        </details>
        <div class="acoes">
          <button value="cancelar" formnovalidate>Cancelar</button>
          <button value="salvar" class="primario">Salvar</button>
        </div>
      </form>
    </dialog>
  </body>
</html>
```

- [ ] **Step 2: CSS**

<!-- file: styles.css -->
```css
:root {
  --fundo: #0f1417;
  --cartao: #182025;
  --campo: #0b0f11;
  --borda: #26313a;
  --texto: #eef3f5;
  --suave: #9aa7ad;
  --acento: #ff8a3d;
  --acento-texto: #1a0d03;
  --ok: #4cd18a;
  --erro: #ff6b6b;
  --raio: 14px;
  color-scheme: dark;
}

* {
  box-sizing: border-box;
}

html,
body {
  margin: 0;
  background: var(--fundo);
  color: var(--texto);
  font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
}

body {
  min-height: 100dvh;
}

main {
  max-width: 560px;
  margin: 0 auto;
  padding: 12px 16px calc(24px + env(safe-area-inset-bottom));
}

[hidden] {
  display: none !important;
}

h2 {
  margin: 0 0 8px;
}

.topo {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 4px 0 12px;
}

.topo h1 {
  flex: 1;
  margin: 0;
  font-size: 1.4rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cartao {
  background: var(--cartao);
  border: 1px solid var(--borda);
  border-radius: var(--raio);
  padding: 16px;
  margin-bottom: 14px;
}

.rotulo {
  margin: 0 0 6px;
  color: var(--suave);
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.status {
  margin: 0 0 12px;
  font-size: 1.05rem;
}

.status.conectada {
  color: var(--ok);
}

button {
  font: inherit;
  color: var(--texto);
  background: #222c33;
  border: 1px solid var(--borda);
  border-radius: 10px;
  padding: 12px 16px;
  min-height: 48px;
  cursor: pointer;
}

button:active {
  transform: scale(0.98);
}

button:disabled {
  opacity: 0.45;
  cursor: default;
}

button.primario {
  background: var(--acento);
  color: var(--acento-texto);
  border-color: transparent;
  font-weight: 600;
}

button.link {
  background: none;
  border: none;
  color: var(--suave);
  text-decoration: underline;
  padding: 10px 0 0;
  min-height: 0;
}

button.icone {
  width: 48px;
  padding: 0;
  font-size: 1.3rem;
}

.acoes {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.acoes > button {
  flex: 1 1 auto;
}

.linha {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 8px;
}

.lista {
  list-style: none;
  margin: 0;
  padding: 0;
}

.lista li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 0;
  border-top: 1px solid var(--borda);
}

.lista .info {
  flex: 1;
  min-width: 0;
}

.lista .nome {
  margin: 0;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lista .detalhe {
  margin: 2px 0 0;
  color: var(--suave);
  font-size: 0.9rem;
}

.vazio,
.dica {
  color: var(--suave);
}

.aviso {
  color: var(--acento);
}

.erro {
  color: var(--erro);
}

#diagnostico {
  white-space: pre-wrap;
  background: var(--campo);
  padding: 10px;
  border-radius: 8px;
  font-size: 0.85rem;
  user-select: all;
}

.mapa {
  height: 55vh;
  border-radius: var(--raio);
  overflow: hidden;
  border: 1px solid var(--borda);
  margin-bottom: 10px;
}

.mapa-pedal {
  height: 32vh;
}

.leaflet-container {
  background: #1b2328;
}

.grafico {
  display: block;
  width: 100%;
  height: 110px;
  margin: 10px 0;
}

input,
select {
  font: inherit;
  color: var(--texto);
  background: var(--campo);
  border: 1px solid var(--borda);
  border-radius: 10px;
  padding: 10px 12px;
  width: 100%;
  min-height: 44px;
}

label {
  display: block;
  margin: 10px 0;
  color: var(--suave);
  font-size: 0.9rem;
}

label input,
label select {
  margin-top: 4px;
}

.metricas {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

.metrica {
  background: var(--cartao);
  border: 1px solid var(--borda);
  border-radius: 12px;
  padding: 10px 6px;
  text-align: center;
}

.metrica span {
  display: block;
  font-size: 1.9rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  line-height: 1.1;
}

.metrica small {
  color: var(--suave);
  font-size: 0.78rem;
}

.metrica small span {
  display: inline;
  font-size: inherit;
  font-weight: inherit;
}

.metrica.destaque > span {
  color: var(--acento);
}

.controles {
  display: grid;
  gap: 8px;
  margin-top: 8px;
}

.carga {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  background: var(--cartao);
  border: 1px solid var(--borda);
  border-radius: 12px;
  padding: 6px;
  text-align: center;
}

.carga button {
  width: 56px;
  font-size: 1.4rem;
}

.carga b {
  font-size: 1.4rem;
}

.banner {
  position: sticky;
  top: 8px;
  z-index: 1100;
  background: var(--acento);
  color: var(--acento-texto);
  font-weight: 700;
  padding: 14px 16px;
  border-radius: 12px;
  margin-bottom: 8px;
}

.banner.info {
  background: #2b3a44;
  color: var(--texto);
}

.sobreposicao {
  position: fixed;
  inset: 0;
  z-index: 2000;
  background: rgba(8, 11, 13, 0.92);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
}

.sobreposicao .cartao {
  width: 100%;
  max-width: 420px;
}

.resumo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin: 12px 0 16px;
}

.resumo-grid small {
  color: var(--suave);
}

.resumo-grid b {
  display: block;
  font-size: 1.4rem;
}

dialog {
  background: var(--cartao);
  color: var(--texto);
  border: 1px solid var(--borda);
  border-radius: var(--raio);
  width: min(92vw, 420px);
  padding: 16px;
}

dialog::backdrop {
  background: rgba(0, 0, 0, 0.6);
}

summary {
  cursor: pointer;
  color: var(--suave);
  margin: 8px 0;
}

@media (max-width: 380px) {
  .metrica span {
    font-size: 1.5rem;
  }
}
```

- [ ] **Step 3: Gráfico de relevo**

<!-- file: src/ui/elevation-chart.js -->
```js
// Desenha o perfil de relevo num <canvas>, com marcador opcional da posição atual.
const CORES = {
  area: 'rgba(255, 138, 61, 0.30)',
  linha: '#ff8a3d',
  marcador: '#ffffff',
  texto: '#9aa7ad',
};

export function drawElevationChart(canvas, profile, markerDistance = null) {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (!w || !h) return;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);

  const { cum, alts, distance } = profile;
  if (alts.length < 2 || distance <= 0) return;

  const altMin = Math.min(...alts);
  const altMax = Math.max(...alts);
  // Garante ao menos 10 m de escala para não exagerar ruas quase planas.
  const meio = (altMin + altMax) / 2;
  const min = Math.min(altMin, meio - 5);
  const max = Math.max(altMax, meio + 5);
  const topo = 8;
  const base = h - 18;
  const x = (d) => (d / distance) * w;
  const y = (a) => topo + (1 - (a - min) / (max - min)) * (base - topo);

  ctx.beginPath();
  ctx.moveTo(0, base);
  alts.forEach((a, i) => ctx.lineTo(x(cum[i]), y(a)));
  ctx.lineTo(w, base);
  ctx.closePath();
  ctx.fillStyle = CORES.area;
  ctx.fill();

  ctx.beginPath();
  alts.forEach((a, i) => (i ? ctx.lineTo(x(cum[i]), y(a)) : ctx.moveTo(x(cum[i]), y(a))));
  ctx.strokeStyle = CORES.linha;
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = CORES.texto;
  ctx.font = '11px system-ui, sans-serif';
  ctx.textBaseline = 'bottom';
  ctx.fillText(`${Math.round(altMin)}–${Math.round(altMax)} m`, 4, h - 2);

  if (markerDistance != null) {
    const d = Math.min(Math.max(markerDistance, 0), distance);
    const mx = x(d);
    ctx.strokeStyle = CORES.marcador;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(mx, topo);
    ctx.lineTo(mx, base);
    ctx.stroke();
    ctx.fillStyle = CORES.marcador;
    ctx.beginPath();
    ctx.arc(mx, y(profile.elevationAt(d)), 5, 0, Math.PI * 2);
    ctx.fill();
  }
}
```

- [ ] **Step 4: Tela inicial e configurações**

<!-- file: src/ui/home.js -->
```js
// Tela inicial: status da bike e lista de rotas salvas.
import { formatKm } from './format.js';

const $ = (id) => document.getElementById(id);

function botao(texto, classe, onClick) {
  const b = document.createElement('button');
  b.type = 'button';
  b.textContent = texto;
  if (classe) b.className = classe;
  b.addEventListener('click', onClick);
  return b;
}

export function initHome({ storage, onConnect, onConnectAny, onSimulated, onNewRoute, onRide, onSettings }) {
  $('btn-conectar').addEventListener('click', onConnect);
  $('btn-todos').addEventListener('click', onConnectAny);
  $('btn-simulada').addEventListener('click', onSimulated);
  $('btn-nova-rota').addEventListener('click', onNewRoute);
  $('btn-config').addEventListener('click', onSettings);
  $('aviso-armazenamento').hidden = storage.available;

  function itemRota(rota) {
    const li = document.createElement('li');
    const info = document.createElement('div');
    info.className = 'info';
    const nome = document.createElement('p');
    nome.className = 'nome';
    nome.textContent = rota.nome;
    const detalhe = document.createElement('p');
    detalhe.className = 'detalhe';
    detalhe.textContent = `${formatKm(rota.distanciaM)} · ↑ ${rota.ganhoM} m`;
    info.append(nome, detalhe);

    const pedalar = botao('Pedalar', 'primario', () => onRide(rota));
    const apagar = botao('✕', 'icone', () => {
      if (confirm(`Apagar a rota “${rota.nome}”?`)) {
        storage.deleteRoute(rota.id);
        renderRoutes();
      }
    });
    apagar.setAttribute('aria-label', `Apagar ${rota.nome}`);
    li.append(info, pedalar, apagar);
    return li;
  }

  function renderRoutes() {
    const rotas = storage.listRoutes();
    $('lista-rotas').replaceChildren(...rotas.map(itemRota));
    $('sem-rotas').hidden = rotas.length > 0;
  }

  return {
    renderRoutes,
    setBikeStatus(texto, conectada) {
      const el = $('status-bike');
      el.textContent = texto;
      el.classList.toggle('conectada', !!conectada);
    },
    showDiagnostic(texto) {
      const el = $('diagnostico');
      el.textContent = texto ?? '';
      el.hidden = !texto;
    },
  };
}
```

<!-- file: src/ui/settings.js -->
```js
// Diálogo de configurações: peso, modo de potência e calibração da estimativa.
import { DEFAULT_CONFIG } from '../storage.js';

const numero = (valor, padrao) => {
  const n = Number(valor);
  return valor !== '' && valor != null && Number.isFinite(n) ? n : padrao;
};

export function initSettings({ storage, onChange }) {
  const dialogo = document.getElementById('dialogo-config');
  const form = document.getElementById('form-config');

  dialogo.addEventListener('close', () => {
    if (dialogo.returnValue !== 'salvar') return;
    const dados = new FormData(form);
    const config = {
      pesoKg: numero(dados.get('pesoKg'), DEFAULT_CONFIG.pesoKg),
      modoPotencia: dados.get('modoPotencia') || DEFAULT_CONFIG.modoPotencia,
      base: numero(dados.get('base'), DEFAULT_CONFIG.base),
      fator: numero(dados.get('fator'), DEFAULT_CONFIG.fator),
    };
    storage.saveConfig(config);
    onChange(config);
  });

  return {
    open(config) {
      form.elements.pesoKg.value = config.pesoKg;
      form.elements.modoPotencia.value = config.modoPotencia;
      form.elements.base.value = config.base;
      form.elements.fator.value = config.fator;
      dialogo.returnValue = '';
      dialogo.showModal();
    },
  };
}
```

- [ ] **Step 5: Editor de rota**

<!-- file: src/ui/route-editor.js -->
```js
// Tela "Nova rota": tocar pontos no mapa, calcular pelas ruas, ver o relevo e salvar.
import { buildRoute } from '../route/build-route.js';
import { createProfile } from '../route/profile.js';
import { drawElevationChart } from './elevation-chart.js';
import { formatKm } from './format.js';

const CENTRO_PADRAO = [-23.5505, -46.6333];
const $ = (id) => document.getElementById(id);

let mapa = null;
let camadaPontos = null;
let camadaRota = null;
let waypoints = [];
let rotaCalculada = null;
let versao = 0;
let armazenamento = null;
let aoTerminar = () => {};

export function openRouteEditor({ storage, onDone }) {
  armazenamento = storage;
  aoTerminar = onDone;
  waypoints = [];
  $('rota-nome').value = '';
  if (!mapa) iniciar();
  setTimeout(() => mapa.invalidateSize(), 0);
  invalidar();
}

function iniciar() {
  mapa = L.map('mapa-rota').setView(CENTRO_PADRAO, 13);
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap',
  }).addTo(mapa);
  camadaRota = L.layerGroup().addTo(mapa);
  camadaPontos = L.layerGroup().addTo(mapa);
  mapa.on('click', (e) => {
    waypoints.push([e.latlng.lat, e.latlng.lng]);
    invalidar();
  });
  mapa.locate({ setView: true, maxZoom: 16 });

  $('rota-voltar').addEventListener('click', () => aoTerminar());
  $('rota-desfazer').addEventListener('click', () => {
    waypoints.pop();
    invalidar();
  });
  $('rota-fechar').addEventListener('click', fecharVolta);
  $('rota-calcular').addEventListener('click', calcular);
  $('rota-salvar').addEventListener('click', salvar);
}

// Qualquer mudança nos pontos descarta a rota calculada.
function invalidar() {
  versao++;
  rotaCalculada = null;
  mensagem(null);
  desenhar();
}

function desenhar() {
  camadaPontos.clearLayers();
  camadaRota.clearLayers();
  waypoints.forEach((p, i) =>
    L.circleMarker(p, {
      radius: i === 0 ? 9 : 7,
      color: '#ffffff',
      weight: 2,
      fillColor: i === 0 ? '#4cd18a' : '#ff8a3d',
      fillOpacity: 1,
    }).addTo(camadaPontos),
  );
  if (rotaCalculada) {
    L.polyline(rotaCalculada.pontos.map((p) => [p[0], p[1]]), { color: '#ff8a3d', weight: 5 }).addTo(camadaRota);
  } else if (waypoints.length > 1) {
    L.polyline(waypoints, { color: '#ff8a3d', weight: 3, dashArray: '6 8', opacity: 0.8 }).addTo(camadaRota);
  }

  $('rota-dica').textContent =
    waypoints.length === 0
      ? 'Toque no mapa para marcar o início.'
      : waypoints.length === 1
        ? 'Agora toque nos próximos pontos do caminho.'
        : 'Quando terminar, toque em “Calcular”.';
  $('rota-desfazer').disabled = waypoints.length === 0;
  $('rota-fechar').disabled = waypoints.length < 2;
  $('rota-calcular').disabled = waypoints.length < 2;
  $('rota-resultado').hidden = !rotaCalculada;
}

function fecharVolta() {
  const primeiro = waypoints[0];
  const ultimo = waypoints.at(-1);
  if (waypoints.length >= 2 && (primeiro[0] !== ultimo[0] || primeiro[1] !== ultimo[1])) {
    waypoints.push([...primeiro]);
    invalidar();
  }
}

async function calcular() {
  const botao = $('rota-calcular');
  const minhaVersao = versao;
  botao.disabled = true;
  botao.textContent = 'Calculando…';
  mensagem(null);
  try {
    const { route, semAltimetria } = await buildRoute({ waypoints: waypoints.map((p) => [...p]) });
    if (minhaVersao !== versao) return;
    rotaCalculada = route;
    desenhar();
    $('rota-resumo').textContent =
      `${formatKm(route.distanciaM)} · ↑ ${route.ganhoM} m de subida · ↓ ${route.perdaM} m de descida`;
    drawElevationChart($('rota-grafico'), createProfile(route.pontos));
    if (semAltimetria) mensagem('Não consegui buscar a altimetria — a rota ficou plana.', 'aviso');
    mapa.fitBounds(L.latLngBounds(route.pontos.map((p) => [p[0], p[1]])), { padding: [20, 20] });
  } catch (e) {
    if (minhaVersao === versao) mensagem(e.message || 'Erro ao calcular a rota.', 'erro');
  } finally {
    botao.textContent = 'Calcular';
    botao.disabled = waypoints.length < 2;
  }
}

function salvar() {
  if (!rotaCalculada) return;
  const nome = $('rota-nome').value.trim() || `Rota de ${new Date().toLocaleDateString('pt-BR')}`;
  armazenamento.saveRoute({ ...rotaCalculada, nome });
  aoTerminar();
}

function mensagem(texto, tipo = 'erro') {
  const el = $('rota-msg');
  el.textContent = texto ?? '';
  el.className = tipo;
  el.hidden = !texto;
}
```

- [ ] **Step 6: Tela de pedal**

<!-- file: src/ui/ride-screen.js -->
```js
// Tela de pedal: liga a fonte da bike, a potência, a física e o mapa.
import { createProfile } from '../route/profile.js';
import { createRide } from '../ride.js';
import { createPowerResolver } from '../power.js';
import { drawElevationChart } from './elevation-chart.js';
import { formatNumber, formatTime, formatKm } from './format.js';

const TICK_MS = 250;
const DADOS_VELHOS_MS = 3000;
const $ = (id) => document.getElementById(id);

let mapa = null;
let camadaRota = null;
let marcador = null;

function iniciarMapa() {
  mapa = L.map('mapa-pedal', { zoomControl: false }).setView([0, 0], 16);
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap',
  }).addTo(mapa);
  camadaRota = L.layerGroup().addTo(mapa);
  marcador = L.circleMarker([0, 0], {
    radius: 9,
    color: '#ffffff',
    weight: 3,
    fillColor: '#ff8a3d',
    fillOpacity: 1,
  }).addTo(mapa);
}

export function openRideScreen({ route, source, config, onExit }) {
  if (!mapa) iniciarMapa();
  const profile = createProfile(route.pontos);
  const ride = createRide({ profile, riderMassKg: config.pesoKg });
  const potencia = createPowerResolver({
    mode: config.modoPotencia,
    calibration: { base: config.base, factor: config.fator },
  });

  let nivel = 4;
  let ultimoDado = 0;
  let ultimoMapa = 0;
  let avisouEstimativa = false;
  let resumoMostrado = false;
  let wakeLock = null;
  let bannerTimer = null;
  const removedores = [];
  const on = (el, evento, fn) => {
    el.addEventListener(evento, fn);
    removedores.push(() => el.removeEventListener(evento, fn));
  };

  camadaRota.clearLayers();
  L.polyline(route.pontos.map((p) => [p[0], p[1]]), { color: '#ff8a3d', weight: 5 }).addTo(camadaRota);
  marcador.setLatLng(profile.positionAt(0));
  setTimeout(() => {
    mapa.invalidateSize();
    mapa.setView(profile.positionAt(0), 16, { animate: false });
  }, 0);

  $('pedal-nome').textContent = route.nome;
  $('m-total').textContent = formatKm(profile.distance);
  $('controles-sim').hidden = !source.simulated;
  $('btn-reconectar').hidden = true;
  $('btn-pausa').hidden = false;
  $('resumo').hidden = true;
  $('pedal-aviso').hidden = true;
  $('carga-nivel').textContent = nivel;

  source.onData((dado) => {
    ultimoDado = Date.now();
    const watts = potencia.resolve(dado, nivel);
    ride.setInputs({ powerW: watts, cadenceRpm: dado.cadence ?? 0 });
    if (potencia.switchedToEstimate && !avisouEstimativa) {
      avisouEstimativa = true;
      banner('A bike não está mandando potência — estimando pela carga.', 'info');
    }
  });
  source.onDisconnect(() => {
    ride.pause();
    ride.setInputs({ powerW: 0, cadenceRpm: 0 });
    $('btn-reconectar').hidden = false;
    $('btn-pausa').hidden = true;
    banner('A bike desconectou.', 'info');
  });

  on($('carga-menos'), 'click', () => mudarNivel(-1));
  on($('carga-mais'), 'click', () => mudarNivel(1));
  on($('sim-fraco'), 'click', () => source.easier?.());
  on($('sim-forte'), 'click', () => source.harder?.());
  on($('btn-pausa'), 'click', () => {
    if (ride.state === 'pedalando') ride.pause();
    else ride.resume();
    render();
  });
  on($('btn-reconectar'), 'click', async () => {
    try {
      await source.connect();
      $('btn-reconectar').hidden = true;
      $('btn-pausa').hidden = false;
      ride.resume();
    } catch (e) {
      banner(`Não reconectou: ${e.message}`, 'info');
    }
  });
  on($('btn-sair'), 'click', () => {
    if (ride.state === 'concluido' || confirm('Encerrar o pedal?')) sair();
  });
  on($('resumo-voltar'), 'click', sair);
  on(document, 'visibilitychange', () => {
    if (document.visibilityState === 'visible' && ride.state !== 'concluido') manterTelaAcesa();
  });

  function mudarNivel(delta) {
    nivel = Math.min(10, Math.max(1, nivel + delta));
    $('carga-nivel').textContent = nivel;
  }

  async function manterTelaAcesa() {
    try {
      wakeLock = (await navigator.wakeLock?.request('screen')) ?? null;
    } catch {
      wakeLock = null;
    }
  }

  function liberarTela() {
    wakeLock?.release().catch(() => {});
    wakeLock = null;
  }

  function banner(texto, tipo = 'alerta') {
    const el = $('pedal-aviso');
    el.textContent = texto;
    el.className = tipo === 'info' ? 'banner info' : 'banner';
    el.hidden = false;
    clearTimeout(bannerTimer);
    bannerTimer = setTimeout(() => {
      el.hidden = true;
    }, 6000);
  }

  function avisar(alerta) {
    if (alerta.tipo === 'subida') {
      banner(`Subida de ${formatNumber(alerta.inclinacao * 100)}% chegando — aumente a carga`);
    } else {
      banner('Descida chegando — pode aliviar');
    }
    navigator.vibrate?.(200);
  }

  function render() {
    const s = ride.snapshot();
    $('m-vel').textContent = formatNumber(s.speedKmh, 1);
    $('m-pot').textContent = formatNumber(s.power);
    $('m-rpm').textContent = formatNumber(s.cadence);
    $('m-incl').textContent = formatNumber(s.grade * 100, 1);
    $('m-dist').textContent = formatNumber(s.distance / 1000, 2);
    $('m-tempo').textContent = formatTime(s.movingTime);
    $('btn-pausa').textContent = s.state === 'pausado' ? 'Continuar' : 'Pausar';
    $('pedal-modo').textContent =
      potencia.effectiveMode === 'estimada'
        ? `Potência estimada pela carga ${nivel}.`
        : 'Potência medida pela bike.';

    const agora = performance.now();
    if (agora - ultimoMapa > 1000 || s.state === 'concluido') {
      ultimoMapa = agora;
      marcador.setLatLng(s.position);
      mapa.panTo(s.position, { animate: false });
      drawElevationChart($('pedal-grafico'), profile, s.distance);
    }
    if (s.state === 'concluido' && !resumoMostrado) mostrarResumo(s);
  }

  function mostrarResumo(s) {
    resumoMostrado = true;
    clearInterval(timer);
    liberarTela();
    $('r-dist').textContent = formatKm(s.distance);
    $('r-tempo').textContent = formatTime(s.movingTime);
    $('r-pot').textContent = `${formatNumber(s.avgPower)} W`;
    $('r-vel').textContent = `${formatNumber(s.avgSpeedKmh, 1)} km/h`;
    $('r-subida').textContent = `${Math.round(profile.gain)} m`;
    $('resumo').hidden = false;
  }

  function sair() {
    clearInterval(timer);
    clearTimeout(bannerTimer);
    removedores.forEach((remover) => remover());
    source.onData(() => {});
    source.onDisconnect(() => {});
    liberarTela();
    onExit();
  }

  let ultimoTick = performance.now();
  const timer = setInterval(() => {
    const agora = performance.now();
    const dt = Math.min(1, (agora - ultimoTick) / 1000);
    ultimoTick = agora;
    if (Date.now() - ultimoDado > DADOS_VELHOS_MS) ride.setInputs({ powerW: 0, cadenceRpm: 0 });
    ride.advance(dt).forEach(avisar);
    render();
  }, TICK_MS);

  manterTelaAcesa();
  ride.start();
  render();
}
```

- [ ] **Step 7: Ligação geral**

<!-- file: src/app.js -->
```js
// Ponto de entrada: navegação entre telas e a fonte da bike atual.
import { createStorage } from './storage.js';
import { createFtmsSource, isBluetoothAvailable, NoFtmsError } from './bike/ftms-source.js';
import { createSimSource } from './bike/sim-source.js';
import { initHome } from './ui/home.js';
import { initSettings } from './ui/settings.js';
import { openRouteEditor } from './ui/route-editor.js';
import { openRideScreen } from './ui/ride-screen.js';

const TELAS = ['tela-inicio', 'tela-rota', 'tela-pedal'];
const storage = createStorage();
let config = storage.loadConfig();
let fonte = null;

function mostrar(id) {
  for (const tela of TELAS) document.getElementById(tela).hidden = tela !== id;
  window.scrollTo(0, 0);
}

const settings = initSettings({
  storage,
  onChange: (novo) => {
    config = novo;
  },
});

const home = initHome({
  storage,
  onConnect: () => conectar(false),
  onConnectAny: () => conectar(true),
  onSimulated: usarSimulada,
  onNewRoute: () => {
    mostrar('tela-rota');
    openRouteEditor({ storage, onDone: voltarAoInicio });
  },
  onRide: pedalar,
  onSettings: () => settings.open(config),
});

function trocarFonte(nova) {
  if (fonte && fonte !== nova) fonte.disconnect();
  fonte = nova;
  ouvirNoInicio();
}

function ouvirNoInicio() {
  fonte.onData(() => {});
  fonte.onDisconnect(() =>
    home.setBikeStatus('A bike desconectou. Toque em “Conectar bike” de novo.', false),
  );
}

async function conectar(qualquerAparelho) {
  home.showDiagnostic(null);
  if (!isBluetoothAvailable()) {
    home.setBikeStatus('Este navegador não tem Bluetooth. Abra no Chrome do Android — ou use a bike simulada.', false);
    return;
  }
  const nova = createFtmsSource({ acceptAllDevices: qualquerAparelho });
  home.setBikeStatus('Procurando a bike…', false);
  try {
    await nova.connect();
    trocarFonte(nova);
    home.setBikeStatus(`${nova.deviceName} conectada`, true);
  } catch (e) {
    if (e instanceof NoFtmsError) {
      home.setBikeStatus('A bike conectou, mas não usa o padrão FTMS. Copie o texto abaixo e me mande:', false);
      home.showDiagnostic(e.message);
    } else if (/cancel/i.test(e.message)) {
      home.setBikeStatus('Nenhuma bike escolhida.', false);
    } else {
      home.setBikeStatus(`Não foi possível conectar: ${e.message}`, false);
    }
  }
}

async function usarSimulada() {
  home.showDiagnostic(null);
  const sim = createSimSource();
  await sim.connect();
  trocarFonte(sim);
  home.setBikeStatus('Bike simulada conectada', true);
}

function pedalar(rota) {
  if (!fonte?.connected) {
    home.setBikeStatus('Conecte a bike (ou use a simulada) antes de pedalar.', false);
    return;
  }
  mostrar('tela-pedal');
  openRideScreen({ route: rota, source: fonte, config, onExit: voltarAoInicio });
}

function voltarAoInicio() {
  mostrar('tela-inicio');
  home.renderRoutes();
  if (fonte) {
    ouvirNoInicio();
    home.setBikeStatus(fonte.connected ? `${fonte.deviceName} conectada` : 'Bike desconectada', fonte.connected);
  }
}

home.renderRoutes();
if (!isBluetoothAvailable()) {
  home.setBikeStatus('Sem Bluetooth neste navegador — use o Chrome do Android ou a bike simulada.', false);
}
```

- [ ] **Step 8: Rodar os testes (nada pode ter quebrado)**

Run: `node --test`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add index.html styles.css src/app.js src/ui
git commit -m "feat: interface com início, editor de rota e tela de pedal"
```

---

### Task 11: Servidor local e verificação no navegador

**Files:**
- Create: `serve.js`, `.claude/launch.json`, `README.md`

**Interfaces:**
- Consumes: o app inteiro.

- [ ] **Step 1: Servidor estático local**

<!-- file: serve.js -->
```js
// Servidor estático mínimo para testar no navegador: node serve.js (porta 8080 ou $PORT).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, sep } from 'node:path';

const TIPOS = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
};
const raiz = process.cwd();
const porta = Number(process.env.PORT) || 8080;

createServer(async (req, res) => {
  const caminho = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const arquivo = normalize(join(raiz, caminho === '/' ? 'index.html' : caminho));
  if (arquivo !== raiz && !arquivo.startsWith(raiz + sep)) {
    res.writeHead(403).end();
    return;
  }
  try {
    const corpo = await readFile(arquivo);
    res.writeHead(200, {
      'Content-Type': TIPOS[extname(arquivo)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(corpo);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('não encontrado');
  }
}).listen(porta, () => console.log(`Pedal Local em http://localhost:${porta}`));
```

<!-- file: .claude/launch.json -->
```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "pedal-local",
      "runtimeExecutable": "node",
      "runtimeArgs": ["serve.js"],
      "port": 8080
    }
  ]
}
```

<!-- file: README.md -->
```markdown
# Pedal Local (protótipo)

Pedale, numa bicicleta ergométrica em casa, uma rota real do seu bairro. O app lê a
bike pelo Bluetooth (padrão FTMS), traça a rota pelas ruas, puxa a altimetria e
simula subidas e descidas na velocidade virtual.

## Rodar no computador

    node serve.js

Abra http://localhost:8080 no Chrome. Sem bike, use “Usar bike simulada”.

## Testes

    node --test

## Usar no celular

O Bluetooth no navegador só funciona em endereço `https` (ou `localhost`).
Para o celular, publique a pasta (por exemplo no GitHub Pages) e abra o link
no Chrome do Android.

## Serviços usados

- Mapa: OpenStreetMap
- Rotas: OSRM (routing.openstreetmap.de, perfil bicicleta)
- Altimetria: Open-Meteo Elevation API
```

- [ ] **Step 2: Rodar os testes**

Run: `node --test`
Expected: PASS

- [ ] **Step 3: Verificação manual no navegador (modo simulado)**

Subir o servidor (`preview_start` com `pedal-local`) e conferir:
1. Início carrega sem erros no console; lista vazia mostra a mensagem.
2. “Usar bike simulada” → status verde “Bike simulada conectada”.
3. “Nova rota” → mapa aparece; tocar 3+ pontos; “Calcular” → linha laranja pelas ruas, resumo com km e subida, gráfico de relevo.
4. “Salvar rota” → volta ao início com a rota na lista.
5. “Pedalar” → métricas mudam a cada segundo, marcador anda no mapa e no gráfico; “Simular: mais forte” aumenta velocidade; “Pausar/Continuar” funcionam.
6. Configurações abre, salva peso, e o valor persiste ao reabrir.
7. Largura de celular (375 px) sem rolagem horizontal.

- [ ] **Step 4: Commit**

```bash
git add serve.js .claude/launch.json README.md
git commit -m "chore: servidor local e README"
```

---

### Task 12: Publicar para testar no celular

Web Bluetooth exige HTTPS. Opções (decisão do usuário, pois envolve conta e publicação):

- **A) GitHub Pages:** usuário cria conta/repo no GitHub; publicar a pasta na branch `main` com Pages ativado em *Settings → Pages → Deploy from branch*. Link fica `https://<usuario>.github.io/<repo>/`.
- **B) Rede local sem conta:** `node serve.js` no PC; no Chrome do Android, em `chrome://flags/#unsafely-treat-insecure-origin-as-secure`, adicionar `http://<IP-do-PC>:8080`, reiniciar o Chrome e abrir esse endereço (celular e PC na mesma rede Wi-Fi; liberar o Node no firewall do Windows).

- [ ] **Step 1: Perguntar ao usuário qual opção prefere e seguir os passos dela.**
- [ ] **Step 2: No celular, à noite: conectar a bike real. Se não aparecer na lista, usar “Procurar todos os aparelhos”. Se aparecer o diagnóstico (sem FTMS), o usuário manda o texto e o protocolo FitShow vira uma nova tarefa.**
