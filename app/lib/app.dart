import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bike/bike_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'data/relief_upgrade.dart';
import 'data/routes_store.dart';
import 'features/abertura/abertura.dart';

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
    Future.microtask(_refazerRelevo);
  }

  /// Rotas salvas antes das pontes em reta: refaz o relevo (quando houver internet).
  Future<void> _refazerRelevo() async {
    try {
      final store = ref.read(routesStoreProvider);
      if ((await store.all()).every((r) => r.relief >= reliefVersion)) return;
      final feitas = await upgradeRelief(store, ref.read(routeBuilderProvider));
      if (feitas > 0 && mounted) {
        ref.invalidate(routesProvider);
        ref.invalidate(routeByIdProvider);
      }
    } catch (_) {
      // sem banco (testes) ou sem internet: tenta na próxima abertura
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pedalaqui',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appThemeProvider),
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Abertura(
        nameStyle: ref.watch(brandTextStyleProvider),
        linhaPronta: ref.watch(aberturaLinhaProntaProvider),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
