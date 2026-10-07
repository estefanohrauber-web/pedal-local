import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'bike_source.dart';
import 'ftms_source.dart';
import 'sim_source.dart';

class BikeState {
  const BikeState({this.source, this.connection = BikeConnection.desconectada, this.message, this.diagnostic});

  final BikeSource? source;
  final BikeConnection connection;
  final String? message;
  final String? diagnostic;

  bool get connected => connection == BikeConnection.conectada;

  BikeState copyWith({BikeConnection? connection, String? message, bool clearMessage = false}) => BikeState(
        source: source,
        connection: connection ?? this.connection,
        message: clearMessage ? null : (message ?? this.message),
        diagnostic: clearMessage ? null : diagnostic,
      );
}

typedef FtmsFactory = BikeSource Function(String deviceId, String deviceName);

final ftmsFactoryProvider = Provider<FtmsFactory>(
  (ref) => (id, name) => FtmsSource(deviceId: id, deviceName: name),
);

final reconnectDelaysProvider = Provider<List<Duration>>(
  (ref) => const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 10)],
);

class BikeController extends Notifier<BikeState> {
  StreamSubscription<BikeConnection>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _reconnecting = false;

  @override
  BikeState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _retry?.cancel();
    });
    return const BikeState();
  }

  Future<void> useSimulated() => useSource(SimSource());

  Future<void> useDevice(String deviceId, String deviceName) async {
    await useSource(ref.read(ftmsFactoryProvider)(deviceId, deviceName));
    if (!ref.mounted || !state.connected) return;
    final store = ref.read(settingsStoreProvider);
    final s = await store.load();
    await store.save(s.copyWith(ultimaBikeId: deviceId, ultimaBikeNome: deviceName));
  }

  /// Ao abrir o app: tenta a última bike usada, se houver.
  Future<void> reconnectLast() async {
    final s = await ref.read(settingsStoreProvider).load();
    final id = s.ultimaBikeId;
    if (!ref.mounted || id == null || state.connected) return;
    await useDevice(id, s.ultimaBikeNome ?? 'Bike');
  }

  Future<void> useSource(BikeSource source) async {
    _retry?.cancel();
    _attempt = 0;
    await _sub?.cancel();
    _sub = null;
    final old = state.source;
    if (old != null && !identical(old, source)) await old.dispose();
    if (!ref.mounted) return;
    state = BikeState(source: source, connection: BikeConnection.conectando);
    _sub = source.connection.listen(_onConnection);
    try {
      await source.connect();
      if (!ref.mounted) return;
      state = BikeState(source: source, connection: source.state);
    } on NoFtmsException catch (e) {
      await _drop(source);
      if (!ref.mounted) return;
      state = BikeState(
        message: 'A bike conectou, mas não usa o padrão FTMS. Me mande o texto abaixo.',
        diagnostic: e.diagnostic,
      );
    } catch (e) {
      await _drop(source);
      if (!ref.mounted) return;
      state = BikeState(message: 'Não foi possível conectar: $e');
    }
  }

  Future<void> _drop(BikeSource source) async {
    await _sub?.cancel();
    _sub = null;
    await source.dispose();
  }

  void _onConnection(BikeConnection c) {
    if (!ref.mounted || state.source == null) return;
    state = state.copyWith(connection: c, clearMessage: c == BikeConnection.conectada);
    if (c == BikeConnection.conectada) _attempt = 0;
    if (c == BikeConnection.caiu && !_reconnecting && !(_retry?.isActive ?? false)) _scheduleRetry();
  }

  void _scheduleRetry() {
    final delays = ref.read(reconnectDelaysProvider);
    if (_attempt >= delays.length) {
      state = state.copyWith(connection: BikeConnection.caiu, message: 'A bike desconectou. Toque em Reconectar.');
      return;
    }
    final delay = delays[_attempt++];
    _retry = Timer(delay, () async {
      final source = state.source;
      if (source == null) return;
      _reconnecting = true;
      try {
        await source.connect();
      } catch (_) {
        if (ref.mounted) _scheduleRetry();
      } finally {
        _reconnecting = false;
      }
    });
  }

  Future<void> reconnectNow() async {
    _retry?.cancel();
    _attempt = 0;
    final source = state.source;
    if (source == null) return;
    try {
      await source.connect();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(message: 'Não reconectou: $e');
    }
  }

  Future<void> disconnect() async {
    _retry?.cancel();
    final source = state.source;
    if (source == null) return;
    await _sub?.cancel();
    _sub = null;
    await source.dispose();
    if (ref.mounted) state = const BikeState();
  }
}

final bikeControllerProvider = NotifierProvider<BikeController, BikeState>(BikeController.new);
