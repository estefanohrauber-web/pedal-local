import 'dart:math' as math;

import 'geo.dart';

/// Trecho de ponte ou túnel, em metros desde o começo do caminho.
class StructureSpan {
  const StructureSpan(this.start, this.end);

  final double start;
  final double end;

  @override
  String toString() => 'StructureSpan($start, $end)';
}

/// Ponte ou túnel no caminho casado pelo Valhalla: índices do começo e do fim no traçado dele.
typedef ShapeRange = ({int begin, int end});

/// Quanto procurar, para cada lado da distância esperada, a ponta de uma ponte na rota.
const _janelaM = 150.0;

/// Leva as pontes e os túneis do caminho casado ([shape], trechos em [ranges]) para metros ao
/// longo de [line]. Cada ponta vai para o lugar mais perto de [line], procurando perto da
/// distância esperada: os dois caminhos têm quase o mesmo comprimento, e uma rota pode passar
/// duas vezes pela mesma ponte (ida e volta).
List<StructureSpan> structureSpans(
  List<GeoPoint> line,
  List<GeoPoint> shape,
  List<ShapeRange> ranges,
) {
  if (line.length < 2 || shape.length < 2) return const [];
  final cum = cumulativeDistances(line);
  final cumShape = cumulativeDistances(shape);
  final escala = cumShape.last > 0 ? cum.last / cumShape.last : 1.0;
  double naRota(int i) => _projetar(line, cum, shape[i], cumShape[i] * escala);
  return [
    for (final r in ranges)
      if (r.begin >= 0 && r.end < shape.length && r.begin < r.end)
        StructureSpan(naRota(r.begin), naRota(r.end)),
  ];
}

/// Distância ao longo de [line] do lugar mais perto de [p], entre os trechos perto de [aprox].
double _projetar(
  List<GeoPoint> line,
  List<double> cum,
  GeoPoint p,
  double aprox,
) {
  var melhor = double.infinity;
  var onde = aprox.clamp(0.0, cum.last).toDouble();
  final mPorGrauLon = _mPorGrauLat * math.cos(p.lat * math.pi / 180);
  for (var i = 0; i < line.length - 1; i++) {
    if (cum[i + 1] < aprox - _janelaM || cum[i] > aprox + _janelaM) continue;
    final a = line[i];
    final b = line[i + 1];
    // Plano local em metros, com origem em a.
    final bx = (b.lon - a.lon) * mPorGrauLon;
    final by = (b.lat - a.lat) * _mPorGrauLat;
    final px = (p.lon - a.lon) * mPorGrauLon;
    final py = (p.lat - a.lat) * _mPorGrauLat;
    final l2 = bx * bx + by * by;
    final t = l2 == 0
        ? 0.0
        : ((px * bx + py * by) / l2).clamp(0.0, 1.0).toDouble();
    final d = math.sqrt(math.pow(px - t * bx, 2) + math.pow(py - t * by, 2));
    if (d < melhor) {
      melhor = d;
      onde = cum[i] + t * (cum[i + 1] - cum[i]);
    }
  }
  return onde;
}

const _mPorGrauLat = 6371000 * math.pi / 180;

/// Altitude nas pontes e nos túneis. O relevo vem do terreno: embaixo da ponte está o rio, em
/// cima do túnel, o morro. Cada trecho vira uma reta entre as cabeceiras, [margin] metros para
/// fora das pontas. Pontes mais próximas que 4·[margin] viram uma reta só (assim a cabeceira de
/// uma não cai no vale embaixo da outra).
List<double> flattenStructures(
  List<double> cum,
  List<double> alts,
  List<StructureSpan> spans, {
  double margin = 10,
}) {
  final out = List.of(alts);
  if (spans.isEmpty || cum.length < 2) return out;
  final ordem = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final juntos = <StructureSpan>[];
  for (final s in ordem) {
    final ultimo = juntos.isEmpty ? null : juntos.last;
    if (ultimo != null && s.start - ultimo.end <= 4 * margin) {
      juntos[juntos.length - 1] = StructureSpan(
        ultimo.start,
        math.max(ultimo.end, s.end),
      );
    } else {
      juntos.add(s);
    }
  }
  for (final s in juntos) {
    var a = 0;
    for (var i = 0; i < cum.length && cum[i] <= s.start - margin; i++) {
      a = i;
    }
    var b = cum.length - 1;
    for (var i = cum.length - 1; i >= 0 && cum[i] >= s.end + margin; i--) {
      b = i;
    }
    if (b - a < 2) continue;
    for (var i = a + 1; i < b; i++) {
      out[i] =
          out[a] + (alts[b] - out[a]) * (cum[i] - cum[a]) / (cum[b] - cum[a]);
    }
  }
  return out;
}
