import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/waypoint_editor.dart';

const a = GeoPoint(-27.19, -51.49);
const b = GeoPoint(-27.18, -51.48);
const c = GeoPoint(-27.17, -51.49);
const d = GeoPoint(-27.16, -51.50);

void main() {
  test('adiciona e desfaz', () {
    final e = WaypointEditor()
      ..add(a)
      ..add(b);
    expect(e.points, [a, b]);
    expect(e.undo(), isTrue);
    expect(e.points, [a]);
    expect(e.undo(), isTrue);
    expect(e.undo(), isFalse);
    expect(e.canUndo, isFalse);
  });

  test('arrastar guarda um passo só no começo do arrasto', () {
    final e = WaypointEditor([a, b, c]);
    e.beginDrag();
    e.dragTo(1, d);
    e.dragTo(1, a);
    e.dragTo(1, d);
    expect(e.points, [a, d, c]);
    e.undo();
    expect(e.points, [a, b, c]);
  });

  test('apagar um ponto', () {
    final e = WaypointEditor([a, b, c])..remove(1);
    expect(e.points, [a, c]);
    e.undo();
    expect(e.points, [a, b, c]);
  });

  test('fechar a volta repete o começo no fim', () {
    final e = WaypointEditor([a, b, c]);
    expect(e.canClose, isTrue);
    e.close();
    expect(e.points, [a, b, c, a]);
    expect(e.isClosed, isTrue);
    expect(e.canClose, isFalse);
    expect(e.canOutAndBack, isFalse);
  });

  test('ida e volta: volta pelos mesmos pontos até o começo', () {
    final e = WaypointEditor([a, b, c]);
    expect(e.canOutAndBack, isTrue);
    e.outAndBack();
    expect(e.points, [a, b, c, b, a]);
  });

  test('na volta fechada, mexer no começo mexe no fim junto', () {
    final e = WaypointEditor([a, b, c, a]);
    e.beginDrag();
    e.dragTo(0, d);
    expect(e.points, [d, b, c, d]);
  });

  test('na volta fechada, apagar o começo fecha no novo começo', () {
    final e = WaypointEditor([a, b, c, a])..remove(0);
    expect(e.points, [b, c, b]);
  });

  test('pontos que aparecem no mapa: o fim repetido da volta não vira outro ponto', () {
    expect(WaypointEditor([a, b, c, a]).handles, [a, b, c]);
    expect(WaypointEditor([a, b, c]).handles, [a, b, c]);
  });
}
