import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  try {
    final db = await banco;
    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // A fonte vem dentro do app (pubspec.yaml) com todos os pesos: o negrito existe de verdade.
        appThemeProvider.overrideWithValue(
          buildAppTheme(textTheme: ThemeData().textTheme.apply(fontFamily: appFontFamily)),
        ),
        // No Android 12+, a tela de carregamento desenha o começo da abertura (MainActivity).
        aberturaDoAndroidProvider.overrideWithValue(args.contains('abertura-android')),
        brandTextStyleProvider.overrideWithValue(const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w800)),
      ],
      child: const PedalLocalApp(),
    ));
  } catch (e) {
    // Sem isso, o app ficaria parado na tela de abertura, sem explicar nada.
    runApp(ErroAoAbrir(erro: e, tentarDeNovo: () => main(args)));
  }
}

/// O banco não abriu (celular sem espaço, versão antiga do app por cima de uma nova…): explica e
/// deixa tentar de novo. Os dados continuam no celular.
class ErroAoAbrir extends StatelessWidget {
  const ErroAoAbrir({super.key, required this.erro, required this.tentarDeNovo});

  final Object erro;
  final VoidCallback tentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(textTheme: ThemeData().textTheme.apply(fontFamily: appFontFamily)),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(Icons.storage_rounded, size: 48, color: AppColors.avisoTexto),
                const SizedBox(height: 16),
                const Text('Não consegui abrir seus dados', style: AppText.titulo),
                const SizedBox(height: 8),
                const Text(
                  'Seus pedais e rotas continuam guardados no celular. Tente de novo; se continuar, '
                  'reinicie o celular. Se você instalou uma versão mais antiga do app, instale a mais nova.',
                  style: AppText.subtitulo,
                ),
                const SizedBox(height: 16),
                SelectableText('Detalhe para o suporte: $erro', style: AppText.suave),
                const Spacer(),
                FilledButton(onPressed: tentarDeNovo, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
