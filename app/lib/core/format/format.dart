import 'dart:math' as math;

import 'package:intl/intl.dart';

final _formatters = <int, NumberFormat>{};

NumberFormat _formatter(int casas) => _formatters.putIfAbsent(
      casas,
      () => NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: casas),
    );

String formatNumber(double n, [int casas = 0]) {
  final valor = n.abs() < 0.5 / math.pow(10, casas) ? 0 : n;
  return _formatter(casas).format(valor);
}

String formatKm(double metros, [int casas = 2]) => '${formatNumber(metros / 1000, casas)} km';

String formatTime(double segundos) {
  final s = segundos.floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final r = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$r' : '$m:$r';
}

String _dois(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}';

String formatDateTime(DateTime d) => '${formatDate(d)} às ${_dois(d.hour)}:${_dois(d.minute)}';
