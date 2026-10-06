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
