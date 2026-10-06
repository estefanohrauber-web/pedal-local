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
