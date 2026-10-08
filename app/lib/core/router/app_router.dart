import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bike/conectar_bike_screen.dart';
import '../../features/criar_rota/criar_rota_screen.dart';
import '../../features/explorar/explorar_screen.dart';
import '../../features/inicio/inicio_screen.dart';
import '../../features/pedal/pedal_rota_screen.dart';
import '../../features/pedal_livre/pedal_livre_screen.dart';
import '../../features/resumo/resumo_screen.dart';
import '../../features/treinos/treinos_screen.dart';
import '../../features/voce/ajustes_screen.dart';
import '../../features/voce/voce_screen.dart';
import '../widgets/shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/inicio', builder: (c, s) => const InicioScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/explorar', builder: (c, s) => const ExplorarScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/treinos', builder: (c, s) => const TreinosScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/voce', builder: (c, s) => const VoceScreen())]),
        ],
      ),
      GoRoute(path: '/ajustes', builder: (c, s) => const AjustesScreen()),
      GoRoute(path: '/bike', builder: (c, s) => const ConectarBikeScreen()),
      GoRoute(path: '/criar-rota', builder: (c, s) => const CriarRotaScreen()),
      GoRoute(path: '/pedal-livre', builder: (c, s) => const PedalLivreScreen()),
      GoRoute(
        path: '/pedal-rota/:id',
        builder: (c, s) => PedalRotaScreen(routeId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/resumo/:id', builder: (c, s) => ResumoScreen(rideId: s.pathParameters['id']!)),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
