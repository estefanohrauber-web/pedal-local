import 'geo.dart';

/// Pontos marcados no mapa ao criar uma rota, com desfazer.
/// Na volta fechada o último ponto repete o primeiro.
class WaypointEditor {
  WaypointEditor([List<GeoPoint> inicial = const []]) : _pontos = List.of(inicial);

  final List<GeoPoint> _pontos;
  final List<List<GeoPoint>> _historico = [];

  List<GeoPoint> get points => List.unmodifiable(_pontos);

  /// Pontos para mostrar e arrastar no mapa (sem o fim repetido da volta).
  List<GeoPoint> get handles => isClosed ? _pontos.sublist(0, _pontos.length - 1) : points;

  bool get canUndo => _historico.isNotEmpty;
  bool get isClosed => _pontos.length >= 3 && _pontos.first == _pontos.last;
  bool get canClose => _pontos.length >= 2 && !isClosed;
  bool get canOutAndBack => _pontos.length >= 2 && !isClosed;

  void _guarda() => _historico.add(List.of(_pontos));

  void add(GeoPoint p) {
    _guarda();
    _pontos.add(p);
  }

  /// Chamar uma vez no começo do arrasto: o desfazer volta para antes dele.
  void beginDrag() => _guarda();

  void dragTo(int i, GeoPoint p) {
    final fechada = isClosed;
    _pontos[i] = p;
    if (fechada && i == 0) _pontos[_pontos.length - 1] = p;
    if (fechada && i == _pontos.length - 1) _pontos[0] = p;
  }

  void remove(int i) {
    _guarda();
    if (isClosed && (i == 0 || i == _pontos.length - 1)) {
      _pontos
        ..removeLast()
        ..removeAt(0);
      if (_pontos.length >= 2) _pontos.add(_pontos.first);
      return;
    }
    _pontos.removeAt(i);
  }

  void close() {
    if (!canClose) return;
    _guarda();
    _pontos.add(_pontos.first);
  }

  /// Volta pelos mesmos pontos até o começo (o caminho de volta é traçado de novo).
  void outAndBack() {
    if (!canOutAndBack) return;
    _guarda();
    _pontos.addAll(_pontos.reversed.skip(1).toList());
  }

  /// Troca todos os pontos de uma vez (por uma volta gerada, por exemplo).
  void replaceAll(List<GeoPoint> pontos) {
    _guarda();
    _pontos
      ..clear()
      ..addAll(pontos);
  }

  bool undo() {
    if (_historico.isEmpty) return false;
    _pontos
      ..clear()
      ..addAll(_historico.removeLast());
    return true;
  }
}
