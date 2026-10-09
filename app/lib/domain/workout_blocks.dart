import 'dart:convert';
import 'dart:math' as math;

import 'training.dart';
import 'workout.dart';

/// Os tipos de bloco do editor de treinos.
enum BlockKind { aquecer, ritmo, serie, rampa, subida, livre, soltar }

/// Nome de cada tipo, como aparece no editor.
const blockTitles = {
  BlockKind.aquecer: 'Aquecer',
  BlockKind.ritmo: 'Ritmo constante',
  BlockKind.serie: 'Série de tiros',
  BlockKind.rampa: 'Rampa',
  BlockKind.subida: 'Subida simulada',
  BlockKind.livre: 'Pedal livre',
  BlockKind.soltar: 'Soltar',
};

/// O que cada tipo faz, na lista de “Adicionar bloco”.
const blockHints = {
  BlockKind.aquecer: 'Começa leve e sobe aos poucos',
  BlockKind.ritmo: 'Um esforço só, pelo tempo que quiser',
  BlockKind.serie: 'Forte e leve, repetidos várias vezes',
  BlockKind.rampa: 'A carga sobe ou desce aos poucos',
  BlockKind.subida: 'Inclinação em %, como uma ladeira',
  BlockKind.livre: 'Sem meta, no seu ritmo',
  BlockKind.soltar: 'Desce a carga para terminar',
};

/// Categoria dos treinos montados pelo usuário.
const customWorkoutCategory = 'Meus treinos';

// Limites do editor.
const maxWorkoutName = 40;
const maxBlocks = 50;
const maxWorkoutSeconds = 4 * 3600;
const minBlockSeconds = 15;
const maxBlockSeconds = 2 * 3600;
const minReps = 2;
const maxReps = 30;
const minFraction = 0.30;
const maxFraction = 2.00;
const minCadence = 50;
const maxCadence = 130;
const minGrade = 0.01;
const maxGrade = 0.15;

/// A % de cada palavra de intensidade, uma por zona, na ordem de [trainingZones].
const zoneTargets = [0.50, 0.65, 0.82, 0.97, 1.12, 1.30, 1.60];

/// A frase do descanso na série.
const restCue = 'Recupere';

const _igual = Object();

/// Um bloco de um treino montado pelo usuário. Intensidades em fração do FTP.
class WorkoutBlock {
  const WorkoutBlock({
    required this.kind,
    required this.seconds,
    this.from = 0.7,
    double? to,
    this.cadenceMin,
    this.cadenceMax,
    this.grade = 0,
    this.cue,
    this.reps = 4,
    this.restSeconds = 60,
    this.restFraction = 0.5,
  }) : to = to ?? from;

  /// Um bloco novo, com os valores comuns de cada tipo.
  factory WorkoutBlock.novo(BlockKind kind) => switch (kind) {
    BlockKind.aquecer => const WorkoutBlock(kind: BlockKind.aquecer, seconds: 600, from: 0.45, to: 0.65),
    BlockKind.ritmo => const WorkoutBlock(kind: BlockKind.ritmo, seconds: 600, from: 0.70),
    BlockKind.serie => const WorkoutBlock(kind: BlockKind.serie, seconds: 60, from: 1.10),
    BlockKind.rampa => const WorkoutBlock(kind: BlockKind.rampa, seconds: 300, from: 0.60, to: 0.90),
    BlockKind.subida => const WorkoutBlock(
      kind: BlockKind.subida,
      seconds: 300,
      from: 0.85,
      cadenceMin: 70,
      cadenceMax: 85,
      grade: 0.06,
    ),
    BlockKind.livre => const WorkoutBlock(kind: BlockKind.livre, seconds: 300, from: 0.5),
    BlockKind.soltar => const WorkoutBlock(kind: BlockKind.soltar, seconds: 300, from: 0.55, to: 0.40),
  };

