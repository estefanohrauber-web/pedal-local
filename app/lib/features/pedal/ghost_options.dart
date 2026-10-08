import '../../data/rides_store.dart';
import '../../domain/ghost.dart';
import '../../domain/laps.dart';
import '../../domain/route_profile.dart';

/// Contra quem correr: o recorde ou o pedal mais recente (na volta fechada, uma volta só).
enum GhostKind { recorde, ultimo }

class GhostOption {
  const GhostOption({required this.kind, required this.ghost, required this.time, required this.when, required this.loop});

  final GhostKind kind;
  final Ghost ghost;

  /// Tempo do fantasma: da ida inteira ou de uma volta.
  final double time;
  final DateTime when;
  final bool loop;

  String get label => switch ((kind, loop)) {
        (GhostKind.recorde, false) => 'Seu recorde',
        (GhostKind.ultimo, false) => 'Último pedal',
        (GhostKind.recorde, true) => 'Sua melhor volta',
        (GhostKind.ultimo, true) => 'Sua última volta',
      };
}

class _Volta {
  _Volta(this.ride, this.slice, this.time);

  final RideRecord ride;
  final LapSlice slice;
  final double time;
}

/// Fantasmas possíveis nesta rota e sentido, a partir dos pedais anteriores (com amostras).
/// [lapLength] é o comprimento da volta de hoje (só na volta fechada).
/// Quando o recorde e o último são o mesmo pedal, só o recorde aparece.
List<GhostOption> ghostOptions(List<RideRecord> rides, {required bool reversed, double? lapLength}) {
  final validos = [
    for (final r in rides)
      if (r.reversed == reversed && r.laps >= 1 && r.samples.isNotEmpty) r,
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (validos.isEmpty) return const [];

  if (lapLength == null) {
    final ultimo = validos.first;
    final recorde = validos.reduce((a, b) => b.movingTimeS < a.movingTimeS ? b : a);
    GhostOption opcao(GhostKind k, RideRecord r) =>
        GhostOption(kind: k, ghost: Ghost.ride(r.samples), time: r.movingTimeS, when: r.startedAt, loop: false);
    return [
      opcao(GhostKind.recorde, recorde),
      if (ultimo.id != recorde.id) opcao(GhostKind.ultimo, ultimo),
    ];
  }

  final voltas = <_Volta>[];
  for (final r in validos) {
    final track = r.track;
    final comprimento = track != null && track.length >= 2 ? RouteProfile(track).distance : lapLength;
    for (final s in lapSlices(r.samples, comprimento)) {
      if (!s.complete) continue;
      final t = timeAtDistance(r.samples, s.start + s.length) - timeAtDistance(r.samples, s.start);
      voltas.add(_Volta(r, s, t));
    }
  }
  if (voltas.isEmpty) return const [];
  // As voltas estão do pedal mais novo para o mais antigo; dentro do pedal, em ordem.
  final maisNovo = voltas.first.ride.id;
  final ultima = voltas.lastWhere((v) => v.ride.id == maisNovo);
  final melhor = voltas.reduce((a, b) => b.time < a.time ? b : a);
  GhostOption opcao(GhostKind k, _Volta v) => GhostOption(
        kind: k,
        ghost: Ghost.lap(v.ride.samples, v.slice, lapLength: lapLength),
        time: v.time,
        when: v.ride.startedAt,
        loop: true,
      );
  return [
    opcao(GhostKind.recorde, melhor),
    if (!identical(ultima, melhor)) opcao(GhostKind.ultimo, ultima),
  ];
}
