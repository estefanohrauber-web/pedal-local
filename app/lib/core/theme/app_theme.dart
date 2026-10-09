import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cores do Design 2 (claro e amigável).
abstract final class AppColors {
  static const fundo = Color(0xFFF4F6F5);
  static const superficie = Color(0xFFFFFFFF);
  static const borda = Color(0xFFE1E6E3);
  static const texto = Color(0xFF14201A);
  static const textoSuave = Color(0xFF5A6660);
  static const destaque = Color(0xFF138A52);
  static const destaqueSuave = Color(0xFFE3F4EA);
  static const destaqueTexto = Color(0xFF0E6B3F);
  static const posicao = Color(0xFF2F6FE4);
  static const avisoFundo = Color(0xFFFFF1E0);
  static const avisoTexto = Color(0xFF8A3C00);
  static const escuro = Color(0xFF14201A);
  static const neutro = Color(0xFFF1F4F2);

  /// O fantasma (o seu pedal anterior) no mapa do pedal.
  static const fantasma = Color(0xFF6D28D9);

  /// Uma cor por rota (mesma ordem de routeColorCount). Escuras o bastante para não
  /// sumir no verde das matas, no azul dos rios e no laranja das estradas do mapa.
  static const rotas = [
    Color(0xFF138A52), // verde
    Color(0xFF1E5BD8), // azul
    Color(0xFFC2187A), // magenta
    Color(0xFF7B3FE4), // roxo
    Color(0xFFD35400), // laranja queimado
    Color(0xFF00838F), // azul-petróleo
  ];
}

/// Cor da rota pelo índice guardado nela.
Color routeColor(int index) => AppColors.rotas[index % AppColors.rotas.length];

/// Cor de cada zona de esforço (1 a 7), do cinza ao roxo, como nos apps de treino.
const zoneColors = [
  Color(0xFF8A9690), // 1 recuperação
  Color(0xFF2F6FE4), // 2 resistência
  Color(0xFF1E9E5A), // 3 ritmo
  Color(0xFFD9A400), // 4 limiar
  Color(0xFFEA6A12), // 5 VO2 máx
  Color(0xFFD62C2C), // 6 anaeróbico
  Color(0xFF7B3FE4), // 7 sprint
];

Color zoneColor(int number) => zoneColors[(number - 1).clamp(0, zoneColors.length - 1)];

/// Escala de calor do mapa e do gráfico do pedal: 0 = azul (menor) … 1 = vermelho (maior).
const heatStops = [
  Color(0xFF2563EB), // azul
  Color(0xFF06B6D4), // ciano
  Color(0xFF22C55E), // verde
  Color(0xFFEAB308), // amarelo
  Color(0xFFDC2626), // vermelho
];

Color heatColor(double t) {
  final x = t.clamp(0.0, 1.0) * (heatStops.length - 1);
  final i = x.floor().clamp(0, heatStops.length - 2);
  return Color.lerp(heatStops[i], heatStops[i + 1], x - i)!;
}

abstract final class AppText {
  static const titulo = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.texto);
  static const subtitulo = TextStyle(fontSize: 15, color: AppColors.textoSuave);
  static const secao = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.texto);
  static const corpoForte = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.texto);
  static const suave = TextStyle(fontSize: 13, color: AppColors.textoSuave);
}

ThemeData buildAppTheme({TextTheme? textTheme}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.destaque,
    primary: AppColors.destaque,
    onPrimary: Colors.white,
    surface: AppColors.superficie,
    onSurface: AppColors.texto,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.fundo,
    textTheme: textTheme,
  );
  const pill = StadiumBorder();
  return base.copyWith(
    cardTheme: CardThemeData(
      color: AppColors.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borda),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.destaque,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        minimumSize: const Size(48, 52),
        shape: pill,
        side: const BorderSide(color: Color(0xFFD5DCD8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fundo,
      foregroundColor: AppColors.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.superficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borda),
      ),
    ),
  );
}

/// Sobrescrito no main() com a fonte Plus Jakarta Sans; os testes usam a fonte padrão.
final appThemeProvider = Provider<ThemeData>((ref) => buildAppTheme());

/// Fonte do nome “Pedalaqui” (Plus Jakarta Sans ExtraBold de verdade, não o negrito
/// imitado). Sobrescrita no main(); nos testes, null = a fonte do tema.
final brandTextStyleProvider = Provider<TextStyle?>((ref) => null);
