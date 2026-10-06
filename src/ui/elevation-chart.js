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
