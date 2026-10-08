import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/geo.dart';

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

/// Crédito exigido pela licença do OpenStreetMap.
const mapAttribution = SimpleAttributionWidget(source: Text('© OpenStreetMap'));
