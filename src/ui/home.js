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
