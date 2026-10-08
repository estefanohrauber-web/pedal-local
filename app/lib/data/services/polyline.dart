import '../../domain/geo.dart';

/// Lê o traçado no formato "encoded polyline" (o Valhalla usa 6 casas decimais).
List<GeoPoint> decodePolyline(String encoded, {int precision = 6}) {
  var fator = 1.0;
  for (var i = 0; i < precision; i++) {
    fator *= 10;
  }
  final out = <GeoPoint>[];
  var i = 0;
  var lat = 0;
  var lon = 0;

  int proximo() {
    var resultado = 0;
    var deslocamento = 0;
    int b;
    do {
      b = encoded.codeUnitAt(i++) - 63;
      resultado |= (b & 0x1f) << deslocamento;
      deslocamento += 5;
    } while (b >= 0x20);
    return (resultado & 1) != 0 ? ~(resultado >> 1) : resultado >> 1;
  }

  while (i < encoded.length) {
    lat += proximo();
    lon += proximo();
    out.add(GeoPoint(lat / fator, lon / fator));
  }
  return out;
}
