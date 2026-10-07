import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../domain/ftms_parser.dart';

class FoundDevice {
  const FoundDevice({required this.id, required this.name, required this.likelyBike, this.rssi});

  final String id;
  final String name;
  final bool likelyBike;
  final int? rssi;
}

/// Parece uma bike: anuncia o serviço FTMS ou tem nome de painel FitShow ("FS-").
bool isLikelyBike({String? name, List<String> services = const []}) =>
    services.any((s) => s.toLowerCase() == ftmsServiceUuid) || (name ?? '').toUpperCase().startsWith('FS-');

List<FoundDevice> sortFound(Iterable<FoundDevice> devices) => devices.toList()
  ..sort((a, b) {
    if (a.likelyBike != b.likelyBike) return a.likelyBike ? -1 : 1;
    return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
  });

enum BleProblem { semPermissao, desligado, semSuporte }

String bleProblemText(BleProblem p) => switch (p) {
      BleProblem.semPermissao =>
        'O app precisa da permissão de Bluetooth (Dispositivos próximos) para achar a bike. Libere nas configurações do celular.',
      BleProblem.desligado => 'O Bluetooth está desligado. Ligue e toque em "Procurar de novo".',
      BleProblem.semSuporte => 'Este aparelho não tem Bluetooth compatível.',
    };

class BikeScanner {
  /// Pede permissão e confere se o Bluetooth está ligado. `null` = tudo certo.
  Future<BleProblem?> check() async {
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {
      return BleProblem.semPermissao;
    }
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return switch (state) {
      AvailabilityState.poweredOff => BleProblem.desligado,
      AvailabilityState.unsupported => BleProblem.semSuporte,
      AvailabilityState.unauthorized => BleProblem.semPermissao,
      _ => null,
    };
  }

  /// Procura aparelhos por [duration]; cada evento traz a lista acumulada e ordenada.
  Stream<List<FoundDevice>> scan({Duration duration = const Duration(seconds: 12)}) {
    final found = <String, FoundDevice>{};
    StreamSubscription<BleDevice>? sub;
    Timer? timer;
    late final StreamController<List<FoundDevice>> controller;

    Future<void> stop() async {
      timer?.cancel();
      await sub?.cancel();
      try {
        await UniversalBle.stopScan();
      } catch (_) {
        // a busca já tinha parado
      }
      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<List<FoundDevice>>(
      onListen: () async {
        sub = UniversalBle.scanStream.listen((d) {
          final name = d.name ?? '';
          found[d.deviceId] = FoundDevice(
            id: d.deviceId,
            name: name.isEmpty ? 'Sem nome' : name,
            likelyBike: isLikelyBike(name: d.name, services: d.services),
            rssi: d.rssi,
          );
          if (!controller.isClosed) controller.add(sortFound(found.values));
        });
        timer = Timer(duration, stop);
        try {
          await UniversalBle.startScan();
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
          await stop();
        }
      },
      onCancel: stop,
    );
    return controller.stream;
  }
}

final bikeScannerProvider = Provider<BikeScanner>((ref) => BikeScanner());
