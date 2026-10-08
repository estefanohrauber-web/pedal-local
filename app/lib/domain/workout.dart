import 'dart:math' as math;

import 'training.dart';

/// Um trecho do treino. A potência alvo é uma fração do FTP; [from] → [to] faz uma rampa.
class WorkoutStep {
  const WorkoutStep(this.seconds, this.from, {double? to, this.cadenceMin, this.cadenceMax, this.grade = 0, this.cue})
      : to = to ?? from;

  final int seconds;
  final double from;
  final double to;
  final int? cadenceMin;
  final int? cadenceMax;

  /// Inclinação simulada (fração): a velocidade cai como numa subida de verdade.
  final double grade;

  /// O que dizer no começo do trecho (“Sprint!”, “Recupere”).
  final String? cue;

  bool get isRamp => (to - from).abs() > 1e-9;
  bool get hasCadence => cadenceMin != null;

  /// Fração do FTP após [t] segundos dentro do trecho.
  double fractionAt(double t) => isRamp ? from + (to - from) * (t / seconds).clamp(0.0, 1.0) : from;

  /// A fração do meio do trecho: é ela que dá a zona e a cor.
  double get mid => (from + to) / 2;
}

/// Onde o treino está num instante.
class WorkoutPosition {
  const WorkoutPosition(this.index, this.inStep, this.remaining);

  final int index;

  /// Segundos já feitos no trecho e quanto falta nele.
  final double inStep;
  final double remaining;
}

class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.steps,
    this.rampTest = false,
  });

  final String id;
  final String name;
  final String summary;
  final String category;
  final List<WorkoutStep> steps;

  /// Teste de rampa: sobe até não aguentar; o resultado vira o FTP.
  final bool rampTest;

  int get seconds => steps.fold(0, (s, p) => s + p.seconds);

  /// Início (s) de cada trecho.
  List<int> get starts {
    final out = <int>[];
    var t = 0;
    for (final s in steps) {
      out.add(t);
      t += s.seconds;
    }
    return out;
  }

  /// Trecho em [t] segundos; depois do fim, o último trecho com nada faltando.
  WorkoutPosition at(double t) {
    var inicio = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final fim = inicio + steps[i].seconds;
      if (t < fim - 1e-9) return WorkoutPosition(i, math.max(0, t - inicio), fim - t);
      inicio = fim;
    }
    return WorkoutPosition(steps.length - 1, steps.last.seconds.toDouble(), 0);
  }

  /// Intensidade média (raiz da média dos quadrados das frações), como o IF dos apps de treino.
  double get intensity {
    var soma = 0.0;
    for (final s in steps) {
      final f = s.mid;
      soma += s.seconds * f * f;
    }
    return seconds == 0 ? 0 : math.sqrt(soma / seconds);
  }

  /// Carga do treino (TSS): 100 = uma hora no FTP.
  double get stress => seconds * intensity * intensity / 36;

  String get level {
    final i = intensity;
    if (i < 0.62) return 'Leve';
    if (i < 0.72) return 'Moderado';
    if (i < 0.80) return 'Difícil';
    return 'Muito difícil';
  }

  /// A zona mais alta do treino.
  TrainingZone get peakZone => zoneFor(steps.map((s) => math.max(s.from, s.to)).reduce(math.max));
}

// --- Biblioteca ---

List<WorkoutStep> _aquecer(int min, {double de = 0.45, double ate = 0.65}) => [WorkoutStep(min * 60, de, to: ate, cue: 'Aquecendo')];
List<WorkoutStep> _soltar(int min, {double de = 0.55, double ate = 0.4}) => [WorkoutStep(min * 60, de, to: ate, cue: 'Soltando as pernas')];
List<WorkoutStep> _repetir(int vezes, List<WorkoutStep> bloco) => [for (var i = 0; i < vezes; i++) ...bloco];

const _recupere = 'Recupere';

