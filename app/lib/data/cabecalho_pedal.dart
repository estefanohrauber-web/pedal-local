import 'dart:math' as math;

import '../core/format/format.dart';
import '../domain/route_profile.dart';
import '../domain/route_variant.dart';
import 'rides_store.dart';

/// O topo da tela do pedal: o título (“Rota concluída!”…), as linhas de detalhe (voltas, sentido,
/// quanto faltou…) e se o pedal chegou ao fim (o círculo verde com o “certo”). O painel da casa
/// mostra os mesmos textos.
({String titulo, List<String> detalhes, bool concluiu}) cabecalhoPedal(RideRecord ride, RouteProfile? perfil) {
  final rota = ride.mode == RideMode.rota;
  final treino = ride.mode == RideMode.treino;
  final concluiu = rota || treino ? ride.laps >= 1 : ride.completed;
  final titulo = !ride.completed
      ? 'Pedal salvo'
      : rota
          ? (ride.laps >= 1 ? 'Rota concluída!' : 'Pedal encerrado')
          : treino
              ? (ride.laps >= 1 ? 'Treino concluído!' : 'Treino encerrado')
              : 'Pedal concluído!';
  final detalhes = <String>[];
  if (rota && perfil != null) {
    if (ride.loop) {
      final extra = ride.distanceM - ride.laps * perfil.distance;
      final voltas = ride.laps == 1 ? '1 volta' : '${ride.laps} voltas';
      detalhes.add(extra > 1 ? '$voltas + ${formatKm(extra)}' : voltas);
      detalhes.add(isClockwise(ride.track!) ? 'sentido horário' : 'sentido anti-horário');
    } else {
      if (ride.reversed) detalhes.add('sentido invertido');
      if (ride.laps == 0) detalhes.add('faltaram ${formatKm(math.max(0, perfil.distance - ride.distanceM))}');
    }
  }
  if (ride.trimmedM > 0) detalhes.add('volta fechada: ${formatNumber(ride.trimmedM)} m a mais descartados');
  return (titulo: titulo, detalhes: detalhes, concluiu: concluiu);
}
