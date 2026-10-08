import 'laps.dart';
import 'ride_session.dart';

/// Um pedal anterior refeito no tempo: quando ele passou por cada distância.
///
/// Na ida, é o pedal como foi gravado e, ao chegar no fim, o fantasma espera lá.
/// Na volta fechada, é uma volta só, repetida a cada volta.
class Ghost {
  Ghost._(this._d, this._t, {required this.repeats});

  /// O pedal inteiro, como foi gravado.
  factory Ghost.ride(List<RideSample> samples) {
    final d = <double>[0];
    final t = <double>[0];
    for (final s in samples) {
      if (s.distance < d.last || s.t < t.last) continue;
      d.add(s.distance);
      t.add(s.t);
    }
    return Ghost._(d, t, repeats: false);
  }

  /// A volta [lap] do pedal [samples], que se repete a cada volta.
  /// [lapLength] é o comprimento da volta de hoje: a volta gravada é esticada para ele.
  factory Ghost.lap(List<RideSample> samples, LapSlice lap, {double? lapLength}) {
    final t0 = timeAtDistance(samples, lap.start);
    final fim = lap.start + lap.length;
    final escala = (lapLength ?? lap.length) / lap.length;
    final d = <double>[0];
    final t = <double>[0];
    for (final s in lap.samples) {
      if (s.distance >= fim - 1e-9) break;
      final dd = (s.distance - lap.start) * escala;
      final tt = s.t - t0;
      if (dd < d.last || tt < t.last) continue;
      d.add(dd);
      t.add(tt);
    }
    d.add(lap.length * escala);
    t.add(timeAtDistance(samples, fim) - t0);
    return Ghost._(d, t, repeats: true);
  }

  final List<double> _d;
  final List<double> _t;

  /// Repete a cada [length] metros (volta fechada).
  final bool repeats;

  /// Distância gravada (a ida inteira ou uma volta).
  double get length => _d.last;

  /// Tempo gravado (da ida inteira ou de uma volta).
  double get time => _t.last;

  /// Tempo em movimento em que o fantasma passou pela distância [d].
  double timeAt(double d) {
    if (d <= 0 || length <= 0) return 0;
    if (repeats) {
      final voltas = (d / length + 1e-9).floor();
      return voltas * time + _interp(_d, _t, d - voltas * length);
    }
    return d >= length ? time : _interp(_d, _t, d);
  }

  /// Onde o fantasma está no tempo em movimento [t].
  double distanceAt(double t) {
    if (t <= 0 || time <= 0) return 0;
    if (repeats) {
      final voltas = (t / time + 1e-9).floor();
      return voltas * length + _interp(_t, _d, t - voltas * time);
    }
    return t >= time ? length : _interp(_t, _d, t);
  }

  /// Segundos de vantagem de quem passou por [d] no tempo [t] (negativo = atrás do fantasma).
  double gapSeconds(double d, double t) => timeAt(d) - t;

  /// Metros que o fantasma está à frente no tempo [t] (negativo = ele está atrás).
  double gapMeters(double d, double t) => distanceAt(t) - d;

  /// Interpola [ys] em [x] numa lista [xs] que não diminui (o primeiro ponto que alcança [x]).
  static double _interp(List<double> xs, List<double> ys, double x) {
    var lo = 0;
    var hi = xs.length - 1;
    if (x >= xs[hi]) return ys[hi];
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (xs[mid] < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo == 0) return ys[0];
    final x0 = xs[lo - 1];
    final x1 = xs[lo];
    final f = x1 > x0 ? (x - x0) / (x1 - x0) : 1.0;
    return ys[lo - 1] + (ys[lo] - ys[lo - 1]) * f;
  }
}
