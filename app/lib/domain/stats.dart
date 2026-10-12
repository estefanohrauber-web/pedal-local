/// O mínimo de um pedal para as contas da aba Você.
class RideStat {
  const RideStat({required this.startedAt, required this.distanceM, required this.movingTimeS, required this.gainM});

  final DateTime startedAt;
  final double distanceM;
  final double movingTimeS;
  final double gainM;
}

class Summary {
  const Summary({this.count = 0, this.distanceM = 0, this.movingTimeS = 0, this.gainM = 0});

  final int count;
  final double distanceM;
  final double movingTimeS;
  final double gainM;
}

/// Segunda-feira, meia-noite, da semana de [d] (fuso do celular).
DateTime weekStart(DateTime d) {
  final dia = DateTime(d.year, d.month, d.day);
  return dia.subtract(Duration(days: dia.weekday - DateTime.monday));
}

/// Soma os pedais a partir de [from] (todos, se null).
Summary summarize(Iterable<RideStat> rides, {DateTime? from}) {
  var count = 0;
  var dist = 0.0;
  var tempo = 0.0;
  var subida = 0.0;
  for (final r in rides) {
    if (from != null && r.startedAt.isBefore(from)) continue;
    count++;
    dist += r.distanceM;
    tempo += r.movingTimeS;
    subida += r.gainM;
  }
  return Summary(count: count, distanceM: dist, movingTimeS: tempo, gainM: subida);
}

class WeekGroup<T extends RideStat> {
  const WeekGroup(this.label, this.start, this.items);

  final String label;
  final DateTime start;
  final List<T> items;

  double get distanceM => items.fold(0, (s, r) => s + r.distanceM);
}

/// Agrupa por semana (mais nova primeiro): “Esta semana”, “Semana passada”, “Semana de dd/mm”.
List<WeekGroup<T>> groupByWeek<T extends RideStat>(List<T> rides, {required DateTime now}) {
  final atual = weekStart(now);
  final passada = atual.subtract(const Duration(days: 7));
  final grupos = <DateTime, List<T>>{};
  for (final r in rides) {
    grupos.putIfAbsent(weekStart(r.startedAt), () => []).add(r);
  }
  final semanas = grupos.keys.toList()..sort((a, b) => b.compareTo(a));
  String nome(DateTime s) {
    if (s == atual) return 'Esta semana';
    if (s == passada) return 'Semana passada';
    return 'Semana de ${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}';
  }

  return [
    for (final s in semanas) WeekGroup(nome(s), s, grupos[s]!..sort((a, b) => b.startedAt.compareTo(a.startedAt))),
  ];
}

/// Os melhores pedais e a semana com mais km.
class Recordes<T extends RideStat> {
  const Recordes({required this.maisLonge, required this.maisSubida, required this.maisTempo, required this.melhorSemana});

  final T maisLonge;
  final T maisSubida;
  final T maisTempo;
  final WeekGroup<T> melhorSemana;
}

/// Os recordes de [pedais] (null = nenhum pedal ainda).
Recordes<T>? recordes<T extends RideStat>(List<T> pedais, {required DateTime now}) {
  if (pedais.isEmpty) return null;
  T maior(double Function(T) valor) => pedais.reduce((a, b) => valor(b) > valor(a) ? b : a);
  return Recordes(
    maisLonge: maior((r) => r.distanceM),
    maisSubida: maior((r) => r.gainM),
    maisTempo: maior((r) => r.movingTimeS),
    melhorSemana: groupByWeek(pedais, now: now).reduce((a, b) => b.distanceM > a.distanceM ? b : a),
  );
}