final rampTestWorkout = Workout(
  id: 'teste-rampa',
  name: 'Teste de rampa (FTP)',
  summary: 'A carga sobe um pouco a cada minuto até você não aguentar. Dá o seu FTP, que acerta todos os treinos.',
  category: 'Teste',
  rampTest: true,
  steps: [
    const WorkoutStep(300, 0.4, to: 0.55, cue: 'Aquecendo. Depois a carga sobe a cada minuto'),
    for (var i = 0; i < 30; i++) WorkoutStep(60, 0.5 + 0.06 * i, cadenceMin: 80, cadenceMax: 100),
    const WorkoutStep(300, 0.4, to: 0.3, cue: 'Soltando as pernas'),
  ],
);

final workoutLibrary = <Workout>[
  Workout(
    id: 'primeiro-giro',
    name: 'Primeiro giro',
    summary: 'Pedal leve e constante para pegar o jeito. Dá para conversar o tempo todo.',
    category: 'Para começar',
    steps: [..._aquecer(5, ate: 0.6), const WorkoutStep(600, 0.62, cadenceMin: 80, cadenceMax: 90), ..._soltar(5, de: 0.5)],
  ),
  Workout(
    id: 'cadencia-alta',
    name: 'Cadência alta',
    summary: 'Carga leve e giro rápido, acima de 95 rpm. Deixa a pedalada redonda e poupa os joelhos.',
    category: 'Para começar',
    steps: [
      ..._aquecer(3, ate: 0.55),
      ..._repetir(4, const [
        WorkoutStep(90, 0.6, cadenceMin: 95, cadenceMax: 105, cue: 'Giro rápido'),
        WorkoutStep(60, 0.5, cadenceMin: 80, cadenceMax: 90, cue: 'Giro normal'),
      ]),
      ..._soltar(2, de: 0.5),
    ],
  ),
  Workout(
    id: 'recuperacao',
    name: 'Recuperação',
    summary: 'Bem leve, para soltar as pernas no dia seguinte a um treino puxado.',
    category: 'Para começar',
    steps: const [WorkoutStep(1200, 0.48, cadenceMin: 85, cadenceMax: 95, cue: 'Bem leve, só soltando')],
  ),
  Workout(
    id: 'resistencia-30',
    name: 'Resistência 30 min',
    summary: 'Ritmo leve e contínuo. A base do condicionamento.',
    category: 'Resistência',
    steps: [..._aquecer(5), const WorkoutStep(1200, 0.68, cadenceMin: 80, cadenceMax: 95), ..._soltar(5)],
  ),
  Workout(
    id: 'resistencia-40',
    name: 'Resistência 40 min',
    summary: 'Mais tempo no ritmo leve, com três giros rápidos no meio para não ficar monótono.',
    category: 'Resistência',
    steps: [
      ..._aquecer(5),
      ..._repetir(3, const [
        WorkoutStep(570, 0.7, cadenceMin: 80, cadenceMax: 95),
        WorkoutStep(30, 0.75, cadenceMin: 100, cadenceMax: 110, cue: 'Giro rápido de 30 segundos'),
      ]),
      ..._soltar(5),
    ],
  ),
  Workout(
    id: 'sweet-spot-2x10',
    name: 'Sweet spot 2 × 10 min',
    summary: 'Dois blocos logo abaixo do seu limite: o treino que mais rende por minuto.',
    category: 'Resistência',
    steps: [
      ..._aquecer(8, ate: 0.7),
      const WorkoutStep(600, 0.9, cadenceMin: 85, cadenceMax: 95, cue: 'Bloco 1. Firme, mas dá para segurar'),
      const WorkoutStep(300, 0.55, cue: _recupere),
      const WorkoutStep(600, 0.9, cadenceMin: 85, cadenceMax: 95, cue: 'Bloco 2. Último!'),
      ..._soltar(7),
    ],
  ),
  Workout(
    id: 'intervalos-5x1',
    name: 'Intervalos 5 × 1 min',
    summary: 'Cinco tiros de um minuto forte com um minuto para recuperar.',
    category: 'Intervalos',
    steps: [
      ..._aquecer(5),
      ..._repetir(5, const [
        WorkoutStep(60, 1.05, cadenceMin: 85, cadenceMax: 100, cue: 'Forte!'),
        WorkoutStep(60, 0.5, cue: _recupere),
      ]),
      ..._soltar(5),
    ],
  ),
  Workout(
    id: 'piramide',
    name: 'Pirâmide 1-2-3-2-1',
    summary: 'Tiros de 1, 2, 3, 2 e 1 minuto. Quanto mais longo, um pouco mais leve.',
    category: 'Intervalos',
    steps: [
      ..._aquecer(6),
      const WorkoutStep(60, 1.08, cue: '1 minuto forte'),
      const WorkoutStep(60, 0.5, cue: _recupere),
      const WorkoutStep(120, 1.0, cue: '2 minutos forte'),
      const WorkoutStep(120, 0.5, cue: _recupere),
      const WorkoutStep(180, 0.95, cue: '3 minutos, o topo da pirâmide'),
      const WorkoutStep(180, 0.5, cue: _recupere),
      const WorkoutStep(120, 1.0, cue: '2 minutos forte'),
      const WorkoutStep(120, 0.5, cue: _recupere),
      const WorkoutStep(60, 1.08, cue: 'Último minuto forte!'),
      const WorkoutStep(60, 0.5, cue: _recupere),
      ..._soltar(5),
    ],
  ),
  Workout(
    id: 'tabata',
    name: 'Tabata 8 × 20 s',
    summary: 'Oito tiros de 20 segundos com tudo e 10 segundos de pausa. Curto e muito intenso.',
    category: 'Intervalos',
    steps: [
      ..._aquecer(6, ate: 0.7),
      ..._repetir(8, const [
        WorkoutStep(20, 1.7, cadenceMin: 95, cadenceMax: 120, cue: 'Tudo!'),
        WorkoutStep(10, 0.4, cue: 'Pausa'),
      ]),
      ..._soltar(6, de: 0.5),
    ],
  ),
  Workout(
    id: 'sprints',
    name: 'Sprints 6 × 15 s',
    summary: 'Seis arrancadas curtas com recuperação longa. Treina a explosão.',
    category: 'Intervalos',
    steps: [
      ..._aquecer(8, ate: 0.7),
      ..._repetir(6, const [
        WorkoutStep(15, 1.8, cadenceMin: 100, cadenceMax: 130, cue: 'Sprint!'),
        WorkoutStep(165, 0.5, cue: _recupere),
      ]),
      ..._soltar(4, de: 0.5),
    ],
  ),
  Workout(
    id: 'subida-longa',
    name: 'Subida longa simulada',
    summary: '20 minutos de subida de 4 % a 8 %: a velocidade cai como numa serra de verdade.',
    category: 'Subidas',
    steps: [
      ..._aquecer(5),
      const WorkoutStep(300, 0.8, cadenceMin: 70, cadenceMax: 85, grade: 0.04, cue: 'Começa a subida: 4 por cento'),
      const WorkoutStep(300, 0.85, cadenceMin: 70, cadenceMax: 85, grade: 0.05, cue: 'Ficou mais íngreme: 5 por cento'),
      const WorkoutStep(300, 0.9, cadenceMin: 70, cadenceMax: 85, grade: 0.06, cue: '6 por cento. Mantenha o ritmo'),
      const WorkoutStep(240, 0.95, cadenceMin: 65, cadenceMax: 80, grade: 0.08, cue: '8 por cento! A parte mais dura'),
      const WorkoutStep(60, 1.05, cadenceMin: 70, cadenceMax: 90, grade: 0.08, cue: 'Último minuto até o topo!'),
      const WorkoutStep(300, 0.5, to: 0.4, grade: -0.03, cue: 'Descida. Pode aliviar'),
    ],
  ),
  rampTestWorkout,
];

Workout? workoutById(String id) {
  for (final w in workoutLibrary) {
    if (w.id == id) return w;
  }
  return null;
}

/// Categorias na ordem da tela.
const workoutCategories = ['Para começar', 'Resistência', 'Intervalos', 'Subidas'];
