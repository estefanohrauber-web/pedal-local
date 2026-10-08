/// Plano de várias semanas: em cada semana, os treinos (ids da biblioteca) na ordem sugerida.
class TrainingPlan {
  const TrainingPlan({required this.id, required this.name, required this.summary, required this.weeks});

  final String id;
  final String name;
  final String summary;
  final List<List<String>> weeks;

  List<String> get sessions => [for (final w in weeks) ...w];
}

const trainingPlans = [
  TrainingPlan(
    id: 'comecando',
    name: 'Começando · 4 semanas',
    summary: '3 pedais por semana, de 15 a 40 minutos. Para quem está começando ou voltando. Termina com o teste de FTP.',
    weeks: [
      ['primeiro-giro', 'cadencia-alta', 'primeiro-giro'],
      ['intervalos-5x1', 'recuperacao', 'resistencia-30'],
      ['piramide', 'cadencia-alta', 'resistencia-40'],
      ['teste-rampa', 'recuperacao', 'subida-longa'],
    ],
  ),
  TrainingPlan(
    id: 'mais-folego',
    name: 'Mais fôlego · 6 semanas',
    summary: '3 pedais por semana para subir o FTP: base, sweet spot e intervalos. A 4ª semana é mais leve. Testa no começo e no fim.',
    weeks: [
      ['teste-rampa', 'resistencia-40', 'cadencia-alta'],
      ['sweet-spot-2x10', 'resistencia-40', 'intervalos-5x1'],
      ['sweet-spot-2x10', 'piramide', 'resistencia-40'],
      ['recuperacao', 'cadencia-alta', 'resistencia-30'],
      ['sweet-spot-2x10', 'sprints', 'subida-longa'],
      ['piramide', 'recuperacao', 'teste-rampa'],
    ],
  ),
  TrainingPlan(
    id: 'subidas',
    name: 'Rei das subidas · 4 semanas',
    summary: '3 pedais por semana com uma subida longa em cada uma. Para encarar as ladeiras do bairro.',
    weeks: [
      ['teste-rampa', 'subida-longa', 'resistencia-40'],
      ['sweet-spot-2x10', 'subida-longa', 'cadencia-alta'],
      ['piramide', 'subida-longa', 'tabata'],
      ['recuperacao', 'subida-longa', 'sprints'],
    ],
  ),
];

TrainingPlan? planById(String? id) {
  for (final p in trainingPlans) {
    if (p.id == id) return p;
  }
  return null;
}

/// Um treino terminado.
class DoneWorkout {
  const DoneWorkout(this.workoutId, this.at);

  final String workoutId;
  final DateTime at;
}

class PlanProgress {
  const PlanProgress(this.plan, this.done);

  final TrainingPlan plan;

  /// Uma marca por sessão do plano, na ordem.
  final List<bool> done;

  int get doneCount => done.where((d) => d).length;
  int get total => done.length;
  bool get finished => doneCount == total;

  /// Primeira sessão ainda não feita (null = plano terminado).
  int? get nextIndex {
    final i = done.indexOf(false);
    return i < 0 ? null : i;
  }

  String? get nextWorkoutId => nextIndex == null ? null : plan.sessions[nextIndex!];

  /// Semana (começa em 0) de uma sessão.
  int weekOf(int session) {
    var inicio = 0;
    for (var w = 0; w < plan.weeks.length; w++) {
      if (session < inicio + plan.weeks[w].length) return w;
      inicio += plan.weeks[w].length;
    }
    return plan.weeks.length - 1;
  }

  /// Semana atual: a da próxima sessão (ou a última, com o plano terminado).
  int get week => nextIndex == null ? plan.weeks.length - 1 : weekOf(nextIndex!);

  int doneInWeek(int w) {
    var inicio = 0;
    for (var i = 0; i < w; i++) {
      inicio += plan.weeks[i].length;
    }
    return done.sublist(inicio, inicio + plan.weeks[w].length).where((d) => d).length;
  }
}

/// Progresso do plano iniciado em [inicio]: cada treino feito depois do início marca a primeira
/// sessão ainda aberta com o mesmo treino (a ordem dentro do plano é só uma sugestão).
PlanProgress planProgress(TrainingPlan plan, DateTime inicio, List<DoneWorkout> feitos) {
  final sessoes = plan.sessions;
  final done = List.filled(sessoes.length, false);
  final validos = [for (final f in feitos) if (!f.at.isBefore(inicio)) f]..sort((a, b) => a.at.compareTo(b.at));
  for (final f in validos) {
    final i = [for (var k = 0; k < sessoes.length; k++) k].firstWhere(
      (k) => !done[k] && sessoes[k] == f.workoutId,
      orElse: () => -1,
    );
    if (i >= 0) done[i] = true;
  }
  return PlanProgress(plan, done);
}

/// Como foi o treino (a pergunta do fim, como no TrainerRoad).
enum Feeling {
  facil('Fácil', 0.03),
  naMedida('Na medida', 0.01),
  dificil('Difícil', 0),
  muitoDificil('Muito difícil', -0.03),
  naoTerminei('Não consegui terminar', -0.05);

  const Feeling(this.label, this.delta);

  final String label;

  /// Quanto muda a intensidade dos próximos treinos.
  final double delta;
}

const minIntensity = 0.85;
const maxIntensity = 1.15;

/// Intensidade dos próximos treinos depois da resposta: sobe se foi fácil, desce se foi demais.
double adjustIntensity(double atual, Feeling f) =>
    ((atual + f.delta) * 100).roundToDouble().clamp(minIntensity * 100, maxIntensity * 100) / 100;
