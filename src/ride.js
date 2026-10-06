// Sessão de pedal sobre um perfil de rota.
// Estados: pronto → pedalando ⇄ pausado → concluido.
import { stepSpeed, DT } from './physics.js';

export const ALERT_LOOKAHEAD_M = 200;
export const CLIMB_ALERT = 0.04;
export const DESCENT_ALERT = -0.03;

export function createRide({ profile, riderMassKg }) {
  let state = 'pronto';
  let speed = 0;
  let distance = 0;
  let movingTime = 0;
  let energyJ = 0;
  let power = 0;
  let cadence = 0;
  // Um aviso só volta a disparar depois que o trecho à frente deixa de ser subida/descida.
  const armed = { subida: true, descida: true };

  function checkAlert() {
    const g = profile.lookahead(distance, ALERT_LOOKAHEAD_M);
    if (g < CLIMB_ALERT / 2) armed.subida = true;
    if (g > DESCENT_ALERT / 2) armed.descida = true;
    if (armed.subida && g >= CLIMB_ALERT) {
      armed.subida = false;
      return { tipo: 'subida', inclinacao: g };
    }
    if (armed.descida && g <= DESCENT_ALERT) {
      armed.descida = false;
      return { tipo: 'descida', inclinacao: g };
    }
    return null;
  }

  return {
    get state() {
      return state;
    },
    start() {
      if (state === 'pronto') state = 'pedalando';
    },
    pause() {
      if (state === 'pedalando') {
        state = 'pausado';
        speed = 0;
      }
    },
    resume() {
      if (state === 'pausado') state = 'pedalando';
    },
    setInputs({ powerW, cadenceRpm }) {
      power = Math.max(0, powerW || 0);
      cadence = cadenceRpm || 0;
    },
    advance(seconds) {
      const alerts = [];
      let remaining = seconds;
      while (state === 'pedalando' && remaining > 1e-9) {
        const dt = Math.min(DT, remaining);
        remaining -= dt;
        const grade = profile.gradeAt(distance);
        speed = stepSpeed(speed, { powerW: power, grade, riderMassKg }, dt);
        distance += speed * dt;
        if (speed > 0 || power > 0) {
          movingTime += dt;
          energyJ += power * dt;
        }
        if (distance >= profile.distance) {
          distance = profile.distance;
          state = 'concluido';
          break;
        }
        const alert = checkAlert();
        if (alert) alerts.push(alert);
      }
      return alerts;
    },
    snapshot() {
      return {
        state,
        distance,
        total: profile.distance,
        speedKmh: speed * 3.6,
        power,
        cadence,
        grade: profile.gradeAt(distance),
        position: profile.positionAt(distance),
        movingTime,
        avgPower: movingTime > 0 ? energyJ / movingTime : 0,
        avgSpeedKmh: movingTime > 0 ? (distance / movingTime) * 3.6 : 0,
      };
    },
  };
}
