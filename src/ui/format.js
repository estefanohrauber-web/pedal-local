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
