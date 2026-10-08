import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/geo.dart';
import '../links.dart';
import '../theme/app_theme.dart';

/// Desligado nos testes de tela (sem internet); ligado no app.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// Centro usado quando não há localização (São Paulo).
const defaultMapCenter = GeoPoint(-23.5505, -46.6333);

LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lon);

GeoPoint toGeo(LatLng p) => GeoPoint(p.latitude, p.longitude);

/// Camada de ruas do OpenStreetMap.
List<Widget> baseMapLayers(WidgetRef ref) => [
      if (ref.watch(mapTilesEnabledProvider))
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pedallocal.app',
          maxZoom: 19,
        ),
    ];

/// Crédito exigido pela licença do OpenStreetMap, compacto para caber em qualquer mapa.
/// Tocar abre os créditos completos e o link para corrigir o mapa (regra de uso da FOSSGIS).
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Tooltip(
        message: 'Créditos do mapa',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const MapCredits(),
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(6)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '© OpenStreetMap',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.textoSuave),
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.info_outline, size: 11, color: AppColors.textoSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const mapCopyrightUrl = 'https://www.openstreetmap.org/copyright';
const fixTheMapUrl = 'https://www.openstreetmap.org/fixthemap';

const _corpo = TextStyle(fontSize: 15, color: AppColors.texto);

/// De onde vêm o mapa, as rotas e a altitude.
class MapCredits extends ConsumerWidget {
  const MapCredits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abrir = ref.watch(openLinkProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sobre o mapa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'Mapa e ruas: © colaboradores do OpenStreetMap, licença ODbL.',
              style: _corpo,
            ),
            const SizedBox(height: 6),
            const Text('Rotas e altitude: Valhalla, nos servidores da FOSSGIS.', style: _corpo),
            const SizedBox(height: 6),
            const Text(
              'Viu uma rua errada ou faltando? O mapa é aberto e qualquer pessoa pode corrigir.',
              style: AppText.suave,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => abrir(Uri.parse(fixTheMapUrl)), child: const Text('Corrigir o mapa')),
            const SizedBox(height: 6),
            TextButton(onPressed: () => abrir(Uri.parse(mapCopyrightUrl)), child: const Text('Ver licença')),
          ],
        ),
      ),
    );
  }
}

const mapAttribution = MapAttribution();
