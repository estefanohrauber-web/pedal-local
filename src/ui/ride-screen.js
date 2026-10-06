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
