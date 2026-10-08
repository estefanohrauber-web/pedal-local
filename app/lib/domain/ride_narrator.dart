import 'ride_session.dart';

/// “4 minutos e 12 segundos”, do jeito que se fala.
String spokenTime(double segundos) {
  final s = segundos.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final r = s % 60;
  String parte(int n, String um, String varios) => '$n ${n == 1 ? um : varios}';
  if (h > 0) return m > 0 ? '${parte(h, 'hora', 'horas')} e ${parte(m, 'minuto', 'minutos')}' : parte(h, 'hora', 'horas');
  if (m > 0) return r > 0 ? '${parte(m, 'minuto', 'minutos')} e ${parte(r, 'segundo', 'segundos')}' : parte(m, 'minuto', 'minutos');
  return parte(r, 'segundo', 'segundos');
}

/// Como você está contra o fantasma: [gapS] segundos à frente (negativo = atrás).
String spokenGhost(double gapS) {
  if (gapS.abs() < 1) return 'Lado a lado com o fantasma.';
  return 'Você está ${spokenTime(gapS.abs())} ${gapS > 0 ? 'à frente do' : 'atrás do'} fantasma.';
}

/// Distância mínima à frente ou atrás para dizer que alguém passou (evita falar sem parar
/// quando você e o fantasma vão juntos).
const ghostPassM = 15.0;

/// O que falar durante o pedal. A cada passo recebe o que aconteceu e devolve as frases.
class RideNarrator {
  RideNarrator({this.routeLength});

  /// Comprimento da ida (null = pedal livre ou volta fechada, que não acabam sozinhos).
  final double? routeLength;

  int _kmFalados = 0;
  bool _metade = false;
  bool _quaseFim = false;
  bool? _naFrente;

  static const bikeDropped = 'A bike desconectou. Pedal pausado.';

  List<String> update({
    required double distance,
    required double movingTime,
    RideAlert? alert,
    int? lapDone,
    double? lapTime,
    double? ghostGapS,
    double? ghostGapM,
  }) {
    final frases = <String>[];
    final fantasma = ghostGapS == null ? '' : ' ${spokenGhost(ghostGapS)}';

    if (alert != null) {
      frases.add(alert.kind == AlertKind.subida
          ? 'Subida de ${(alert.grade * 100).round()} por cento chegando. Aumente a carga.'
          : 'Descida chegando. Pode aliviar a carga.');
    }

    final km = (distance / 1000 + 1e-9).floor();
    if (lapDone != null) {
      frases.add('Volta $lapDone concluída em ${spokenTime(lapTime ?? 0)}.$fantasma');
      _kmFalados = km; // não repete o km junto com a volta
    } else if (km > _kmFalados) {
      _kmFalados = km;
      frases.add('${km == 1 ? '1 quilômetro' : '$km quilômetros'}, em ${spokenTime(movingTime)}.$fantasma');
    }

    final total = routeLength;
    if (total != null && total >= 2000 && !_metade && distance >= total / 2) {
      _metade = true;
      frases.add('Metade da rota.');
    }
    if (total != null && total >= 1000 && !_quaseFim && total - distance <= 200) {
      _quaseFim = true;
      frases.add('Faltam 200 metros!');
    }

    if (ghostGapM != null) {
      final naFrente = ghostGapM < -ghostPassM
          ? true
          : ghostGapM > ghostPassM
              ? false
              : _naFrente;
      if (naFrente != null && naFrente != _naFrente) {
        frases.add(naFrente ? 'Você passou o fantasma!' : 'O fantasma passou você.');
      }
      _naFrente = naFrente;
    }
    return frases;
  }

  /// Frase do fim: [completed] = chegou ao fim da ida; [laps] = voltas completas na volta fechada.
  String finished({required bool completed, required int laps, required double movingTime, double? ghostGapS}) {
    final inicio = completed
        ? 'Rota concluída em ${spokenTime(movingTime)}!'
        : laps > 0
            ? 'Pedal encerrado: ${laps == 1 ? '1 volta' : '$laps voltas'} em ${spokenTime(movingTime)}.'
            : 'Pedal encerrado: ${spokenTime(movingTime)}.';
    if (ghostGapS == null) return inicio;
    final fantasma = ghostGapS.abs() < 1
        ? 'Empate com o fantasma!'
        : ghostGapS > 0
            ? 'Você venceu o fantasma por ${spokenTime(ghostGapS)}!'
            : 'O fantasma ganhou por ${spokenTime(-ghostGapS)}.';
    return '$inicio $fantasma';
  }
}