  factory WorkoutBlock.fromJson(Map<String, Object?> j) {
    double n(String k, double padrao) => (j[k] as num?)?.toDouble() ?? padrao;
    final from = n('from', 0.7);
    return WorkoutBlock(
      kind: BlockKind.values.asNameMap()[j['kind']] ?? BlockKind.ritmo,
      seconds: (j['s'] as num?)?.toInt() ?? 600,
      from: from,
      to: n('to', from),
      cadenceMin: (j['cmin'] as num?)?.toInt(),
      cadenceMax: (j['cmax'] as num?)?.toInt(),
      grade: n('grade', 0),
      cue: j['cue'] as String?,
      reps: (j['reps'] as num?)?.toInt() ?? 4,
      restSeconds: (j['rs'] as num?)?.toInt() ?? 60,
      restFraction: n('rf', 0.5),
    );
  }

  final BlockKind kind;

  /// Duração do bloco; na série, a de cada tiro.
  final int seconds;
  final double from;

  /// Onde termina: Aquecer, Rampa e Soltar sobem ou descem aos poucos.
  final double to;
  final int? cadenceMin;
  final int? cadenceMax;

  /// Inclinação simulada (fração). O editor só mostra na Subida; a cópia de um treino pronto a guarda.
  final double grade;

  /// Frase da voz no começo do bloco (na série, de cada tiro).
  final String? cue;

  /// Série: repetições e o descanso depois de cada tiro.
  final int reps;
  final int restSeconds;
  final double restFraction;

  bool get hasRamp => kind == BlockKind.aquecer || kind == BlockKind.rampa || kind == BlockKind.soltar;

  /// Duração total do bloco (na série, todos os tiros e descansos).
  int get totalSeconds => kind == BlockKind.serie ? reps * (seconds + restSeconds) : seconds;

  /// Muda o bloco. Num bloco sem rampa, o fim acompanha o começo. Giro e frase aceitam null.
  WorkoutBlock copyWith({
    int? seconds,
    double? from,
    double? to,
    Object? cadenceMin = _igual,
    Object? cadenceMax = _igual,
    double? grade,
    Object? cue = _igual,
    int? reps,
    int? restSeconds,
    double? restFraction,
  }) => WorkoutBlock(
    kind: kind,
    seconds: seconds ?? this.seconds,
    from: from ?? this.from,
    to: to ?? (from != null && !hasRamp ? from : this.to),
    cadenceMin: identical(cadenceMin, _igual) ? this.cadenceMin : cadenceMin as int?,
    cadenceMax: identical(cadenceMax, _igual) ? this.cadenceMax : cadenceMax as int?,
    grade: grade ?? this.grade,
    cue: identical(cue, _igual) ? this.cue : cue as String?,
    reps: reps ?? this.reps,
    restSeconds: restSeconds ?? this.restSeconds,
    restFraction: restFraction ?? this.restFraction,
  );

  /// Os trechos que o treino pedala.
  List<WorkoutStep> toSteps() => switch (kind) {
    BlockKind.serie => [
      for (var r = 1; r <= reps; r++) ...[
        WorkoutStep(
          seconds,
          from,
          cadenceMin: cadenceMin,
          cadenceMax: cadenceMax,
          cue: cue == null ? 'Tiro $r de $reps' : 'Tiro $r de $reps. $cue',
        ),
        WorkoutStep(restSeconds, restFraction, cue: restCue),
      ],
    ],
    BlockKind.livre => [WorkoutStep(seconds, 0.5, cue: cue, free: true)],
    _ => [
      WorkoutStep(
        seconds,
        from,
        to: hasRamp ? to : from,
        cadenceMin: cadenceMin,
        cadenceMax: cadenceMax,
        grade: grade,
        cue: cue,
      ),
    ],
  };

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    's': seconds,
    'from': from,
    'to': to,
    if (cadenceMin != null) 'cmin': cadenceMin,
    if (cadenceMax != null) 'cmax': cadenceMax,
    if (grade != 0) 'grade': grade,
    if (cue != null) 'cue': cue,
    if (kind == BlockKind.serie) ...{'reps': reps, 'rs': restSeconds, 'rf': restFraction},
  };
}

