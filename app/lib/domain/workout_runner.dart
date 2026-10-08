import 'dart:math' as math;

import 'ride_narrator.dart';
import 'training.dart';
import 'workout.dart';

enum Compliance { semAlvo, naMeta, abaixo, acima }

/// O que a tela do treino mostra num instante.
class WorkoutFrame {
  const WorkoutFrame({
    required this.index,
    required this.step,
    required this.inStep,
    required this.remaining,
    required this.fraction,
    required this.targetWatts,
    required this.zone,
    required this.next,
    required this.nextWatts,
    required this.elapsed,
    required this.total,
    required this.compliance,
    required this.cadenceHint,
    required this.done,
    required this.rampEnded,
    required this.rampFtp,
  });

  final int index;
  final WorkoutStep step;
  final double inStep;
  final double remaining;
  final double fraction;
  final int targetWatts;
  final TrainingZone zone;
  final WorkoutStep? next;

  /// Meta do começo do próximo trecho.
  final int? nextWatts;

  /// Tempo do treino (com o pulo do teste de rampa) e duração total.
  final double elapsed;
  final int total;
  final Compliance compliance;

  /// “Gire mais rápido” / “Gire mais devagar”, quando o giro sai da faixa.
  final String? cadenceHint;
  final bool done;
  final bool rampEnded;

  /// FTP calculado no fim da rampa (null se não deu para calcular).
  final double? rampFtp;
}

/// Segundos para se ajustar a um trecho novo antes de dizer que está fora da meta.
const complianceGraceS = 8.0;

/// Fora da meta por tanto tempo seguido: a voz dá um toque (uma vez por trecho).
const nudgeAfterS = 15.0;

/// No teste de rampa: abaixo de 70 % do alvo por 15 s, ou quase parado por 10 s, acaba o teste.
const rampFailFraction = 0.7;
const rampFailAfterS = 15.0;
const rampStopCadence = 40.0;
const rampStopAfterS = 10.0;

/// Conduz um treino: em que trecho está, a meta, se está na meta e o que falar.
class WorkoutRunner {
  WorkoutRunner(this.workout, {required this.ftp, double intensity = 1})
      : intensity = workout.rampTest ? 1 : intensity;

  final Workout workout;
  final double ftp;

  /// Ajuste do plano (1 = como o treino foi escrito).
  final double intensity;

  double _skip = 0;
  double _lastClock = 0;
  int _index = -1;
  bool _avisouAntes = false;
  bool _deuToque = false;
  bool _falouMetade = false;
  double _foraDesde = -1;
  double _fracoDesde = -1;
  double _paradoDesde = -1;
  bool _rampEnded = false;
  double? _rampFtp;
  int? _rampStartSample;
  final _potencias = <double>[];
  final spoken = <String>[];

  /// Trecho que começou no último [update] (para mandar a nova carga para a bike).
  int? stepChanged;

  int get _rampFirst => 1;
  int get _cooldown => workout.steps.length - 1;

  bool get rampEnded => _rampEnded;
  double? get rampFtp => _rampFtp;

  int watts(double fraction) => (ftp * fraction * intensity).round();

  /// Uma amostra de potência por segundo do pedal (para o teste de rampa).
  void addSample(double power) => _potencias.add(power);

  /// Encerra a rampa (não aguenta mais): calcula o FTP e pula para soltar as pernas.
  void endRamp() {
    if (!workout.rampTest || _rampEnded) return;
    _rampEnded = true;
    final inicio = _rampStartSample ?? 0;
    final potencias = _potencias.sublist(math.min(inicio, _potencias.length));
    _rampFtp = potencias.length >= 60 ? rampTestFtp(potencias) : null;
    final inicioSoltar = workout.starts[_cooldown].toDouble();
    if (_lastClock < inicioSoltar) _skip += inicioSoltar - _lastClock;
    spoken.add(_rampFtp == null
        ? 'Teste encerrado cedo demais para calcular o FTP. Agora, pedal leve para soltar.'
        : 'Teste encerrado. Seu FTP é de ${_rampFtp!.round()} watts. Agora, 5 minutos leves para soltar as pernas.');
  }

