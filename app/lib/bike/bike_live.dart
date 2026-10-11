import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bike_controller.dart';
import 'bike_reading.dart';
import 'bike_source.dart';

/// Se os dados da bike estão chegando: o que a tela de conectar e o selo “ao vivo” mostram.
enum BikeLive {
  /// Nenhuma bike escolhida, ou desconectada.
  semBike,

  /// Conectando, ou reconectando depois de uma queda.
  conectando,

  /// Conectada, mas nada chegou ainda (ou parou de chegar).
  esperando,

  /// Os pacotes chegam, mas tudo zerado: falta pedalar (ou a bike ainda não começou).
  parada,

  /// Giro ou potência chegando agora.
  aoVivo,
}

/// Sem pacote há mais que isso: a bike parou de mandar.
const _semPacote = Duration(seconds: 5);

/// Giro ou potência há menos que isso: ao vivo.
const _pedalRecente = Duration(seconds: 3);

BikeLive bikeLiveStatus({
  required BikeConnection connection,
  required bool hasSource,
  required DateTime now,
  DateTime? lastPacket,
  DateTime? lastPedaling,
}) {
  if (!hasSource || connection == BikeConnection.desconectada) {
    return BikeLive.semBike;
  }
  if (connection != BikeConnection.conectada) return BikeLive.conectando;
  if (lastPacket == null || now.difference(lastPacket) > _semPacote) {
    return BikeLive.esperando;
  }
  final pedalou = lastPedaling != null;
  if (pedalou && now.difference(lastPedaling) <= _pedalRecente) {
    return BikeLive.aoVivo;
  }
  return BikeLive.parada;
}

class BikeLiveState {
  const BikeLiveState({
    this.status = BikeLive.semBike,
    this.last,
    this.waiting = Duration.zero,
  });

  final BikeLive status;

  /// A última leitura (para mostrar os números ao vivo).
  final BikeReading? last;

  /// Há quanto tempo está conectada sem nada chegando (para explicar o que fazer).
  final Duration waiting;

  // Igual = não redesenha a tela (o relógio recalcula a cada segundo).
  @override
  bool operator ==(Object other) =>
      other is BikeLiveState &&
      other.status == status &&
      identical(other.last, last) &&
      other.waiting.inSeconds == waiting.inSeconds;

  @override
  int get hashCode => Object.hash(status, last, waiting.inSeconds);
}

/// Acompanha as leituras da bike de agora e diz, a cada segundo, se os dados estão chegando.
class BikeLiveController extends Notifier<BikeLiveState> {
  DateTime? _pacote;
  DateTime? _pedalando;
  DateTime? _esperandoDesde;
  BikeReading? _ultima;

  @override
  BikeLiveState build() {
    final (source, _) = ref.watch(
      bikeControllerProvider.select((s) => (s.source, s.connection)),
    );
    _pacote = null;
    _pedalando = null;
    _ultima = null;
    _esperandoDesde = clock.now();
    final sub = source?.readings.listen((r) {
      final agora = clock.now();
      _pacote = agora;
      _ultima = r;
      if ((r.cadence ?? 0) > 0 || (r.power ?? 0) > 0) _pedalando = agora;
      state = _calcular();
    });
    final relogio = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = _calcular(),
    );
    ref.onDispose(() {
      sub?.cancel();
      relogio.cancel();
    });
    return _calcular();
  }

  @override
  bool updateShouldNotify(BikeLiveState previous, BikeLiveState next) =>
      previous != next;

  BikeLiveState _calcular() {
    final bike = ref.read(bikeControllerProvider);
    final agora = clock.now();
    final status = bikeLiveStatus(
      connection: bike.connection,
      hasSource: bike.source != null,
      now: agora,
      lastPacket: _pacote,
      lastPedaling: _pedalando,
    );
    final desde = _pacote ?? _esperandoDesde;
    return BikeLiveState(
      status: status,
      last: _ultima,
      waiting: status == BikeLive.esperando && desde != null
          ? agora.difference(desde)
          : Duration.zero,
    );
  }
}

final bikeLiveProvider = NotifierProvider<BikeLiveController, BikeLiveState>(
  BikeLiveController.new,
);
