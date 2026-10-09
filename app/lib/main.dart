import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/db/app_database.dart';
import 'data/providers.dart';
import 'features/abertura/abertura.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Os dois ao mesmo tempo: quanto antes o app desenha, antes a abertura continua.
  final banco = openAppDatabase();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final db = await banco;
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appThemeProvider.overrideWithValue(buildAppTheme(textTheme: GoogleFonts.plusJakartaSansTextTheme())),
      // No Android 12+, a tela de carregamento desenha o começo da abertura (MainActivity).
      aberturaDoAndroidProvider.overrideWithValue(args.contains('abertura-android')),
      brandTextStyleProvider.overrideWithValue(GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
    ],
    child: const PedalLocalApp(),
  ));
}
