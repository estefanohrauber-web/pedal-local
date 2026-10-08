import 'package:pedal_local/domain/geo.dart';

/// Codifica pontos no formato "encoded polyline" (o inverso do que o app decodifica).
String encodePolyline(List<GeoPoint> pontos, {int precision = 6}) {
  var fator = 1;
  for (var i = 0; i < precision; i++) {
    fator *= 10;
  }
  final out = StringBuffer();
  var lat0 = 0;
  var lon0 = 0;
  void valor(int v) {
    var x = v < 0 ? ~(v << 1) : v << 1;
    while (x >= 0x20) {
      out.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    out.writeCharCode(x + 63);
  }

  for (final p in pontos) {
    final lat = (p.lat * fator).round();
    final lon = (p.lon * fator).round();
    valor(lat - lat0);
    valor(lon - lon0);
    lat0 = lat;
    lon0 = lon;
  }
  return out.toString();
}
