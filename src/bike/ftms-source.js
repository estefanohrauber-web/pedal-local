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
