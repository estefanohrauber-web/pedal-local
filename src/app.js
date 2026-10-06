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
