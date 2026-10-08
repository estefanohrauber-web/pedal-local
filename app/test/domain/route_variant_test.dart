import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:pedal_local/domain/route_variant.dart';

import '../support/geo_helpers.dart';

void main() {
  group('tipo da rota', () {
    test('ida: o fim fica longe do começo', () {
      expect(isLoop(northProfile(List.filled(10, 700))), isFalse);
    });

    test('volta: o fim volta ao começo', () {
      expect(isLoop(squareLoop(200)), isTrue);
    });

    test('sentido da volta: norte → leste → sul → oeste é horário', () {
      final volta = squareLoop(200);
      expect(isClockwise(volta), isTrue);
      expect(isClockwise(volta.reversed.toList()), isFalse);
    });
  });

  group('variante', () {
    test('sem mudança devolve os mesmos pontos', () {
      final pts = northProfile([700, 710, 720]);
      expect(routeVariant(pts), pts);
    });

    test('inverter a ida: começa no fim e a subida vira descida', () {
      final pts = northProfile([700, 710, 720]);
      final inv = routeVariant(pts, reversed: true);
      expect(inv.map((p) => p.alt), [720, 710, 700]);
      final perfil = RouteProfile(inv);
      expect(perfil.gain, 0);
      expect(perfil.loss, 20);
    });

    test('começo escolhido na volta: gira e fecha no novo começo', () {
      final volta = squareLoop(200); // 41 pontos, o último repete o primeiro
      final girada = routeVariant(volta, startIndex: 10);
      expect(girada.first.geo, volta[10].geo);
      expect(girada.last.geo, volta[10].geo);
      expect(girada.length, volta.length);
      expectNear(RouteProfile(girada).distance, RouteProfile(volta).distance, 0.5);
    });

    test('começo na volta + inverter: começa no mesmo ponto, no outro sentido', () {
      final volta = squareLoop(200);
      final v = routeVariant(volta, startIndex: 10, reversed: true);
      expect(v.first.geo, volta[10].geo);
      expect(v[1].geo, volta[9].geo);
      expect(isClockwise(v), isFalse);
    });

    test('começo só vale para volta fechada', () {
      final pts = northProfile([700, 710, 720, 730]);
      expect(routeVariant(pts, startIndex: 2), pts);
    });

    test('ponto mais perto para escolher o começo tocando no mapa', () {
      final volta = squareLoop(200);
      final alvo = GeoPoint(volta[15].lat + 0.00001, volta[15].lon);
      expect(nearestIndex(volta, alvo), 15);
    });
  });
}
