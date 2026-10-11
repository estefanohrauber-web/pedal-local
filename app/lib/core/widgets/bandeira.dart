import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bandeira quadriculada de chegada: um mastro e um pano de 4 × 3 quadrados.
class BandeiraChegada extends StatelessWidget {
  const BandeiraChegada({super.key, this.tamanho = 34});

  /// Altura do mastro; o pano ocupa a metade de cima.
  final double tamanho;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Chegada',
    child: CustomPaint(
      size: Size(tamanho * 0.9, tamanho),
      painter: const _BandeiraPainter(),
    ),
  );
}

class _BandeiraPainter extends CustomPainter {
  const _BandeiraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final mastro = size.width * 0.1;
    final pano = Rect.fromLTWH(
      mastro,
      0,
      size.width - mastro,
      size.height * 0.55,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, mastro, size.height),
      Paint()..color = AppColors.escuro,
    );
    canvas.drawRect(pano, Paint()..color = Colors.white);
    final lado = pano.width / 4;
    final altura = pano.height / 3;
    final preto = Paint()..color = AppColors.escuro;
    for (var linha = 0; linha < 3; linha++) {
      for (var coluna = 0; coluna < 4; coluna++) {
        if ((linha + coluna).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(
              pano.left + coluna * lado,
              linha * altura,
              lado,
              altura,
            ),
            preto,
          );
        }
      }
    }
    canvas.drawRect(
      pano,
      Paint()
        ..color = AppColors.escuro
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BandeiraPainter old) => false;
}

/// O ponto de saída no mapa: bolinha branca com borda verde.
class PontoDeSaida extends StatelessWidget {
  const PontoDeSaida({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Saída',
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.destaque, width: 4),
      ),
    ),
  );
}
