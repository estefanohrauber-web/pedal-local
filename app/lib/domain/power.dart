/// Potência usada na simulação: a da bike, ou estimada pela cadência e pela carga.
enum PowerMode { auto, bike, estimada }

class PowerCalibration {
  const PowerCalibration({this.base = 0.6, this.factor = 0.25});
  final double base;
  final double factor;
}

const fallbackAfter = Duration(seconds: 10);

int estimatePower(double? cadence, int level, [PowerCalibration calibration = const PowerCalibration()]) {
  if (cadence == null || cadence <= 0) return 0;
  return (cadence * (calibration.base + calibration.factor * level)).round();
}

class PowerResolver {
  PowerResolver({this.mode = PowerMode.auto, this.calibration = const PowerCalibration()})
      : _effective = mode == PowerMode.estimada ? PowerMode.estimada : PowerMode.bike;

  final PowerMode mode;
  final PowerCalibration calibration;
  PowerMode _effective;
  DateTime? _missingSince;
  bool _switched = false;

  PowerMode get effectiveMode => _effective;
  bool get switchedToEstimate => _switched;

  int resolve({
    required double? cadence,
    required int? power,
    required DateTime timestamp,
    required int level,
  }) {
    if (cadence == null || cadence <= 0) {
      _missingSince = null;
      return 0;
    }
    final hasPower = power != null && power > 0;
    if (mode == PowerMode.auto && _effective == PowerMode.bike) {
      if (hasPower) {
        _missingSince = null;
      } else if (_missingSince == null) {
        _missingSince = timestamp;
      } else if (timestamp.difference(_missingSince!) >= fallbackAfter) {
        _effective = PowerMode.estimada;
        _switched = true;
      }
    }
    if (_effective == PowerMode.estimada) return estimatePower(cadence, level, calibration);
    if (hasPower) return power;
    return mode == PowerMode.auto ? estimatePower(cadence, level, calibration) : 0;
  }
}
