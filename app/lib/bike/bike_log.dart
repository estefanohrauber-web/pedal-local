import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Diário da conexão com a bike: o que aconteceu (conectou, caiu e por quê) e cada pacote cru
/// que ela mandou. Serve para entender uma bike de verdade sem estar junto dela. Guarda as
/// últimas [maxLines] linhas num arquivo do app, que continua de uma abertura para outra.
class BikeLog {
  BikeLog({
    Future<File?> Function()? file,
    this.maxLines = 4000,
    this.flushAfter = const Duration(seconds: 5),
  }) : _arquivo = file;

  final int maxLines;
  final Duration flushAfter;
  final Future<File?> Function()? _arquivo;
  final _linhas = <String>[];
  Timer? _timer;
  bool _leuAnterior = false;

  List<String> get lines => List.unmodifiable(_linhas);

  void add(String texto) {
    _linhas.add('${_quando(clock.now())} $texto');
    _cortar();
    if (_arquivo != null) _timer ??= Timer(flushAfter, flush);
  }

  /// Pacote cru, em hexadecimal.
  void packet(Uint8List bytes) => add(
    'dados ${[for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join(' ')}',
  );

  /// Os últimos [n] pacotes crus (o mais novo por último).
  List<String> recentPackets(int n) {
    final pacotes = _linhas.where((l) => l.contains(' dados ')).toList();
    return pacotes.sublist(pacotes.length > n ? pacotes.length - n : 0);
  }

  /// Grava no arquivo. Na primeira vez, junta o que já estava lá (de outras aberturas do app).
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    try {
      final arquivo = await _arquivo?.call();
      if (arquivo == null) return;
      if (!_leuAnterior) {
        _leuAnterior = true;
        if (await arquivo.exists()) {
          _linhas.insertAll(0, await arquivo.readAsLines());
          _cortar();
        }
      }
      await arquivo.writeAsString('${_linhas.join('\n')}\n', flush: true);
    } catch (_) {
      // o diário é só para diagnóstico: sem arquivo, fica na memória
    }
  }

  void _cortar() {
    if (_linhas.length > maxLines) {
      _linhas.removeRange(0, _linhas.length - maxLines);
    }
  }

  static String _quando(DateTime t) {
    String d(int v, [int n = 2]) => v.toString().padLeft(n, '0');
    return '${d(t.month)}-${d(t.day)} ${d(t.hour)}:${d(t.minute)}:${d(t.second)}.${d(t.millisecond, 3)}';
  }
}

/// Diário da bike, em `files/bike_log.txt` (dá para copiar pela tela “Dados da bike”).
final bikeLogProvider = Provider<BikeLog>(
  (ref) => BikeLog(
    file: () async => File(
      p.join((await getApplicationSupportDirectory()).path, 'bike_log.txt'),
    ),
  ),
);
