import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/core/format/format.dart';

void main() {
  test('formatNumber usa vírgula e ponto do pt-BR', () {
    expect(formatNumber(1234.5, 1), '1.234,5');
    expect(formatNumber(7.25), '7');
  });

  test('formatNumber não mostra "-0"', () {
    expect(formatNumber(-0.2), '0');
    expect(formatNumber(-0.04, 1), '0,0');
  });

  test('formatKm', () {
    expect(formatKm(1234), '1,23 km');
  });

  test('formatTime', () {
    expect(formatTime(0), '0:00');
    expect(formatTime(65.9), '1:05');
    expect(formatTime(3725), '1:02:05');
  });

  test('formatDateTime', () {
    expect(formatDateTime(DateTime(2026, 10, 7, 9, 5)), '07/10 às 09:05');
  });
}