  WorkoutFrame update(double movingTime, {required double power, required double cadence}) {
    spoken.clear();
    stepChanged = null;
    var clock = movingTime + _skip;
    _lastClock = clock;
    var pos = workout.at(clock);

    if (workout.rampTest && !_rampEnded && pos.index >= _rampFirst) {
      _rampStartSample ??= _potencias.length;
      if (pos.index >= _cooldown) {
        endRamp();
      } else {
        _vigiaRampa(clock, pos, power, cadence);
      }
      if (_rampEnded) {
        clock = movingTime + _skip;
        _lastClock = clock;
        pos = workout.at(clock);
      }
    }

    final step = workout.steps[pos.index];
    if (pos.index != _index) {
      _index = pos.index;
      stepChanged = pos.index;
      _avisouAntes = false;
      _deuToque = false;
      _falouMetade = false;
      _foraDesde = -1;
      if (!(workout.rampTest && _rampEnded && pos.index == _cooldown)) spoken.add(_fraseDoTrecho(pos.index));
    }

    final fracao = step.fractionAt(pos.inStep);
    final alvo = watts(fracao);
    final zona = zoneFor(step.mid);
    final proximo = pos.index + 1 < workout.steps.length ? workout.steps[pos.index + 1] : null;
    final done = clock >= workout.seconds - 1e-9;

    // Meta de potência e de giro.
    var compliance = Compliance.semAlvo;
    String? giro;
    if (!done && pos.inStep >= complianceGraceS) {
      final folga = math.max(8.0, alvo * 0.06);
      compliance = power < alvo - folga
          ? Compliance.abaixo
          : (power > alvo + folga && zona.number < 6 ? Compliance.acima : Compliance.naMeta);
      if (step.hasCadence && cadence > 0) {
        if (cadence < step.cadenceMin! - 3) giro = 'Gire mais rápido';
        if (cadence > step.cadenceMax! + 5) giro = 'Gire mais devagar';
      }
    }
    _toque(clock, pos, compliance, giro);

    // Aviso 5 s antes de um trecho forte.
    if (!_avisouAntes && proximo != null && pos.remaining <= 5 && zoneFor(proximo.mid).number >= 4 && zona.number < 4) {
      _avisouAntes = true;
      if (!(workout.rampTest && pos.index >= _rampFirst)) {
        spoken.add('Em 5 segundos: ${spokenTime(proximo.seconds.toDouble())} ${zoneFor(proximo.mid).effort.toLowerCase()}.');
      }
    }

    // Metade de um bloco longo.
    if (!_falouMetade && step.seconds >= 300 && zona.number >= 3 && pos.inStep >= step.seconds / 2) {
      _falouMetade = true;
      spoken.add('Metade do bloco.');
    }

    return WorkoutFrame(
      index: pos.index,
      step: step,
      inStep: pos.inStep,
      remaining: pos.remaining,
      fraction: fracao * intensity,
      targetWatts: alvo,
      zone: zona,
      next: proximo,
      nextWatts: proximo == null ? null : watts(proximo.from),
      elapsed: math.min(clock, workout.seconds.toDouble()),
      total: workout.seconds,
      compliance: compliance,
      cadenceHint: giro,
      done: done,
      rampEnded: _rampEnded,
      rampFtp: _rampFtp,
    );
  }

  void _vigiaRampa(double clock, WorkoutPosition pos, double power, double cadence) {
    final alvo = watts(workout.steps[pos.index].from);
    if (power < alvo * rampFailFraction) {
      if (_fracoDesde < 0) _fracoDesde = clock;
    } else {
      _fracoDesde = -1;
    }
    if (cadence < rampStopCadence) {
      if (_paradoDesde < 0) _paradoDesde = clock;
    } else {
      _paradoDesde = -1;
    }
    final fraco = _fracoDesde >= 0 && clock - _fracoDesde >= rampFailAfterS;
    final parado = _paradoDesde >= 0 && clock - _paradoDesde >= rampStopAfterS;
    if (fraco || parado) endRamp();
  }

  void _toque(double clock, WorkoutPosition pos, Compliance c, String? giro) {
    final fora = giro != null || c == Compliance.abaixo || c == Compliance.acima;
    if (!fora) {
      _foraDesde = -1;
      return;
    }
    if (_foraDesde < 0) _foraDesde = clock;
    if (_deuToque || clock - _foraDesde < nudgeAfterS || pos.remaining < 10) return;
    if (workout.rampTest && pos.index >= _rampFirst) return;
    _deuToque = true;
    spoken.add(giro != null
        ? '$giro.'
        : c == Compliance.abaixo
            ? 'Aumente um pouco a carga ou o giro.'
            : 'Alivie um pouco.');
  }

  String _fraseDoTrecho(int i) {
    final s = workout.steps[i];
    final alvo = watts(s.mid);
    if (workout.rampTest && i >= _rampFirst && i < _cooldown) {
      return i == _rampFirst
          ? 'Começou a rampa: ${watts(s.from)} watts. A carga sobe a cada minuto. Vá até não aguentar mais.'
          : '${watts(s.from)} watts.';
    }
    final cue = s.cue == null ? '' : '${s.cue}${s.cue!.endsWith('!') ? '' : '.'} ';
    final giro = s.hasCadence ? ', giro de ${s.cadenceMin} a ${s.cadenceMax}' : '';
    return '$cue${spokenTime(s.seconds.toDouble())} ${zoneFor(s.mid).effort.toLowerCase()}, $alvo watts$giro.';
  }
}
