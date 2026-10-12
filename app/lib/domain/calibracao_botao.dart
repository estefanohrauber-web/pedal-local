/// O giro e os watts médios que a bike mandou numa volta da calibração guiada do botão.
class VoltaMedida {
  const VoltaMedida(this.volta, this.rpm, this.watts);

  /// Posição do botão (voltas a partir do mais leve).
  final int volta;
  final double rpm;
  final double watts;
}

/// O giro que a calibração pede para manter.
const metaRpm = 60;

/// Abaixo disso a pessoa não aguentou manter o giro: o botão ficou pesado demais.
const rpmMinimo = 50;

/// Até que volta a pessoa manteve o giro; null = sem dados da bike (ou não pedalou no começo).
int? limitePedalavel(List<VoltaMedida> medidas) {
  final ordem = [...medidas]..sort((a, b) => a.volta.compareTo(b.volta));
  if (ordem.isEmpty || ordem.first.rpm < rpmMinimo) return null;
  var limite = ordem.first.volta;
  for (final m in ordem) {
    if (m.rpm < rpmMinimo) break;
    limite = m.volta;
  }
  return limite;
}

/// Se os watts da bike sobem com o botão no mesmo giro (ela mede o freio): compara voltas
/// distantes (3 ou mais) com giros parecidos (até 3 rpm). null = nada parecido para comparar.
bool? bikeSenteOBotao(List<VoltaMedida> medidas) {
  var comparou = false;
  for (final leve in medidas) {
    for (final pesada in medidas) {
      if (pesada.volta - leve.volta < 3 ||
          (pesada.rpm - leve.rpm).abs() > 3 ||
          leve.rpm < 30 ||
          leve.watts <= 0) {
        continue;
      }
      comparou = true;
      if (pesada.watts > leve.watts * 1.15) return true;
    }
  }
  return comparou ? false : null;
}
