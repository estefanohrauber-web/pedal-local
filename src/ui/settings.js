// Diálogo de configurações: peso, modo de potência e calibração da estimativa.
import { DEFAULT_CONFIG } from '../storage.js';

const numero = (valor, padrao) => {
  const n = Number(valor);
  return valor !== '' && valor != null && Number.isFinite(n) ? n : padrao;
};

export function initSettings({ storage, onChange }) {
  const dialogo = document.getElementById('dialogo-config');
  const form = document.getElementById('form-config');

  dialogo.addEventListener('close', () => {
    if (dialogo.returnValue !== 'salvar') return;
    const dados = new FormData(form);
    const config = {
      pesoKg: numero(dados.get('pesoKg'), DEFAULT_CONFIG.pesoKg),
      modoPotencia: dados.get('modoPotencia') || DEFAULT_CONFIG.modoPotencia,
      base: numero(dados.get('base'), DEFAULT_CONFIG.base),
      fator: numero(dados.get('fator'), DEFAULT_CONFIG.fator),
    };
    storage.saveConfig(config);
    onChange(config);
  });

  return {
    open(config) {
      form.elements.pesoKg.value = config.pesoKg;
      form.elements.modoPotencia.value = config.modoPotencia;
      form.elements.base.value = config.base;
      form.elements.fator.value = config.fator;
      dialogo.returnValue = '';
      dialogo.showModal();
    },
  };
}
