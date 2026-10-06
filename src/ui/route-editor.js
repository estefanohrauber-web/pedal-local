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
