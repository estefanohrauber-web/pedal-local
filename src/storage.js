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
