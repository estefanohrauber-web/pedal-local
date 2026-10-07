import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/db/app_database.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final db = await openAppDatabase();
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appThemeProvider.overrideWithValue(buildAppTheme(textTheme: GoogleFonts.plusJakartaSansTextTheme())),
    ],
    child: const PedalLocalApp(),
  ));
}
