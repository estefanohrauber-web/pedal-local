import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bike/bike_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class PedalLocalApp extends ConsumerStatefulWidget {
  const PedalLocalApp({super.key});

  @override
  ConsumerState<PedalLocalApp> createState() => _PedalLocalAppState();
}

class _PedalLocalAppState extends ConsumerState<PedalLocalApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(bikeControllerProvider.notifier).reconnectLast());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pedal Local',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appThemeProvider),
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
