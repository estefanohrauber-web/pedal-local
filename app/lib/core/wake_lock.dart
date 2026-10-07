import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantém a tela acesa durante o pedal.
abstract interface class WakeLock {
  Future<void> enable();
  Future<void> disable();
}

class PlatformWakeLock implements WakeLock {
  const PlatformWakeLock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final wakeLockProvider = Provider<WakeLock>((ref) => const PlatformWakeLock());
