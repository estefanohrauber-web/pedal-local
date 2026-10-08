import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/services/polyline.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/geo_helpers.dart';
import '../support/polyline_encode.dart';

void main() {
  test('exemplo oficial com 5 casas', () {
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
    expect(pts, const [GeoPoint(38.5, -120.2), GeoPoint(40.7, -120.95), GeoPoint(43.252, -126.453)]);
  });

  test('ida e volta com 6 casas (formato do Valhalla)', () {
    const pts = [GeoPoint(-27.190612, -51.491734), GeoPoint(-27.274211, -51.442518), GeoPoint(-23.5505, -46.6333)];
    final volta = decodePolyline(encodePolyline(pts));
    expect(volta.length, 3);
    for (var i = 0; i < 3; i++) {
      expectNear(volta[i].lat, pts[i].lat, 1e-9);
      expectNear(volta[i].lon, pts[i].lon, 1e-9);
    }
  });

  test('texto vazio não tem pontos', () {
    expect(decodePolyline(''), isEmpty);
  });
}