/// Um treino montado pelo usuário.
class CustomWorkout {
  const CustomWorkout({
    required this.id,
    required this.name,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomWorkout.fromRow(Map<String, Object?> r) => CustomWorkout(
    id: r['id'] as String,
    name: r['name'] as String,
    blocks: [
      for (final b in jsonDecode(r['blocks'] as String) as List)
        WorkoutBlock.fromJson((b as Map).cast<String, Object?>()),
    ],
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
  );

  final String id;
  final String name;
  final List<WorkoutBlock> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// O treino de sempre (desenho, tela, pedal e voz).
  Workout toWorkout() => Workout(
    id: id,
    name: name,
    summary: 'Montado por você: ${blocks.length} ${blocks.length == 1 ? 'bloco' : 'blocos'}.',
    category: customWorkoutCategory,
    steps: [for (final b in blocks) ...b.toSteps()],
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'blocks': jsonEncode([for (final b in blocks) b.toJson()]),
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

bool isCustomWorkoutId(String id) => id.startsWith('meu-');

String newCustomWorkoutId(DateTime agora, math.Random sorteio) =>
    'meu-${agora.microsecondsSinceEpoch.toRadixString(36)}${sorteio.nextInt(1 << 30).toRadixString(36)}';

/// Os blocos de um treino pronto, para “Copiar e editar”: o desenho fica igual. Pares de trechos
/// repetidos seguidos viram uma série (se o descanso não tiver giro próprio).
List<WorkoutBlock> blocksFromSteps(List<WorkoutStep> steps) {
  bool igual(WorkoutStep a, WorkoutStep b) =>
      a.seconds == b.seconds &&
      a.from == b.from &&
      a.to == b.to &&
      a.cadenceMin == b.cadenceMin &&
      a.cadenceMax == b.cadenceMax &&
      a.grade == b.grade &&
      a.cue == b.cue &&
      a.free == b.free;
  bool podeSerSerie(WorkoutStep tiro, WorkoutStep descanso) =>
      !tiro.isRamp &&
      !descanso.isRamp &&
      tiro.grade == 0 &&
      descanso.grade == 0 &&
      !tiro.free &&
      !descanso.free &&
      !descanso.hasCadence;

  final blocos = <WorkoutBlock>[];
  var i = 0;
  while (i < steps.length) {
    final s = steps[i];
    if (i + 3 < steps.length &&
        podeSerSerie(s, steps[i + 1]) &&
        igual(s, steps[i + 2]) &&
        igual(steps[i + 1], steps[i + 3])) {
      var reps = 2;
      while (i + 2 * reps + 1 < steps.length &&
          igual(s, steps[i + 2 * reps]) &&
          igual(steps[i + 1], steps[i + 2 * reps + 1])) {
        reps++;
      }
      blocos.add(
        WorkoutBlock(
          kind: BlockKind.serie,
          seconds: s.seconds,
          from: s.from,
          cadenceMin: s.cadenceMin,
          cadenceMax: s.cadenceMax,
          cue: s.cue,
          reps: reps,
          restSeconds: steps[i + 1].seconds,
          restFraction: steps[i + 1].from,
        ),
      );
      i += 2 * reps;
      continue;
    }
    final ultimo = i == steps.length - 1;
    final kind = s.free
        ? BlockKind.livre
        : s.isRamp && i == 0 && s.to > s.from
        ? BlockKind.aquecer
        : s.isRamp && ultimo && s.to < s.from
        ? BlockKind.soltar
        : s.isRamp
        ? BlockKind.rampa
        : s.grade != 0
        ? BlockKind.subida
        : BlockKind.ritmo;
    blocos.add(
      WorkoutBlock(
        kind: kind,
        seconds: s.seconds,
        from: s.from,
        to: s.to,
        cadenceMin: s.cadenceMin,
        cadenceMax: s.cadenceMax,
        grade: s.grade,
        cue: s.cue,
      ),
    );
    i++;
  }
  return blocos;
}

/// Passo dos botões de tempo: 15 s até 2 min, 30 s até 10 min, 1 min acima.
int timeStep(int seconds) => seconds < 120 ? 15 : (seconds < 600 ? 30 : 60);

int moreTime(int seconds) => math.min(maxBlockSeconds, seconds + timeStep(seconds));

int lessTime(int seconds) => math.max(minBlockSeconds, seconds - timeStep(seconds - 1));

/// Fração arredondada a 1 % e dentro dos limites.
double clampFraction(double f) =>
    (f * 100).round().clamp((minFraction * 100).round(), (maxFraction * 100).round()) / 100;

int blocksSeconds(List<WorkoutBlock> blocks) => blocks.fold(0, (s, b) => s + b.totalSeconds);

/// O que impede salvar o treino (null = pode salvar).
String? workoutProblem(List<WorkoutBlock> blocks) {
  if (blocks.isEmpty) return 'Coloque pelo menos um bloco.';
  if (blocks.length > maxBlocks) return 'Um treino pode ter até $maxBlocks blocos.';
  if (blocksSeconds(blocks) > maxWorkoutSeconds) return 'O treino passou de 4 horas. Encurte algum bloco.';
  return null;
}

/// O nome digitado, sem espaços nas pontas e até [maxWorkoutName] letras; vazio vira “Meu treino”.
String workoutNameOrDefault(String digitado) {
  final nome = digitado.trim();
  if (nome.isEmpty) return 'Meu treino';
  return nome.length > maxWorkoutName ? nome.substring(0, maxWorkoutName).trimRight() : nome;
}

/// Onde entra um bloco novo: antes do último Soltar, ou no fim.
int insertIndex(List<WorkoutBlock> blocks) =>
    blocks.isNotEmpty && blocks.last.kind == BlockKind.soltar ? blocks.length - 1 : blocks.length;

/// Muda um bloco de lugar, como a lista arrastável entrega: [to] conta o bloco ainda na lista.
List<T> moveBlock<T>(List<T> blocks, int from, int to) {
  final lista = List.of(blocks);
  final item = lista.removeAt(from);
  lista.insert(to > from ? to - 1 : to, item);
  return lista;
}

/// Título do cartão do bloco.
String blockHeading(WorkoutBlock b) =>
    b.kind == BlockKind.serie ? '${blockTitles[b.kind]} · ${b.reps} ×' : blockTitles[b.kind]!;

String _tempoCurto(int s) {
  if (s < 60) return '$s s';
  final resto = s % 60;
  return resto == 0 ? '${s ~/ 60} min' : '${s ~/ 60} min $resto s';
}

String _palavra(double f) => zoneFor(f).effort;

String _giro(WorkoutBlock b) => b.cadenceMin == null ? '' : ', giro ${b.cadenceMin}–${b.cadenceMax}';

/// Resumo do bloco em palavras, com os watts do FTP (cartão do editor).
String describeBlock(WorkoutBlock b, int Function(double fraction) watts) {
  switch (b.kind) {
    case BlockKind.livre:
      return 'Sem meta, no seu ritmo';
    case BlockKind.serie:
      return '${_tempoCurto(b.seconds)} ${_palavra(b.from).toLowerCase()} (${watts(b.from)} W) + '
          '${_tempoCurto(b.restSeconds)} ${_palavra(b.restFraction).toLowerCase()}${_giro(b)}';
    case BlockKind.subida:
      return '${_palavra(b.from)} (${watts(b.from)} W), ${(b.grade * 100).round()} %${_giro(b)}';
    case BlockKind.aquecer || BlockKind.rampa || BlockKind.soltar when b.from != b.to:
      final sentido = b.to > b.from ? 'subindo' : 'descendo';
      return '${_palavra(b.from)} $sentido para ${_palavra(b.to).toLowerCase()} '
          '(${watts(b.from)} → ${watts(b.to)} W)${_giro(b)}';
    default:
      return '${_palavra(b.from)} (${watts(b.from)} W)${_giro(b)}';
  }
}
