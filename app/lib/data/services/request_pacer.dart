import 'package:clock/clock.dart';

/// Põe os pedidos em fila com um intervalo mínimo entre eles.
/// Os servidores da FOSSGIS (Valhalla) aceitam no máximo 1 pedido por segundo.
class RequestPacer {
  RequestPacer({this.gap = const Duration(seconds: 1), DateTime Function()? now, Future<void> Function(Duration)? sleep})
      : _now = now ?? clock.now,
        _sleep = sleep ?? Future<void>.delayed;

  final Duration gap;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  DateTime? _proximo;

  /// Espera até ser a vez deste pedido.
  Future<void> wait() async {
    final agora = _now();
    final proximo = _proximo;
    final vez = proximo == null || proximo.isBefore(agora) ? agora : proximo;
    _proximo = vez.add(gap);
    final falta = vez.difference(agora);
    if (falta > Duration.zero) await _sleep(falta);
  }
}
