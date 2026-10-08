import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef OpenLink = Future<void> Function(Uri uri);

/// Abre um endereço no navegador do celular (trocado nos testes).
final openLinkProvider = Provider<OpenLink>(
  (ref) => (uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);
