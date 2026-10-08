# Pedal Local Flutter — Plano 2a: Mapa, criar rota e pedalar nela

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar uma rota tocando pontos no mapa (traçada pelas ruas, com relevo), salvá-la, vê-la no Explorar e pedalar nela com a posição andando no mapa, subidas pesando na velocidade e avisos de subida.

**Architecture:** Novos módulos puros `domain/geo.dart` e `domain/route_profile.dart` (o perfil da rota implementa `Terrain`, então a `RideSession` existente já simula as subidas). Serviços HTTP (OSRM, Open-Meteo) e localização (geolocator) atrás de interfaces em `data/`. O controlador do pedal livre vira `RideController(routeId?)`, um `NotifierProvider.autoDispose.family`, usado pelo pedal livre (`null`) e pelo pedal na rota (id). Mapa com `flutter_map` + tiles do OpenStreetMap.

**Tech Stack:** Flutter 3.47.6, flutter_riverpod 3.4, go_router 18, flutter_map 8.3, latlong2 0.10, http 1.6, geolocator 14, clock 1.1, sqflite (banco v2).

Spec: `docs/superpowers/specs/2026-10-07-app-flutter-fase1-design.md` (seções Rotas, Pedal, Dados, Serviços externos). Ordem combinada com o usuário em 2026-10-08: esta fatia primeiro; editor completo (arrastar, ida e volta, busca, gerador) e extras (instruções, fantasma, metas) depois.

## Global Constraints

- App em `C:\dev\pedal-local\app`; compilar com `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\dev\tmp`.
- Reamostragem da rota a cada **20 m**; suavização por média móvel de **5 amostras**; inclinação limitada a **±20 %**; aviso de subida ≥ 4 % / descida ≤ −3 % nos próximos **200 m** (já em `ride_session.dart`).
- Rotas: OSRM `https://routing.openstreetmap.de/routed-bike/route/v1/driving/{lon,lat;...}?overview=full&geometries=geojson`. Altimetria: `https://api.open-meteo.com/v1/elevation?latitude=..&longitude=..`, lotes de **100**. Toda requisição com `User-Agent: PedalLocal/0.1 (+https://github.com/estefanohrauber-web/pedal-local)`.
- Mapa: tiles `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, `userAgentPackageName: com.pedallocal.app`, atribuição “© OpenStreetMap” visível.
- Sem localização: centro padrão São Paulo (−23,5505, −46,6333) e aviso para arrastar o mapa.
- `domain/` continua em Dart puro (sem Flutter, sem pacotes de mapa).
- Banco sobe para a **versão 2** (tabela `routes`) sem perder ajustes nem pedais.
- Textos em português do Brasil; Design 2; alvos de toque ≥ 48 px.

## Estrutura de arquivos

```
app/lib/domain/geo.dart                    GeoPoint, haversine, distâncias, pointAt, resample
app/lib/domain/route_profile.dart          ProfilePoint, smoothElevations, RouteProfile (Terrain)
app/lib/data/db/app_database.dart          (modificar) versão 2 + tabela routes
app/lib/data/routes_store.dart             RouteRecord, RoutesStore (SQLite e memória)
app/lib/data/services/app_http.dart        User-Agent do app
app/lib/data/services/routing_service.dart RouteException, RoutingService (OSRM)
app/lib/data/services/elevation_service.dart ElevationService (Open-Meteo)
app/lib/data/services/location_service.dart LocationService (geolocator) e versão fixa
app/lib/data/route_builder.dart            BuiltRoute, RouteBuilder
app/lib/data/providers.dart                (modificar) providers de rotas, http, localização
app/lib/core/format/format.dart            (modificar) formatDate
app/lib/core/widgets/app_map.dart          camada de ruas, atribuição, conversões
app/lib/core/widgets/elevation_chart.dart  gráfico de relevo com marcador
app/lib/features/pedal/ride_controller.dart  RideController (substitui free_ride_controller.dart)
app/lib/features/pedal/ride_widgets.dart   AvisoFaixa, RideControls, SimControls
app/lib/features/pedal/pedal_rota_screen.dart
app/lib/features/pedal_livre/pedal_livre_screen.dart (reescrever com os widgets comuns)
app/lib/features/explorar/explorar_screen.dart (reescrever)
app/lib/features/explorar/route_tile.dart
app/lib/features/criar_rota/criar_rota_screen.dart
app/lib/features/escolher_pedal/escolher_pedal_sheet.dart (reescrever: “Seguir uma rota” ativo)
app/lib/features/inicio/inicio_screen.dart (reescrever: cartão de rotas)
app/lib/features/resumo/resumo_screen.dart (reescrever: “Rota concluída!” e nome da rota)
app/lib/core/router/app_router.dart        (reescrever: /criar-rota e /pedal-rota/:id)
app/android/app/src/main/AndroidManifest.xml (localização sem maxSdk)
```

Cada bloco de código é precedido por `<!-- file: caminho -->` (a partir da raiz do repositório).

---

### Task 1: Domínio — geografia e perfil da rota

**Files:**
- Create: `app/lib/domain/geo.dart`, `app/lib/domain/route_profile.dart`, `app/test/support/geo_helpers.dart`
- Test: `app/test/domain/geo_test.dart`, `app/test/domain/route_profile_test.dart`

**Interfaces:**
- Consumes: `Terrain` (`app/lib/domain/ride_session.dart`).
- Produces: `GeoPoint(lat, lon)` com `==`; `double haversine(GeoPoint a, GeoPoint b)`; `List<double> cumulativeDistances(List<GeoPoint>)`; `int segmentIndex(List<double> cum, double d)`; `GeoPoint pointAt(List<GeoPoint>, List<double> cum, double d)`; `List<GeoPoint> resample(List<GeoPoint>, [double step = 20])`.
- Produces: `maxGrade = 0.2`; `ProfilePoint(lat, lon, alt)` com `geo`; `List<double> smoothElevations(List<double>, [int window = 5])`; `RouteProfile(List<ProfilePoint>)` implementa `Terrain`, com `points` (`List<GeoPoint>`), `alts`, `cum`, `gain`, `loss`, `distance`, `gradeAt(d)`, `lookahead(d, span)`, `elevationAt(d)`, `positionAt(d)`, `traveled(d)`.

- [ ] **Step 1: Testes que falham**

<!-- file: app/test/support/geo_helpers.dart -->
```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';

const mPerDegLat = 6371000 * math.pi / 180;

/// Linha reta para o norte com [count] pontos espaçados [spacingM] metros.
List<GeoPoint> northLine(int count, double spacingM, {GeoPoint start = const GeoPoint(-23.5, -46.6)}) => [
      for (var i = 0; i < count; i++) GeoPoint(start.lat + i * spacingM / mPerDegLat, start.lon),
    ];

/// Perfil reto para o norte, um ponto a cada [spacingM] metros, com as altitudes dadas.
List<ProfilePoint> northProfile(List<double> alts, {double spacingM = 20}) {
  final linha = northLine(alts.length, spacingM);
  return [for (var i = 0; i < alts.length; i++) ProfilePoint(linha[i].lat, linha[i].lon, alts[i])];
}

void expectNear(double actual, double expected, double tol) =>
    expect((actual - expected).abs(), lessThanOrEqualTo(tol), reason: 'esperado $expected ± $tol, veio $actual');
```

<!-- file: app/test/domain/geo_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/geo_helpers.dart';

void main() {
  test('haversine: 1 grau de latitude ≈ 111,2 km', () {
    expectNear(haversine(const GeoPoint(0, 0), const GeoPoint(1, 0)), 111195, 1);
  });

  test('haversine: mesmo ponto = 0', () {
    expect(haversine(const GeoPoint(-23.5, -46.6), const GeoPoint(-23.5, -46.6)), 0);
  });

  test('cumulativeDistances acumula os trechos', () {
    final cum = cumulativeDistances(northLine(3, 20));
    expect(cum.length, 3);
    expect(cum[0], 0);
    expectNear(cum[1], 20, 0.01);
    expectNear(cum[2], 40, 0.01);
  });

  test('pointAt interpola no meio e limita nas pontas', () {
    final pts = northLine(2, 100);
    final cum = cumulativeDistances(pts);
    expectNear(pointAt(pts, cum, 50).lat, pts[0].lat + 50 / mPerDegLat, 1e-9);
    expectNear(pointAt(pts, cum, 500).lat, pts[1].lat, 1e-9);
    expect(pointAt(pts, cum, -5), pts[0]);
  });

  test('resample: linha de 100 m vira 6 pontos a cada 20 m', () {
    final out = resample(northLine(2, 100));
    expect(out.length, 6);
    final cum = cumulativeDistances(out);
    for (var i = 1; i < out.length; i++) {
      expectNear(cum[i] - cum[i - 1], 20, 0.01);
    }
  });

  test('resample: linha curta mantém início e fim', () {
    final pts = northLine(2, 15);
    expect(resample(pts), [pts[0], pts[1]]);
  });

  test('resample: último trecho nunca fica minúsculo', () {
    final cum = cumulativeDistances(resample(northLine(2, 101)));
    expect(cum.last - cum[cum.length - 2], greaterThanOrEqualTo(10));
  });
}
```

<!-- file: app/test/domain/route_profile_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/route_profile.dart';

import '../support/geo_helpers.dart';

// 5 % nos primeiros 100 m, depois plano.
RouteProfile perfil() => RouteProfile(northProfile([0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5]));

void main() {
  test('smoothElevations: média móvel centrada', () {
    final out = smoothElevations([0, 0, 10, 0, 0], 3);
    for (final (i, v) in [0.0, 10 / 3, 10 / 3, 10 / 3, 0.0].indexed) {
      expectNear(out[i], v, 1e-9);
    }
  });

  test('smoothElevations: altitude constante não muda', () {
    expect(smoothElevations([5, 5, 5, 5, 5, 5]), [5, 5, 5, 5, 5, 5]);
  });

  test('totais', () {
    final p = perfil();
    expectNear(p.distance, 200, 0.05);
    expectNear(p.gain, 5, 1e-9);
    expect(p.loss, 0);
  });

  test('inclinação por trecho', () {
    final p = perfil();
    expectNear(p.gradeAt(10), 0.05, 1e-4);
    expectNear(p.gradeAt(150), 0, 1e-9);
    expectNear(p.gradeAt(999), 0, 1e-9);
  });

  test('lookahead é a inclinação média à frente', () {
    final p = perfil();
    expectNear(p.lookahead(0, 100), 0.05, 1e-4);
    expectNear(p.lookahead(50, 100), 0.025, 1e-4);
    expectNear(p.lookahead(100, 100), 0, 1e-4);
    expect(p.lookahead(200, 200), 0);
  });

  test('altitude, posição e trecho percorrido', () {
    final p = perfil();
    expectNear(p.elevationAt(30), 1.5, 1e-4);
    expectNear(p.positionAt(40).lat, p.points[2].lat, 1e-9);
    final feito = p.traveled(50);
    expect(feito.length, 4); // 3 pontos inteiros + a posição atual
    expectNear(feito.last.lat, p.positionAt(50).lat, 1e-12);
  });

  test('inclinação limitada a ±20 %', () {
    expect(RouteProfile(northProfile([0, 10])).gradeAt(5), maxGrade);
    expect(RouteProfile(northProfile([10, 0])).gradeAt(5), -maxGrade);
  });

  test('rota de um ponto só não quebra', () {
    final p = RouteProfile(northProfile([7]));
    expect(p.distance, 0);
    expect(p.gradeAt(0), 0);
    expect(p.lookahead(0, 200), 0);
    expect(p.elevationAt(0), 7);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain/geo_test.dart test/domain/route_profile_test.dart`
Expected: FAIL — `geo.dart` e `route_profile.dart` não existem.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/domain/geo.dart -->
```dart
import 'dart:math' as math;

/// Um ponto no mapa (graus decimais).
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}

const _earthRadiusM = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;

double haversine(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

List<double> cumulativeDistances(List<GeoPoint> points) {
  final out = <double>[0];
  for (var i = 1; i < points.length; i++) {
    out.add(out[i - 1] + haversine(points[i - 1], points[i]));
  }
  return out;
}

/// Índice i do trecho [i, i+1] que contém a distância [d] (`cum` crescente).
int segmentIndex(List<double> cum, double d) {
  var lo = 0;
  var hi = cum.length - 2;
  if (hi < 0) return 0;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (cum[mid] <= d) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

GeoPoint pointAt(List<GeoPoint> points, List<double> cum, double d) {
  if (points.length == 1) return points.first;
  final total = cum.last;
  final dist = math.min(math.max(d, 0.0), total);
  final i = segmentIndex(cum, dist);
  final seg = cum[i + 1] - cum[i];
  final t = seg > 0 ? (dist - cum[i]) / seg : 0.0;
  final a = points[i];
  final b = points[i + 1];
  if (t == 0) return a;
  return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);
}

/// Pontos a cada [step] metros; o último trecho fica entre step/2 e 1,5·step.
List<GeoPoint> resample(List<GeoPoint> points, [double step = 20]) {
  if (points.length < 2) return List.of(points);
  final cum = cumulativeDistances(points);
  final total = cum.last;
  final out = <GeoPoint>[];
  for (var d = 0.0; d < total - step / 2; d += step) {
    out.add(pointAt(points, cum, d));
  }
  out.add(points.last);
  return out;
}
```

<!-- file: app/lib/domain/route_profile.dart -->
```dart
import 'dart:math' as math;

import 'geo.dart';
import 'ride_session.dart';

const maxGrade = 0.2;

double _clamp(double x, double lo, double hi) => math.min(hi, math.max(lo, x));

/// Ponto da rota já reamostrado, com a altitude suavizada (m).
class ProfilePoint {
  const ProfilePoint(this.lat, this.lon, this.alt);

  final double lat;
  final double lon;
  final double alt;

  GeoPoint get geo => GeoPoint(lat, lon);
}

List<double> smoothElevations(List<double> alts, [int window = 5]) {
  final half = window ~/ 2;
  return [
    for (var i = 0; i < alts.length; i++)
      () {
        var soma = 0.0;
        var n = 0;
        for (var j = math.max(0, i - half); j <= math.min(alts.length - 1, i + half); j++) {
          soma += alts[j];
          n++;
        }
        return soma / n;
      }(),
  ];
}

/// Relevo da rota: inclinação por trecho, totais e consultas pela distância percorrida.
class RouteProfile implements Terrain {
  factory RouteProfile(List<ProfilePoint> pontos) {
    final points = [for (final p in pontos) p.geo];
    final alts = [for (final p in pontos) p.alt];
    final cum = cumulativeDistances(points);
    final grades = <double>[];
    var gain = 0.0;
    var loss = 0.0;
    for (var i = 0; i < pontos.length - 1; i++) {
      final run = cum[i + 1] - cum[i];
      final rise = alts[i + 1] - alts[i];
      grades.add(run > 0 ? _clamp(rise / run, -maxGrade, maxGrade) : 0);
      if (rise > 0) {
        gain += rise;
      } else {
        loss -= rise;
      }
    }
    return RouteProfile._(points, alts, cum, grades, gain, loss);
  }

  RouteProfile._(this.points, this.alts, this.cum, this._grades, this.gain, this.loss);

  final List<GeoPoint> points;
  final List<double> alts;
  final List<double> cum;
  final List<double> _grades;
  final double gain;
  final double loss;

  @override
  double get distance => cum.last;

  @override
  double gradeAt(double d) => _grades.isEmpty ? 0 : _grades[segmentIndex(cum, _clamp(d, 0, distance))];

  @override
  double lookahead(double d, double span) {
    final start = _clamp(d, 0, distance);
    final end = math.min(distance, start + span);
    return end - start > 1 ? (elevationAt(end) - elevationAt(start)) / (end - start) : 0;
  }

  double elevationAt(double d) {
    if (alts.length < 2) return alts.isEmpty ? 0 : alts.first;
    final x = _clamp(d, 0, distance);
    final i = segmentIndex(cum, x);
    final seg = cum[i + 1] - cum[i];
    final t = seg > 0 ? (x - cum[i]) / seg : 0.0;
    return alts[i] + (alts[i + 1] - alts[i]) * t;
  }

  GeoPoint positionAt(double d) => points.isEmpty ? const GeoPoint(0, 0) : pointAt(points, cum, d);

  /// Pontos já percorridos até [d], terminando na posição atual (para pintar a linha feita).
  List<GeoPoint> traveled(double d) {
    if (points.length < 2) return List.of(points);
    final x = _clamp(d, 0, distance);
    return [...points.take(segmentIndex(cum, x) + 1), positionAt(x)];
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain`
Expected: `All tests passed!` (34 antigos + 15 novos)

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/domain app/test/domain app/test/support/geo_helpers.dart && git commit -m "feat(app): geografia e perfil de relevo da rota no domínio"
```

---

### Task 2: Dados — rotas, serviços e construção da rota

**Files:**
- Modify: `app/lib/data/db/app_database.dart` (substituir), `app/lib/data/providers.dart` (substituir), `app/lib/core/format/format.dart` (substituir), `app/android/app/src/main/AndroidManifest.xml` (substituir)
- Create: `app/lib/data/routes_store.dart`, `app/lib/data/services/app_http.dart`, `app/lib/data/services/routing_service.dart`, `app/lib/data/services/elevation_service.dart`, `app/lib/data/services/location_service.dart`, `app/lib/data/route_builder.dart`
- Test: `app/test/data/routes_store_test.dart`, `app/test/data/routing_service_test.dart`, `app/test/data/elevation_service_test.dart`, `app/test/data/route_builder_test.dart`, `app/test/core/format_test.dart` (substituir)

**Interfaces:**
- Consumes: `GeoPoint`, `resample` , `ProfilePoint`, `smoothElevations`, `RouteProfile` (Task 1).
- Produces: banco versão 2 com tabela `routes`; `RouteRecord({id, name, createdAt, waypoints: List<GeoPoint>, points: List<ProfilePoint>, distanceM, gainM, lossM})` + `copyWith({String? name})`; `abstract class RoutesStore { upsert, byId, all, delete }`; `SqliteRoutesStore(Database)`; `MemoryRoutesStore`.
- Produces: `appHeaders`; `RouteException(code, message)` com códigos `poucos-pontos | sem-conexao | sem-caminho | servico`; `osrmBase`; `RoutingService(http.Client)` com `Future<List<GeoPoint>> route(List<GeoPoint>)`; `elevationBase`, `elevationBatch = 100`, `ElevationService(http.Client)` com `Future<List<double>> elevations(List<GeoPoint>)`.
- Produces: `abstract class LocationService { Future<GeoPoint?> current(); }`; `GeolocatorLocationService`; `FixedLocationService(GeoPoint?)`.
- Produces: `sampleStepM = 20`; `BuiltRoute(route, {flat})`; `RouteBuilder({routing, elevation, now?, newId?})` com `Future<BuiltRoute> build(List<GeoPoint> waypoints)`.
- Produces: providers `routesStoreProvider`, `routesProvider` (`FutureProvider<List<RouteRecord>>`), `routeByIdProvider` (`FutureProvider.family<RouteRecord?, String>`), `httpClientProvider`, `routeBuilderProvider`, `locationServiceProvider`.
- Produces: `String formatDate(DateTime)` → `dd/MM`.

- [ ] **Step 1: Testes que falham**

<!-- file: app/test/data/routes_store_test.dart -->
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/route_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RouteRecord rota(String id, DateTime criada, {String nome = 'Volta do bairro'}) => RouteRecord(
      id: id,
      name: nome,
      createdAt: criada,
      waypoints: const [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)],
      points: const [ProfilePoint(-23.5, -46.6, 760.5), ProfilePoint(-23.5001, -46.6001, 761)],
      distanceM: 8400,
      gainM: 96,
      lossM: 90,
    );

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('salva e lê a rota com pontos e altitudes', () async {
    final store = SqliteRoutesStore(db);
    await store.upsert(rota('a', DateTime(2026, 10, 8, 9)));
    final r = (await store.byId('a'))!;
    expect(r.name, 'Volta do bairro');
    expect(r.createdAt, DateTime(2026, 10, 8, 9));
    expect(r.waypoints, const [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)]);
    expect(r.points.length, 2);
    expect(r.points.first.alt, 760.5);
    expect(r.distanceM, 8400);
    expect(await store.byId('zzz'), isNull);
  });

  test('all: mais nova primeiro; apagar remove', () async {
    final store = SqliteRoutesStore(db);
    await store.upsert(rota('velha', DateTime(2026, 10, 1)));
    await store.upsert(rota('nova', DateTime(2026, 10, 8)));
    expect((await store.all()).map((r) => r.id), ['nova', 'velha']);
    await store.delete('velha');
    expect((await store.all()).map((r) => r.id), ['nova']);
  });

  test('copyWith troca o nome', () {
    expect(rota('a', DateTime(2026)).copyWith(name: 'Ladeira').name, 'Ladeira');
  });

  test('versão em memória', () async {
    final store = MemoryRoutesStore();
    await store.upsert(rota('velha', DateTime(2026, 10, 1)));
    await store.upsert(rota('nova', DateTime(2026, 10, 8)));
    expect((await store.all()).map((r) => r.id), ['nova', 'velha']);
  });

  test('banco da versão 1 ganha a tabela de rotas e mantém os pedais', () async {
    final dir = await Directory.systemTemp.createTemp('pedal_v1');
    final caminho = '${dir.path}/v1.db';
    final antigo = await databaseFactoryFfi.openDatabase(caminho,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async {
            await d.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            await d.execute("INSERT INTO settings VALUES ('pesoKg', '82')");
          },
        ));
    await antigo.close();
    final novo = await openAppDatabase(factory: databaseFactoryFfi, path: caminho);
    expect(await novo.query('settings'), [
      {'key': 'pesoKg', 'value': '82'},
    ]);
    await SqliteRoutesStore(novo).upsert(rota('a', DateTime(2026)));
    expect((await SqliteRoutesStore(novo).all()).length, 1);
    await novo.close();
    await dir.delete(recursive: true);
  });
}
```

<!-- file: app/test/data/routing_service_test.dart -->
```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/domain/geo.dart';

const dois = [GeoPoint(-23.5, -46.6), GeoPoint(-23.51, -46.61)];

http.Response json(Object data, [int status = 200]) => http.Response(jsonEncode(data), status);

Matcher erro(String code) => throwsA(isA<RouteException>().having((e) => e.code, 'code', code));

void main() {
  test('monta a URL como lon,lat, manda o User-Agent e devolve os pontos', () async {
    late http.Request pedido;
    final client = MockClient((req) async {
      pedido = req;
      return json({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [-46.6, -23.5],
                [-46.61, -23.51],
              ],
            },
          },
        ],
      });
    });
    final linha = await RoutingService(client).route(dois);
    expect(linha, dois);
    expect(
      pedido.url.toString(),
      '$osrmBase-46.600000,-23.500000;-46.610000,-23.510000?overview=full&geometries=geojson',
    );
    expect(pedido.headers['User-Agent'], contains('PedalLocal'));
  });

  test('menos de dois pontos', () {
    expect(RoutingService(MockClient((r) async => json({}))).route(const [GeoPoint(0, 0)]), erro('poucos-pontos'));
  });

  test('sem conexão', () {
    final client = MockClient((r) async => throw http.ClientException('Failed host lookup'));
    expect(RoutingService(client).route(dois), erro('sem-conexao'));
  });

  test('sem caminho', () {
    expect(RoutingService(MockClient((r) async => json({'code': 'NoRoute'}, 400))).route(dois), erro('sem-caminho'));
    expect(RoutingService(MockClient((r) async => json({'code': 'NoSegment'}, 400))).route(dois), erro('sem-caminho'));
  });

  test('serviço fora do ar', () {
    expect(RoutingService(MockClient((r) async => http.Response('<html>', 502))).route(dois), erro('servico'));
  });
}
```

<!-- file: app/test/data/elevation_service_test.dart -->
```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/domain/geo.dart';

int quantos(http.Request req) => req.url.queryParameters['latitude']!.split(',').length;

void main() {
  test('busca em lotes de 100 e mantém a ordem', () async {
    var n = 0;
    final pedidos = <http.Request>[];
    final client = MockClient((req) async {
      pedidos.add(req);
      final k = quantos(req);
      final base = n;
      n += k;
      return http.Response(jsonEncode({'elevation': [for (var i = 0; i < k; i++) base + i]}), 200);
    });
    final pts = [for (var i = 0; i < 150; i++) GeoPoint(-23.5 + i * 1e-4, -46.6)];
    final alts = await ElevationService(client).elevations(pts);
    expect(pedidos.length, 2);
    expect(quantos(pedidos.first), 100);
    expect(alts, [for (var i = 0; i < 150; i++) i.toDouble()]);
  });

  test('resposta com tamanho errado falha', () {
    final client = MockClient((r) async => http.Response(jsonEncode({'elevation': [1]}), 200));
    expect(ElevationService(client).elevations(const [GeoPoint(0, 0), GeoPoint(0, 1)]), throwsException);
  });

  test('HTTP de erro falha', () {
    final client = MockClient((r) async => http.Response('limite', 429));
    expect(ElevationService(client).elevations(const [GeoPoint(0, 0)]), throwsException);
  });
}
```

<!-- file: app/test/data/route_builder_test.dart -->
```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/routing_service.dart';

import '../support/geo_helpers.dart';

final _linha = northLine(2, 100);

http.Response _osrm() => http.Response(
      jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                for (final p in _linha) [p.lon, p.lat],
              ],
            },
          },
        ],
      }),
      200,
    );

RouteBuilder builder(MockClient client) => RouteBuilder(
      routing: RoutingService(client),
      elevation: ElevationService(client),
      now: () => DateTime(2026, 10, 8, 9),
      newId: () => 'r1',
    );

void main() {
  test('rota com pontos a cada 20 m e altimetria suavizada', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'routing.openstreetmap.de') return _osrm();
      final k = req.url.queryParameters['latitude']!.split(',').length;
      return http.Response(jsonEncode({'elevation': [for (var i = 0; i < k; i++) i * 2]}), 200);
    });
    final built = await builder(client).build(_linha);
    expect(built.flat, isFalse);
    final r = built.route;
    expect(r.id, 'r1');
    expect(r.name, '');
    expect(r.createdAt, DateTime(2026, 10, 8, 9));
    expect(r.points.length, 6);
    expectNear(r.distanceM, 100, 0.5);
    expectNear(r.gainM, 6, 1e-9); // 0,2,4,6,8,10 suavizado → 2,3,4,6,7,8
    expect(r.lossM, 0);
    expect(r.waypoints, _linha);
  });

  test('altimetria fora do ar: rota plana com aviso', () async {
    final client = MockClient((req) async =>
        req.url.host == 'routing.openstreetmap.de' ? _osrm() : http.Response('erro', 500));
    final built = await builder(client).build(_linha);
    expect(built.flat, isTrue);
    expect(built.route.points.every((p) => p.alt == 0), isTrue);
  });

  test('erro de rota sobe para quem chamou', () {
    final client = MockClient((req) async => _osrm());
    expect(builder(client).build([_linha.first]), throwsA(isA<RouteException>()));
  });
}
```

<!-- file: app/test/core/format_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/core/format/format.dart';

void main() {
  test('formatNumber usa vírgula e ponto do pt-BR', () {
    expect(formatNumber(1234.5, 1), '1.234,5');
    expect(formatNumber(7.25), '7');
  });

  test('formatNumber não mostra "-0"', () {
    expect(formatNumber(-0.2), '0');
    expect(formatNumber(-0.04, 1), '0,0');
  });

  test('formatKm', () {
    expect(formatKm(1234), '1,23 km');
  });

  test('formatTime', () {
    expect(formatTime(0), '0:00');
    expect(formatTime(65.9), '1:05');
    expect(formatTime(3725), '1:02:05');
  });

  test('formatDateTime e formatDate', () {
    expect(formatDateTime(DateTime(2026, 10, 7, 9, 5)), '07/10 às 09:05');
    expect(formatDate(DateTime(2026, 10, 7)), '07/10');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/data test/core`
Expected: FAIL — `routes_store.dart`, serviços, `route_builder.dart` e `formatDate` não existem.

- [ ] **Step 3: Implementar banco v2, store e formatação**

<!-- file: app/lib/data/db/app_database.dart -->
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _schemaVersion = 2;

Future<void> _createRoutes(DatabaseExecutor db) => db.execute('''
  CREATE TABLE routes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    waypoints TEXT NOT NULL,
    points TEXT NOT NULL,
    distance_m REAL NOT NULL,
    gain_m REAL NOT NULL,
    loss_m REAL NOT NULL
  )''');

/// Abre (ou cria/atualiza) o banco do app. Nos testes, passe `databaseFactoryFfi` e `inMemoryDatabasePath`.
Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? p.join(await f.getDatabasesPath(), 'pedal_local.db');
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: _schemaVersion,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('''
          CREATE TABLE rides (
            id TEXT PRIMARY KEY,
            route_id TEXT,
            mode TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            moving_time_s REAL NOT NULL,
            distance_m REAL NOT NULL,
            avg_power_w REAL NOT NULL,
            avg_speed_kmh REAL NOT NULL,
            gain_m REAL NOT NULL,
            kcal REAL NOT NULL,
            completed INTEGER NOT NULL,
            samples BLOB NOT NULL
          )''');
        await db.execute('CREATE INDEX rides_started ON rides(started_at DESC)');
        await _createRoutes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createRoutes(db);
      },
    ),
  );
}
```

<!-- file: app/lib/data/routes_store.dart -->
```dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/geo.dart';
import '../domain/route_profile.dart';

class RouteRecord {
  const RouteRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.waypoints,
    required this.points,
    required this.distanceM,
    required this.gainM,
    required this.lossM,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<GeoPoint> waypoints;
  final List<ProfilePoint> points; // a cada 20 m, altitude suavizada
  final double distanceM;
  final double gainM;
  final double lossM;

  RouteRecord copyWith({String? name}) => RouteRecord(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        waypoints: waypoints,
        points: points,
        distanceM: distanceM,
        gainM: gainM,
        lossM: lossM,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'waypoints': jsonEncode([
          for (final w in waypoints) [w.lat, w.lon],
        ]),
        'points': jsonEncode([
          for (final p in points) [p.lat, p.lon, p.alt],
        ]),
        'distance_m': distanceM,
        'gain_m': gainM,
        'loss_m': lossM,
      };

  factory RouteRecord.fromRow(Map<String, Object?> r) {
    double n(Object? v) => (v as num).toDouble();
    final waypoints = jsonDecode(r['waypoints'] as String) as List;
    final points = jsonDecode(r['points'] as String) as List;
    return RouteRecord(
      id: r['id'] as String,
      name: r['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      waypoints: [
        for (final w in waypoints) GeoPoint(n((w as List)[0]), n(w[1])),
      ],
      points: [
        for (final p in points) ProfilePoint(n((p as List)[0]), n(p[1]), n(p[2])),
      ],
      distanceM: n(r['distance_m']),
      gainM: n(r['gain_m']),
      lossM: n(r['loss_m']),
    );
  }
}

abstract class RoutesStore {
  Future<void> upsert(RouteRecord route);
  Future<RouteRecord?> byId(String id);
  Future<List<RouteRecord>> all();
  Future<void> delete(String id);
}

class SqliteRoutesStore implements RoutesStore {
  SqliteRoutesStore(this._db);

  final Database _db;

  @override
  Future<void> upsert(RouteRecord route) =>
      _db.insert('routes', route.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<RouteRecord?> byId(String id) async {
    final rows = await _db.query('routes', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : RouteRecord.fromRow(rows.first);
  }

  @override
  Future<List<RouteRecord>> all() async {
    final rows = await _db.query('routes', orderBy: 'created_at DESC');
    return rows.map(RouteRecord.fromRow).toList();
  }

  @override
  Future<void> delete(String id) => _db.delete('routes', where: 'id = ?', whereArgs: [id]);
}

class MemoryRoutesStore implements RoutesStore {
  final _routes = <String, RouteRecord>{};

  @override
  Future<void> upsert(RouteRecord route) async => _routes[route.id] = route;

  @override
  Future<RouteRecord?> byId(String id) async => _routes[id];

  @override
  Future<List<RouteRecord>> all() async =>
      _routes.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> delete(String id) async => _routes.remove(id);
}
```

<!-- file: app/lib/core/format/format.dart -->
```dart
import 'dart:math' as math;

import 'package:intl/intl.dart';

final _formatters = <int, NumberFormat>{};

NumberFormat _formatter(int casas) => _formatters.putIfAbsent(
      casas,
      () => NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: casas),
    );

String formatNumber(double n, [int casas = 0]) {
  final valor = n.abs() < 0.5 / math.pow(10, casas) ? 0 : n;
  return _formatter(casas).format(valor);
}

String formatKm(double metros, [int casas = 2]) => '${formatNumber(metros / 1000, casas)} km';

String formatTime(double segundos) {
  final s = segundos.floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final r = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$r' : '$m:$r';
}

String _dois(int n) => n.toString().padLeft(2, '0');

String formatDate(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}';

String formatDateTime(DateTime d) => '${formatDate(d)} às ${_dois(d.hour)}:${_dois(d.minute)}';
```

- [ ] **Step 4: Implementar serviços, construtor de rota e providers**

<!-- file: app/lib/data/services/app_http.dart -->
```dart
/// Identifica o app nos serviços abertos (exigência das políticas de uso).
const appUserAgent = 'PedalLocal/0.1 (+https://github.com/estefanohrauber-web/pedal-local)';

const appHeaders = {'User-Agent': appUserAgent};
```

<!-- file: app/lib/data/services/routing_service.dart -->
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import 'app_http.dart';

const osrmBase = 'https://routing.openstreetmap.de/routed-bike/route/v1/driving/';

class RouteException implements Exception {
  const RouteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Traça o caminho pelas ruas entre os pontos (OSRM, perfil bicicleta).
class RoutingService {
  RoutingService(this._client);

  final http.Client _client;

  Future<List<GeoPoint>> route(List<GeoPoint> waypoints) async {
    if (waypoints.length < 2) {
      throw const RouteException('poucos-pontos', 'Toque pelo menos dois pontos no mapa.');
    }
    final coords = waypoints.map((p) => '${p.lon.toStringAsFixed(6)},${p.lat.toStringAsFixed(6)}').join(';');
    final uri = Uri.parse('$osrmBase$coords?overview=full&geometries=geojson');

    http.Response res;
    try {
      res = await _client.get(uri, headers: appHeaders).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const RouteException('sem-conexao', 'Sem conexão — não deu para traçar a rota.');
    }

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    final code = data?['code'];
    final routes = data?['routes'] as List?;
    if (code == 'NoRoute' || code == 'NoSegment' || (code == 'Ok' && (routes == null || routes.isEmpty))) {
      throw const RouteException('sem-caminho', 'Não encontrei caminho entre esses pontos.');
    }
    if (res.statusCode != 200 || code != 'Ok') {
      throw const RouteException('servico', 'O serviço de rotas não respondeu. Tente de novo em instantes.');
    }
    final geometry = (routes!.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    return [
      for (final c in coordinates) GeoPoint(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
  }
}
```

<!-- file: app/lib/data/services/elevation_service.dart -->
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/geo.dart';
import 'app_http.dart';

const elevationBase = 'https://api.open-meteo.com/v1/elevation';
const elevationBatch = 100;

/// Altitude de cada ponto (Open-Meteo, até 100 coordenadas por chamada).
class ElevationService {
  ElevationService(this._client);

  final http.Client _client;

  Future<List<double>> elevations(List<GeoPoint> points) async {
    final out = <double>[];
    for (var i = 0; i < points.length; i += elevationBatch) {
      final lote = points.sublist(i, (i + elevationBatch).clamp(0, points.length));
      final lat = lote.map((p) => p.lat.toStringAsFixed(5)).join(',');
      final lon = lote.map((p) => p.lon.toStringAsFixed(5)).join(',');
      final res = await _client
          .get(Uri.parse('$elevationBase?latitude=$lat&longitude=$lon'), headers: appHeaders)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('Altimetria indisponível (HTTP ${res.statusCode})');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elevation = data['elevation'];
      if (elevation is! List || elevation.length != lote.length) {
        throw Exception('Altimetria: resposta inválida');
      }
      out.addAll(elevation.map((e) => (e as num).toDouble()));
    }
    return out;
  }
}
```

<!-- file: app/lib/data/services/location_service.dart -->
```dart
import 'package:geolocator/geolocator.dart';

import '../../domain/geo.dart';

/// Onde a pessoa está agora, ou `null` se não der (sem permissão, GPS desligado, demora).
abstract class LocationService {
  Future<GeoPoint?> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// Para testes: sempre devolve o mesmo ponto.
class FixedLocationService implements LocationService {
  const FixedLocationService(this.point);

  final GeoPoint? point;

  @override
  Future<GeoPoint?> current() async => point;
}
```

<!-- file: app/lib/data/route_builder.dart -->
```dart
import '../domain/geo.dart';
import '../domain/route_profile.dart';
import 'routes_store.dart';
import 'services/elevation_service.dart';
import 'services/routing_service.dart';

const sampleStepM = 20.0;

class BuiltRoute {
  const BuiltRoute(this.route, {required this.flat});

  final RouteRecord route;

  /// A altimetria falhou e a rota ficou plana.
  final bool flat;
}

double _round(double x, int casas) {
  var f = 1.0;
  for (var i = 0; i < casas; i++) {
    f *= 10;
  }
  return (x * f).roundToDouble() / f;
}

/// Pontos tocados no mapa → rota pelas ruas, reamostrada, com relevo. O nome é dado depois.
class RouteBuilder {
  RouteBuilder({required this.routing, required this.elevation, DateTime Function()? now, String Function()? newId})
      : _now = now ?? DateTime.now,
        _newId = newId ?? (() => 'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}');

  final RoutingService routing;
  final ElevationService elevation;
  final DateTime Function() _now;
  final String Function() _newId;

  Future<BuiltRoute> build(List<GeoPoint> waypoints) async {
    final linha = await routing.route(waypoints);
    final amostras = resample(linha, sampleStepM);
    List<double> alts;
    var flat = false;
    try {
      alts = smoothElevations(await elevation.elevations(amostras));
    } catch (_) {
      alts = List.filled(amostras.length, 0);
      flat = true;
    }
    final pontos = [
      for (var i = 0; i < amostras.length; i++)
        ProfilePoint(_round(amostras[i].lat, 6), _round(amostras[i].lon, 6), _round(alts[i], 1)),
    ];
    final perfil = RouteProfile(pontos);
    return BuiltRoute(
      RouteRecord(
        id: _newId(),
        name: '',
        createdAt: _now(),
        waypoints: List.of(waypoints),
        points: pontos,
        distanceM: perfil.distance,
        gainM: perfil.gain,
        lossM: perfil.loss,
      ),
      flat: flat,
    );
  }
}
```

<!-- file: app/lib/data/providers.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'rides_store.dart';
import 'route_builder.dart';
import 'routes_store.dart';
import 'services/elevation_service.dart';
import 'services/location_service.dart';
import 'services/routing_service.dart';
import 'settings_store.dart';

/// Aberto no main() e sobrescrito no ProviderScope.
final databaseProvider = Provider<Database>(
  (ref) => throw StateError('Abra o banco no main() e sobrescreva databaseProvider.'),
);

final settingsStoreProvider = Provider<SettingsStore>((ref) => SqliteSettingsStore(ref.watch(databaseProvider)));

final ridesStoreProvider = Provider<RidesStore>((ref) => SqliteRidesStore(ref.watch(databaseProvider)));

final routesStoreProvider = Provider<RoutesStore>((ref) => SqliteRoutesStore(ref.watch(databaseProvider)));

final settingsProvider = FutureProvider<AppSettings>((ref) => ref.watch(settingsStoreProvider).load());

final recentRidesProvider = FutureProvider<List<RideRecord>>((ref) => ref.watch(ridesStoreProvider).recent());

final rideByIdProvider = FutureProvider.family<RideRecord?, String>(
  (ref, id) => ref.watch(ridesStoreProvider).byId(id),
);

final routesProvider = FutureProvider<List<RouteRecord>>((ref) => ref.watch(routesStoreProvider).all());

final routeByIdProvider = FutureProvider.family<RouteRecord?, String>(
  (ref, id) => ref.watch(routesStoreProvider).byId(id),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final routeBuilderProvider = Provider<RouteBuilder>((ref) {
  final client = ref.watch(httpClientProvider);
  return RouteBuilder(routing: RoutingService(client), elevation: ElevationService(client));
});

final locationServiceProvider = Provider<LocationService>((ref) => const GeolocatorLocationService());
```

<!-- file: app/android/app/src/main/AndroidManifest.xml -->
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <!-- Localização: centralizar o mapa no bairro (e, no Android ≤ 11, a busca Bluetooth). -->
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

    <application
        android:label="Pedal Local"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/data test/core && flutter analyze lib/data lib/core`
Expected: `All tests passed!` e `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/data app/lib/core/format app/test/data app/test/core app/android/app/src/main/AndroidManifest.xml app/pubspec.yaml app/pubspec.lock && git commit -m "feat(app): rotas salvas, traçado pelas ruas, altimetria e localização"
```

---

### Task 3: Pedal genérico — livre e na rota

**Files:**
- Create: `app/lib/features/pedal/ride_controller.dart`
- Delete: `app/lib/features/pedal_livre/free_ride_controller.dart`, `app/test/features/free_ride_controller_test.dart`
- Test: `app/test/features/ride_controller_test.dart`

**Interfaces:**
- Consumes: `RideSession`, `FlatTerrain`, `RideAlert`, `AlertKind`, `RideState`; `RouteProfile`; `routesStoreProvider`, `RouteRecord`; tudo que o antigo `FreeRideController` usava.
- Produces: `clockProvider` (padrão `clock.now`, do pacote `clock`), `rideIdProvider`, `rideTickProvider`; `RideView` (campos do antigo `FreeRideView` + `notFound`, `routeName`, `total`, `grade`, `position` (`GeoPoint?`), `alert` (`RideAlert?`), `alertAt`, `profile` (`RouteProfile?`), `isRoute`); `RideController(String? routeId)` com `start()`, `onReading`, `tick`, `changeLevel`, `togglePause`, `Future<String> finish()` (idempotente); `rideProvider` = `NotifierProvider.autoDispose.family<RideController, RideView, String?>` (`null` = pedal livre).

- [ ] **Step 1: Teste que falha**

<!-- file: app/test/features/ride_controller_test.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/geo.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/features/pedal/ride_controller.dart';

import '../support/fakes.dart';
import '../support/geo_helpers.dart';

RouteRecord rotaDeTeste(String id, List<double> alts) {
  final pontos = northProfile(alts);
  return RouteRecord(
    id: id,
    name: 'Rua de teste',
    createdAt: DateTime(2026, 10, 8),
    waypoints: [pontos.first.geo, pontos.last.geo],
    points: pontos,
    distanceM: (alts.length - 1) * 20.0,
    gainM: 0,
    lossM: 0,
  );
}

void main() {
  late FakeBikeSource bike;
  late FakeWakeLock wake;
  late MemoryRidesStore rides;
  late MemoryRoutesStore routes;
  late ProviderContainer container;
  late DateTime agora;

  setUp(() async {
    bike = FakeBikeSource();
    wake = FakeWakeLock();
    rides = MemoryRidesStore();
    routes = MemoryRoutesStore();
    agora = DateTime(2026, 10, 8, 20);
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      routesStoreProvider.overrideWithValue(routes),
      wakeLockProvider.overrideWithValue(wake),
      clockProvider.overrideWithValue(() => agora),
      rideIdProvider.overrideWithValue(() => 'p1'),
      rideTickProvider.overrideWithValue(const Duration(hours: 1)),
      reconnectDelaysProvider.overrideWithValue(const [Duration(hours: 1)]),
    ]);
    addTearDown(container.dispose);
    await container.read(bikeControllerProvider.notifier).useSource(bike);
  });

  RideController ctrl(String? rota) {
    container.listen(rideProvider(rota), (anterior, proximo) {});
    return container.read(rideProvider(rota).notifier);
  }

  RideView view(String? rota) => container.read(rideProvider(rota));

  Future<void> pedalar(String? rota, int segundos, {int? power = 150, double cadence = 80}) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      bike.emitReading(BikeReading(cadence: cadence, power: power, timestamp: agora));
      await settle();
      ctrl(rota).tick();
    }
  }

  group('pedal livre', () {
    test('start liga a tela, salva o pedal e começa pedalando', () async {
      await ctrl(null).start();
      expect(wake.enabled, isTrue);
      expect(view(null).started, isTrue);
      expect(view(null).state, RideState.pedalando);
      expect(view(null).isRoute, isFalse);
      final salvo = await rides.byId('p1');
      expect(salvo!.completed, isFalse);
      expect(salvo.mode, RideMode.livre);
    });

    test('pedalando com 150 W ganha velocidade e grava o histórico de potência', () async {
      await ctrl(null).start();
      await pedalar(null, 10);
      expect(view(null).speedKmh, greaterThan(15));
      expect(view(null).distance, greaterThan(0));
      expect(view(null).power, 150);
      expect(view(null).powerHistory.length, 10);
    });

    test('sem leitura por mais de 3 s, a potência zera', () async {
      await ctrl(null).start();
      await pedalar(null, 5);
      for (var i = 0; i < 16; i++) {
        agora = agora.add(const Duration(milliseconds: 250));
        ctrl(null).tick();
      }
      expect(view(null).power, 0);
    });

    test('carga muda entre 1 e 10; pausar e continuar', () async {
      await ctrl(null).start();
      for (var i = 0; i < 20; i++) {
        ctrl(null).changeLevel(1);
      }
      expect(view(null).level, 10);
      ctrl(null).togglePause();
      expect(view(null).state, RideState.pausado);
      ctrl(null).togglePause();
      expect(view(null).state, RideState.pedalando);
    });

    test('queda da bike pausa; reconexão retoma', () async {
      await ctrl(null).start();
      await pedalar(null, 3);
      bike.emitConnection(BikeConnection.caiu);
      await settle();
      expect(view(null).pausedByBike, isTrue);
      expect(view(null).state, RideState.pausado);
      bike.emitConnection(BikeConnection.conectada);
      await settle();
      expect(view(null).state, RideState.pedalando);
    });

    test('finish salva concluído, desliga a tela e é idempotente', () async {
      await ctrl(null).start();
      await pedalar(null, 12);
      expect(await ctrl(null).finish(), 'p1');
      expect(await ctrl(null).finish(), 'p1');
      final salvo = await rides.byId('p1');
      expect(salvo!.completed, isTrue);
      expect(salvo.samples.length, greaterThanOrEqualTo(12));
      expect(wake.enabled, isFalse);
    });
  });

  group('pedal na rota', () {
    test('anda pela rota, mostra a posição e conclui no fim', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760))); // 100 m planos
      await ctrl('r').start();
      expect(view('r').isRoute, isTrue);
      expect(view('r').routeName, 'Rua de teste');
      expectNear(view('r').total, 100, 0.5);
      final inicio = view('r').position!;
      for (var s = 0; s < 120 && view('r').state != RideState.concluido; s++) {
        await pedalar('r', 1);
      }
      expect(view('r').state, RideState.concluido);
      expect(view('r').position!.lat, greaterThan(inicio.lat));
      await ctrl('r').finish();
      final salvo = (await rides.byId('p1'))!;
      expect(salvo.mode, RideMode.rota);
      expect(salvo.routeId, 'r');
      expect(salvo.completed, isTrue);
    });

    test('avisa a subida que vem pela frente', () async {
      await routes.upsert(rotaDeTeste('s', [for (var i = 0; i < 16; i++) 760 + i * 1.2])); // 6 %
      await ctrl('s').start();
      await pedalar('s', 2);
      expect(view('s').alert?.kind, AlertKind.subida);
      expect(view('s').alertAt, isNotNull);
      expect(view('s').grade, closeTo(0.06, 0.001));
    });

    test('rota que não existe', () async {
      await ctrl('nada').start();
      expect(view('nada').notFound, isTrue);
      expect(view('nada').started, isFalse);
      expect(wake.enabled, isFalse);
    });

    test('posição começa no primeiro ponto', () async {
      await routes.upsert(rotaDeTeste('r', List.filled(6, 760)));
      await ctrl('r').start();
      final p = view('r').position!;
      expect(p, isA<GeoPoint>());
      expectNear(p.lat, -23.5, 1e-9);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/features/ride_controller_test.dart`
Expected: FAIL — `features/pedal/ride_controller.dart` não existe.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/features/pedal/ride_controller.dart -->
```dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_source.dart';
import '../../core/wake_lock.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../domain/geo.dart';
import '../../domain/power.dart';
import '../../domain/ride_session.dart';
import '../../domain/route_profile.dart';

/// Relógio do pedal. `clock.now()` é o relógio real no app e o relógio simulado nos testes de tela.
final clockProvider = Provider<DateTime Function()>((ref) => () => clock.now());
final rideIdProvider = Provider<String Function()>(
  (ref) => () => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
);
final rideTickProvider = Provider<Duration>((ref) => const Duration(milliseconds: 250));

const _historyLength = 300; // 5 minutos de amostras
const _staleAfter = Duration(seconds: 3);
const _saveEverySeconds = 15.0;

class RideView {
  const RideView({
    this.started = false,
    this.notFound = false,
    this.state = RideState.pronto,
    this.speedKmh = 0,
    this.power = 0,
    this.cadence = 0,
    this.heartRate,
    this.distance = 0,
    this.total = double.infinity,
    this.grade = 0,
    this.movingTime = 0,
    this.kcal = 0,
    this.level = 4,
    this.estimating = false,
    this.pausedByBike = false,
    this.powerHistory = const [],
    this.routeName,
    this.position,
    this.alert,
    this.alertAt,
    this.profile,
  });

  final bool started;
  final bool notFound;
  final RideState state;
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
  final double distance;
  final double total;
  final double grade;
  final double movingTime;
  final double kcal;
  final int level;
  final bool estimating;
  final bool pausedByBike;
  final List<double> powerHistory;
  final String? routeName;
  final GeoPoint? position;
  final RideAlert? alert;
  final DateTime? alertAt;
  final RouteProfile? profile;

  bool get isRoute => profile != null;
}

/// Pedal livre (`routeId == null`) ou pedal numa rota salva.
class RideController extends Notifier<RideView> {
  RideController(this.routeId);

  final String? routeId;
  RideSession? _session;
  PowerResolver? _resolver;
  RouteProfile? _profile;
  String? _routeName;
  WakeLock? _wakeLock;
  Timer? _ticker;
  StreamSubscription<BikeReading>? _readingSub;
  StreamSubscription<BikeConnection>? _connectionSub;
  DateTime? _startedAt;
  DateTime? _lastTick;
  DateTime? _lastReading;
  String? _rideId;
  RideAlert? _alert;
  DateTime? _alertAt;
  double _sinceSave = 0;
  int _level = 4;
  int _seenSamples = 0;
  bool _pausedByBike = false;
  bool _starting = false;
  bool _finished = false;
  final List<double> _history = [];

  @override
  RideView build() {
    ref.onDispose(_stop);
    return const RideView();
  }

  Future<void> start() async {
    if (_session != null || _starting) return;
    _starting = true;
    final settings = await ref.read(settingsStoreProvider).load();
    if (!ref.mounted) return;
    final id = routeId;
    if (id != null) {
      final route = await ref.read(routesStoreProvider).byId(id);
      if (!ref.mounted) return;
      if (route == null) {
        state = const RideView(notFound: true);
        return;
      }
      _profile = RouteProfile(route.points);
      _routeName = route.name;
    }
    final relogio = ref.read(clockProvider);
    _session = RideSession(terrain: _profile ?? const FlatTerrain(), riderMassKg: settings.pesoKg)..start();
    _resolver = PowerResolver(
      mode: settings.modoPotencia,
      calibration: PowerCalibration(base: settings.base, factor: settings.fator),
    );
    _level = settings.cargaPadrao;
    _startedAt = relogio();
    _lastTick = _startedAt;
    _rideId = ref.read(rideIdProvider)();
    final source = ref.read(bikeControllerProvider).source;
    _readingSub = source?.readings.listen(onReading);
    _connectionSub = source?.connection.listen(_onConnection);
    _wakeLock = ref.read(wakeLockProvider);
    await _wakeLock!.enable();
    await _save(completed: false);
    if (!ref.mounted) return;
    _ticker = Timer.periodic(ref.read(rideTickProvider), (_) => tick());
    _publish();
  }

  @visibleForTesting
  void onReading(BikeReading r) {
    final session = _session;
    final resolver = _resolver;
    if (session == null || resolver == null || !ref.mounted) return;
    _lastReading = ref.read(clockProvider)();
    final watts = resolver.resolve(cadence: r.cadence, power: r.power, timestamp: r.timestamp, level: _level);
    session.setInputs(powerW: watts.toDouble(), cadence: r.cadence ?? 0, heartRate: r.heartRate?.toDouble());
  }

  void _onConnection(BikeConnection c) {
    final session = _session;
    if (session == null || !ref.mounted) return;
    final caiu = c == BikeConnection.caiu || c == BikeConnection.desconectada;
    if (caiu && session.state == RideState.pedalando) {
      session
        ..pause()
        ..setInputs(powerW: 0, cadence: 0);
      _pausedByBike = true;
      _publish();
    } else if (c == BikeConnection.conectada && _pausedByBike) {
      _pausedByBike = false;
      session.resume();
      _publish();
    }
  }

  @visibleForTesting
  void tick() {
    final session = _session;
    if (session == null || session.state == RideState.concluido || !ref.mounted) return;
    final now = ref.read(clockProvider)();
    final dt = (now.difference(_lastTick ?? now).inMicroseconds / 1e6).clamp(0.0, 1.0).toDouble();
    _lastTick = now;
    final last = _lastReading;
    if (last == null || now.difference(last) > _staleAfter) session.setInputs(powerW: 0, cadence: 0);
    final alerts = session.advance(dt);
    if (alerts.isNotEmpty) {
      _alert = alerts.last;
      _alertAt = now;
    }
    if (session.samples.length > _seenSamples) {
      _history.addAll(session.samples.skip(_seenSamples).map((s) => s.power));
      _seenSamples = session.samples.length;
      if (_history.length > _historyLength) _history.removeRange(0, _history.length - _historyLength);
    }
    _sinceSave += dt;
    if (_sinceSave >= _saveEverySeconds) {
      _sinceSave = 0;
      _save(completed: false);
    }
    _publish();
  }

  void changeLevel(int delta) {
    _level = (_level + delta).clamp(1, 10);
    _publish();
  }

  void togglePause() {
    final session = _session;
    if (session == null) return;
    if (session.state == RideState.pedalando) {
      session.pause();
    } else if (session.state == RideState.pausado) {
      _pausedByBike = false;
      session.resume();
    }
    _publish();
  }

  /// Encerra, salva como concluído e devolve o id do pedal. Chamar de novo só devolve o id.
  Future<String> finish() async {
    final session = _session!;
    if (_finished) return _rideId!;
    _finished = true;
    session.finish();
    _stop();
    await _save(completed: true);
    if (ref.mounted) {
      ref.invalidate(recentRidesProvider);
      _publish();
    }
    return _rideId!;
  }

  Future<void> _save({required bool completed}) async {
    final session = _session;
    final id = _rideId;
    final started = _startedAt;
    if (session == null || id == null || started == null) return;
    final snap = session.snapshot();
    await ref.read(ridesStoreProvider).upsert(RideRecord(
          id: id,
          routeId: routeId,
          mode: _profile != null ? RideMode.rota : RideMode.livre,
          startedAt: started,
          movingTimeS: snap.movingTime,
          distanceM: snap.distance,
          avgPowerW: snap.avgPower,
          avgSpeedKmh: snap.avgSpeedKmh,
          gainM: snap.climbed,
          kcal: snap.kcal,
          completed: completed,
          samples: List.of(session.samples),
        ));
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _readingSub?.cancel();
    _readingSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _wakeLock?.disable();
    _wakeLock = null;
  }

  void _publish() {
    final session = _session;
    if (session == null) return;
    final snap = session.snapshot();
    state = RideView(
      started: true,
      state: snap.state,
      speedKmh: snap.speedKmh,
      power: snap.power,
      cadence: snap.cadence,
      heartRate: snap.heartRate,
      distance: snap.distance,
      total: snap.total,
      grade: snap.grade,
      movingTime: snap.movingTime,
      kcal: snap.kcal,
      level: _level,
      estimating: _resolver?.effectiveMode == PowerMode.estimada,
      pausedByBike: _pausedByBike,
      powerHistory: List.unmodifiable(_history),
      routeName: _routeName,
      position: _profile?.positionAt(snap.distance),
      alert: _alert,
      alertAt: _alertAt,
      profile: _profile,
    );
  }
}

final rideProvider = NotifierProvider.autoDispose.family<RideController, RideView, String?>(RideController.new);
```

- [ ] **Step 4: Remover o controlador antigo e ajustar quem o usava**

```bash
cd /c/dev/pedal-local && git rm -q app/lib/features/pedal_livre/free_ride_controller.dart app/test/features/free_ride_controller_test.dart
```
A tela `pedal_livre_screen.dart` é reescrita na Task 4 (usa `rideProvider(null)`). Até lá ela não compila; por isso o teste desta task roda só o arquivo novo.

- [ ] **Step 5: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/features/ride_controller_test.dart`
Expected: `All tests passed!` (10 testes)

- [ ] **Step 6: Commit**

```bash
cd /c/dev/pedal-local && git add -A app/lib/features app/test/features && git commit -m "feat(app): controlador de pedal único para pedal livre e rota"
```

---

### Task 4: Componentes de mapa, relevo e pedal

**Files:**
- Create: `app/lib/core/widgets/app_map.dart`, `app/lib/core/widgets/elevation_chart.dart`, `app/lib/features/pedal/ride_widgets.dart`
- Modify: `app/lib/features/pedal_livre/pedal_livre_screen.dart` (substituir)

**Interfaces:**
- Consumes: `GeoPoint`, `RouteProfile`; `rideProvider`, `RideView`; `SimSource`; `bikeControllerProvider`.
- Produces: `mapTilesEnabledProvider` (`Provider<bool>`, `false` nos testes); `defaultMapCenter`; `LatLng toLatLng(GeoPoint)`; `GeoPoint toGeo(LatLng)`; `List<Widget> baseMapLayers(WidgetRef ref)`; `mapAttribution`; `ElevationChart({required RouteProfile profile, double? marker})`; `AvisoFaixa({texto, acao?, onAcao?, icone?})`; `RideControls({level, paused, enabled, onLevel, onPause})`; `SimControls({source})`.

- [ ] **Step 1: Implementar os componentes**

<!-- file: app/lib/core/widgets/app_map.dart -->
```dart
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
```

<!-- file: app/lib/core/widgets/elevation_chart.dart -->
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/route_profile.dart';
import '../theme/app_theme.dart';

/// Perfil de relevo da rota, com marcador opcional na distância percorrida.
class ElevationChart extends StatelessWidget {
  const ElevationChart({super.key, required this.profile, this.marker});

  final RouteProfile profile;
  final double? marker;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Perfil de relevo da rota',
      child: CustomPaint(painter: _ElevationPainter(profile, marker), child: const SizedBox.expand()),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.profile, this.marker);

  final RouteProfile profile;
  final double? marker;

  @override
  void paint(Canvas canvas, Size size) {
    final alts = profile.alts;
    final cum = profile.cum;
    final distance = profile.distance;
    if (alts.length < 2 || distance <= 0 || size.isEmpty) return;

    final altMin = alts.reduce(math.min);
    final altMax = alts.reduce(math.max);
    // Pelo menos 10 m de escala, para não exagerar ruas quase planas.
    final meio = (altMin + altMax) / 2;
    final minimo = math.min(altMin, meio - 5);
    final maximo = math.max(altMax, meio + 5);
    const topo = 6.0;
    final base = size.height - 16;
    double x(double d) => d / distance * size.width;
    double y(double a) => topo + (1 - (a - minimo) / (maximo - minimo)) * (base - topo);

    final linha = Path()..moveTo(x(cum[0]), y(alts[0]));
    for (var i = 1; i < alts.length; i++) {
      linha.lineTo(x(cum[i]), y(alts[i]));
    }
    final area = Path.from(linha)
      ..lineTo(size.width, base)
      ..lineTo(0, base)
      ..close();
    canvas.drawPath(area, Paint()..color = AppColors.destaque.withValues(alpha: 0.18));
    canvas.drawPath(
      linha,
      Paint()
        ..color = AppColors.destaque
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final rotulo = TextPainter(
      text: TextSpan(
        text: '${altMin.round()}–${altMax.round()} m',
        style: const TextStyle(fontSize: 11, color: AppColors.textoSuave),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rotulo.paint(canvas, Offset(2, size.height - rotulo.height));

    final m = marker;
    if (m != null) {
      final d = m.clamp(0, distance).toDouble();
      final mx = x(d);
      canvas.drawLine(Offset(mx, topo), Offset(mx, base), Paint()..color = AppColors.texto..strokeWidth = 1);
      canvas.drawCircle(Offset(mx, y(profile.elevationAt(d))), 6, Paint()..color = AppColors.posicao);
      canvas.drawCircle(
        Offset(mx, y(profile.elevationAt(d))),
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.profile != profile || old.marker != marker;
}
```

<!-- file: app/lib/features/pedal/ride_widgets.dart -->
```dart
import 'package:flutter/material.dart';

import '../../bike/sim_source.dart';
import '../../core/theme/app_theme.dart';

/// Faixa de aviso no topo do pedal (queda da bike, subida chegando, pausa).
class AvisoFaixa extends StatelessWidget {
  const AvisoFaixa({super.key, required this.texto, this.acao, this.onAcao, this.icone});

  final String texto;
  final String? acao;
  final VoidCallback? onAcao;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            if (icone != null) ...[
              Icon(icone, color: AppColors.avisoTexto),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(texto, style: const TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w700)),
            ),
            if (acao != null) TextButton(onPressed: onAcao, child: Text(acao!)),
          ],
        ),
      ),
    );
  }
}

/// Carga − / + e Pausar / Continuar.
class RideControls extends StatelessWidget {
  const RideControls({
    super.key,
    required this.level,
    required this.paused,
    required this.enabled,
    required this.onLevel,
    required this.onPause,
  });

  final int level;
  final bool paused;
  final bool enabled;
  final void Function(int delta) onLevel;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borda),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Diminuir carga',
                  onPressed: () => onLevel(-1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Carga $level', style: AppText.corpoForte),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Aumentar carga',
                  onPressed: () => onLevel(1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.escuro,
            minimumSize: const Size(104, 60),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: enabled ? onPause : null,
          child: Text(paused ? 'Continuar' : 'Pausar'),
        ),
      ],
    );
  }
}

/// Botões da bike simulada (só aparecem com ela).
class SimControls extends StatelessWidget {
  const SimControls({super.key, required this.source});

  final SimSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: source.easier,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Mais fraco', maxLines: 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: source.harder,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Mais forte', maxLines: 1),
            ),
          ),
        ],
      ),
    );
  }
}
```

<!-- file: app/lib/features/pedal_livre/pedal_livre_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/sim_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/power_chart.dart';
import '../../domain/ride_session.dart';
import '../pedal/ride_controller.dart';
import '../pedal/ride_widgets.dart';

class PedalLivreScreen extends ConsumerStatefulWidget {
  const PedalLivreScreen({super.key});

  @override
  ConsumerState<PedalLivreScreen> createState() => _PedalLivreScreenState();
}

class _PedalLivreScreenState extends ConsumerState<PedalLivreScreen> {
  bool _encerrando = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rideProvider(null).notifier).start());
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
    final ok = await confirmarEncerrar(context);
    if (!ok || !mounted) return;
    setState(() => _encerrando = true);
    final id = await ref.read(rideProvider(null).notifier).finish();
    if (!mounted) return;
    context.go('/resumo/$id');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(rideProvider(null));
    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(rideProvider(null).notifier);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _encerrar();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Pedal livre', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                    OutlinedButton(onPressed: _encerrar, child: const Text('Encerrar')),
                  ],
                ),
                const SizedBox(height: 12),
                if (v.pausedByBike)
                  AvisoFaixa(
                    texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                    acao: 'Reconectar',
                    onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                  )
                else if (v.state == RideState.pausado)
                  const AvisoFaixa(texto: 'Pedal pausado. Toque em Continuar para seguir.')
                else if (v.estimating)
                  const AvisoFaixa(texto: 'A bike não manda potência: estimando pela carga.'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      Text(
                        formatNumber(v.speedKmh, 1),
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: AppColors.destaque,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Text('km/h', style: AppText.suave),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: MetricTile(value: formatNumber(v.power), label: 'watts')),
                          Expanded(child: MetricTile(value: formatNumber(v.cadence), label: 'rpm')),
                          Expanded(child: MetricTile(value: formatTime(v.movingTime), label: 'tempo')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: MetricTile(value: formatNumber(v.distance / 1000, 2), label: 'km')),
                          Expanded(child: MetricTile(value: formatNumber(v.kcal), label: 'kcal')),
                          Expanded(
                            child: MetricTile(
                              value: v.heartRate == null ? '—' : formatNumber(v.heartRate!),
                              label: 'bpm',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Potência nos últimos minutos', style: AppText.suave),
                        const SizedBox(height: 8),
                        Expanded(child: PowerChart(values: v.powerHistory)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (source is SimSource) SimControls(source: source),
                RideControls(
                  level: v.level,
                  paused: v.state == RideState.pausado,
                  enabled: v.started,
                  onLevel: ctrl.changeLevel,
                  onPause: ctrl.togglePause,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pergunta se a pessoa quer mesmo encerrar o pedal.
Future<bool> confirmarEncerrar(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Encerrar o pedal?'),
      content: const Text('O pedal vai ser salvo no seu histórico.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continuar pedalando')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Encerrar')),
      ],
    ),
  );
  return ok == true;
}
```

- [ ] **Step 2: Verificar**

Run: `cd /c/dev/pedal-local/app && flutter analyze lib/core lib/features/pedal lib/features/pedal_livre`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/core/widgets app/lib/features/pedal app/lib/features/pedal_livre && git commit -m "feat(app): componentes de mapa, gráfico de relevo e controles do pedal"
```

---

### Task 5: Telas — Explorar, Criar rota, Pedalar na rota

**Files:**
- Create: `app/lib/features/explorar/route_tile.dart`, `app/lib/features/criar_rota/criar_rota_screen.dart`, `app/lib/features/pedal/pedal_rota_screen.dart`
- Modify (substituir): `app/lib/features/explorar/explorar_screen.dart`, `app/lib/features/escolher_pedal/escolher_pedal_sheet.dart`, `app/lib/features/inicio/inicio_screen.dart`, `app/lib/features/resumo/resumo_screen.dart`, `app/lib/core/router/app_router.dart`, `app/test/widget/app_test.dart`, `app/test/widget/fluxo_test.dart`
- Test: `app/test/widget/rota_test.dart`

**Interfaces:**
- Consumes: tudo das Tasks 1–4.
- Produces: rotas `/criar-rota` e `/pedal-rota/:id`; `RouteTile({route})`; `CriarRotaScreen`; `PedalRotaScreen({routeId})`.

- [ ] **Step 1: Testes de tela que falham**

<!-- file: app/test/widget/rota_test.dart -->
```dart
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/route_builder.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/elevation_service.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/services/routing_service.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/geo.dart';

import '../support/fakes.dart';
import '../support/geo_helpers.dart';

RouteRecord rotaDeTeste(String id, String nome, int pontos) {
  final perfil = northProfile(List.filled(pontos, 760));
  return RouteRecord(
    id: id,
    name: nome,
    createdAt: DateTime(2026, 10, 8),
    waypoints: [perfil.first.geo, perfil.last.geo],
    points: perfil,
    distanceM: (pontos - 1) * 20.0,
    gainM: 0,
    lossM: 0,
  );
}

/// Serviços falsos: OSRM devolve uma reta de 100 m; altimetria sobe 1 m a cada ponto.
MockClient servicosFalsos() => MockClient((req) async {
      if (req.url.host == 'routing.openstreetmap.de') {
        final linha = northLine(2, 100);
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    for (final p in linha) [p.lon, p.lat],
                  ],
                },
              },
            ],
          }),
          200,
        );
      }
      final k = req.url.queryParameters['latitude']!.split(',').length;
      return http.Response(jsonEncode({'elevation': [for (var i = 0; i < k; i++) 700 + i]}), 200);
    });

Future<ProviderContainer> abrirApp(WidgetTester tester, {required MemoryRoutesStore routes, MemoryRidesStore? rides}) async {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final client = servicosFalsos();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides ?? MemoryRidesStore()),
      routesStoreProvider.overrideWithValue(routes),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(GeoPoint(-23.5, -46.6))),
      routeBuilderProvider.overrideWithValue(
        RouteBuilder(routing: RoutingService(client), elevation: ElevationService(client)),
      ),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

void main() {
  testWidgets('Explorar mostra as rotas salvas', (tester) async {
    final routes = MemoryRoutesStore();
    await routes.upsert(rotaDeTeste('r1', 'Volta do bairro', 6));
    await abrirApp(tester, routes: routes);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    expect(find.text('Minhas rotas'), findsOneWidget);
    expect(find.text('Volta do bairro'), findsOneWidget);
    expect(find.text('Pedalar'), findsOneWidget);
  });

  testWidgets('criar rota: tocar pontos, calcular e salvar', (tester) async {
    final routes = MemoryRoutesStore();
    await abrirApp(tester, routes: routes);
    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar rota'));
    await tester.pumpAndSettle();
    expect(find.text('Toque no mapa para marcar o início.'), findsOneWidget);

    final mapa = tester.getRect(find.byKey(const Key('mapa-criar-rota')));
    await tester.tapAt(mapa.center.translate(-60, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(mapa.center.translate(60, -60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('2 pontos'), findsOneWidget);

    await tester.tap(find.text('Calcular rota'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar rota'), findsOneWidget);
    expect(find.textContaining('0,10 km'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Rua de casa');
    await tester.tap(find.text('Salvar rota'));
    await tester.pumpAndSettle();
    expect((await routes.all()).single.name, 'Rua de casa');
    expect(find.text('Rua de casa'), findsOneWidget);
  });

  testWidgets('pedalar uma rota até o fim leva ao resumo', (tester) async {
    final routes = MemoryRoutesStore();
    final rides = MemoryRidesStore();
    await routes.upsert(rotaDeTeste('r1', 'Rua curta', 7)); // 120 m
    final container = await abrirApp(tester, routes: routes, rides: rides);
    final bike = FakeBikeSource(name: 'FS-TESTE');
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedalar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rua curta'), findsOneWidget);

    for (var i = 0; i < 120 && find.text('Rota concluída!').evaluate().isEmpty; i++) {
      bike.emitReading(BikeReading(cadence: 85, power: 250, timestamp: clock.now()));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.text('Rota concluída!'), findsOneWidget);
    final pedal = (await rides.recent()).single;
    expect(pedal.mode, RideMode.rota);
    expect(pedal.routeId, 'r1');
    expect(pedal.completed, isTrue);
  });
}
```

<!-- file: app/test/widget/app_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';

Widget app(MemoryRidesStore rides) => ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        ridesStoreProvider.overrideWithValue(rides),
        routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
        mapTilesEnabledProvider.overrideWithValue(false),
        locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
      ],
      child: const PedalLocalApp(),
    );

void main() {
  testWidgets('abas e escolha do pedal', (tester) async {
    await tester.pumpWidget(app(MemoryRidesStore()));
    await tester.pumpAndSettle();
    expect(find.text('Bora pedalar?'), findsOneWidget);
    for (final aba in ['Início', 'Explorar', 'Treinos', 'Você']) {
      expect(find.text(aba), findsWidgets);
    }
    await tester.tap(find.byKey(const Key('botao-pedalar')));
    await tester.pumpAndSettle();
    expect(find.text('Como vai ser hoje?'), findsOneWidget);
    expect(find.text('Conectar a bike'), findsOneWidget);
  });

  testWidgets('aba Você mostra o histórico', (tester) async {
    final rides = MemoryRidesStore();
    await rides.upsert(RideRecord(
      id: 'a',
      mode: RideMode.livre,
      startedAt: DateTime(2026, 10, 7, 20, 4),
      movingTimeS: 1392,
      distanceM: 8400,
      avgPowerW: 161,
      avgSpeedKmh: 21.7,
      gainM: 0,
      kcal: 224,
      completed: true,
    ));
    await tester.pumpWidget(app(rides));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Você').last);
    await tester.pumpAndSettle();
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.textContaining('8,40 km'), findsOneWidget);
  });
}
```

<!-- file: app/test/widget/fluxo_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/core/widgets/app_map.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/routes_store.dart';
import 'package:pedal_local/data/services/location_service.dart';
import 'package:pedal_local/data/settings_store.dart';

import '../support/fakes.dart';

/// Celular pequeno (360 × 690 dp) para pegar textos e caixas que não cabem.
void celularPequeno(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2070);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> abrirApp(WidgetTester tester, MemoryRidesStore rides) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      routesStoreProvider.overrideWithValue(MemoryRoutesStore()),
      wakeLockProvider.overrideWithValue(FakeWakeLock()),
      mapTilesEnabledProvider.overrideWithValue(false),
      locationServiceProvider.overrideWithValue(const FixedLocationService(null)),
    ],
    child: const PedalLocalApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PedalLocalApp)));
}

void main() {
  testWidgets('todas as abas cabem num celular pequeno', (tester) async {
    celularPequeno(tester);
    await abrirApp(tester, MemoryRidesStore());
    for (final aba in ['Explorar', 'Treinos', 'Você', 'Início']) {
      await tester.tap(find.text(aba).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Bora pedalar?'), findsOneWidget);
  });

  testWidgets('pedal livre completo: pedalar, encerrar e ver o resumo', (tester) async {
    celularPequeno(tester);
    final rides = MemoryRidesStore();
    final container = await abrirApp(tester, rides);
    final bike = FakeBikeSource(name: 'FS-TESTE');
    await container.read(bikeControllerProvider.notifier).useSource(bike);
    await tester.pumpAndSettle();
    expect(find.text('FS-TESTE'), findsOneWidget);

    await tester.tap(find.text('Pedal livre').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Encerrar'), findsOneWidget);
    expect(find.text('Carga 4'), findsOneWidget);

    await tester.tap(find.byTooltip('Aumentar carga'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Carga 5'), findsOneWidget);

    await tester.tap(find.text('Pausar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.textContaining('Pedal pausado'), findsOneWidget);

    await tester.tap(find.text('Encerrar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Encerrar o pedal?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Pedal concluído!'), findsOneWidget);
    expect((await rides.recent()).single.completed, isTrue);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Último pedal'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/widget`
Expected: FAIL — telas e rotas novas não existem.

- [ ] **Step 3: Implementar Explorar e o cartão de rota**

<!-- file: app/lib/features/explorar/route_tile.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';

class RouteTile extends ConsumerWidget {
  const RouteTile({super.key, required this.route});

  final RouteRecord route;

  Future<void> _apagar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar a rota?'),
        content: Text('“${route.name}” some da sua lista. Os pedais já feitos continuam no histórico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(routesStoreProvider).delete(route.id);
    ref.invalidate(routesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(bikeControllerProvider.select((s) => s.connected));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.route, color: AppColors.destaqueTexto),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.name, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${formatKm(route.distanceM)} · ↑ ${formatNumber(route.gainM)} m', style: AppText.suave),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Apagar rota',
            onPressed: () => _apagar(context, ref),
            icon: const Icon(Icons.delete_outline, color: AppColors.textoSuave),
          ),
          FilledButton(
            onPressed: () => context.push(connected ? '/pedal-rota/${route.id}' : '/bike'),
            child: const Text('Pedalar'),
          ),
        ],
      ),
    );
  }
}
```

<!-- file: app/lib/features/explorar/explorar_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import 'route_tile.dart';

class ExplorarScreen extends ConsumerWidget {
  const ExplorarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Explorar', style: AppText.titulo)),
                FilledButton.icon(
                  onPressed: () => context.push('/criar-rota'),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar rota'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...routes.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (e, s) => [Text('Não consegui ler as rotas: $e', style: AppText.suave)],
              data: (lista) => lista.isEmpty
                  ? const [_SemRotas()]
                  : [
                      SizedBox(
                        height: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _MapaDasRotas(rotas: lista),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionTitle('Minhas rotas'),
                      for (final r in lista) ...[RouteTile(route: r), const SizedBox(height: 10)],
                    ],
            ),
            const SizedBox(height: 10),
            const EmBreveCard(
              icon: Icons.terrain_outlined,
              titulo: 'Subidas e desafios do bairro',
              texto: 'Ranking das ladeiras e desafio do mês.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SemRotas extends StatelessWidget {
  const _SemRotas();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.map_outlined, size: 48, color: AppColors.destaque),
          const SizedBox(height: 12),
          const Text('Nenhuma rota ainda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Marque um caminho no seu bairro tocando no mapa. O app traça pelas ruas e mostra as subidas.',
            textAlign: TextAlign.center,
            style: AppText.suave,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => context.push('/criar-rota'),
            child: const Text('Criar minha primeira rota'),
          ),
        ],
      ),
    );
  }
}

class _MapaDasRotas extends ConsumerWidget {
  const _MapaDasRotas({required this.rotas});

  final List<RouteRecord> rotas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = [
      for (final r in rotas)
        for (final p in r.points) LatLng(p.lat, p.lon),
    ];
    return FlutterMap(
      options: MapOptions(
        initialCenter: todos.isEmpty ? toLatLng(defaultMapCenter) : todos.first,
        initialZoom: 14,
        initialCameraFit: todos.length < 2
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(todos),
                padding: const EdgeInsets.all(28),
                maxZoom: 17,
              ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        ...baseMapLayers(ref),
        PolylineLayer(
          polylines: [
            for (final r in rotas)
              Polyline(
                points: [for (final p in r.points) LatLng(p.lat, p.lon)],
                strokeWidth: 5,
                color: AppColors.destaque,
              ),
          ],
        ),
        mapAttribution,
      ],
    );
  }
}
```

- [ ] **Step 4: Implementar Criar rota**

<!-- file: app/lib/features/criar_rota/criar_rota_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/elevation_chart.dart';
import '../../data/providers.dart';
import '../../data/routes_store.dart';
import '../../data/services/routing_service.dart';
import '../../domain/geo.dart';
import '../../domain/route_profile.dart';
import '../pedal/ride_widgets.dart';

class CriarRotaScreen extends ConsumerStatefulWidget {
  const CriarRotaScreen({super.key});

  @override
  ConsumerState<CriarRotaScreen> createState() => _CriarRotaScreenState();
}

class _CriarRotaScreenState extends ConsumerState<CriarRotaScreen> {
  final _map = MapController();
  final _nome = TextEditingController();
  final List<GeoPoint> _pontos = [];
  RouteRecord? _rota;
  RouteProfile? _perfil;
  bool _plana = false;
  bool _calculando = false;
  bool _mapaPronto = false;
  bool _semLocalizacao = false;
  GeoPoint? _centroPendente;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _localizar();
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _localizar() async {
    final aqui = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    if (aqui == null) {
      setState(() => _semLocalizacao = true);
      return;
    }
    setState(() => _semLocalizacao = false);
    if (_mapaPronto) {
      _map.move(toLatLng(aqui), 16);
    } else {
      _centroPendente = aqui;
    }
  }

  void _quandoMapaPronto() {
    _mapaPronto = true;
    final p = _centroPendente;
    if (p != null) _map.move(toLatLng(p), 16);
  }

  void _mudou(void Function() alteracao) {
    setState(() {
      alteracao();
      _rota = null;
      _perfil = null;
      _erro = null;
    });
  }

  void _tocar(LatLng p) => _mudou(() => _pontos.add(toGeo(p)));

  void _desfazer() => _mudou(_pontos.removeLast);

  void _fecharVolta() => _mudou(() => _pontos.add(_pontos.first));

  Future<void> _calcular() async {
    setState(() {
      _calculando = true;
      _erro = null;
    });
    try {
      final built = await ref.read(routeBuilderProvider).build(List.of(_pontos));
      if (!mounted) return;
      setState(() {
        _rota = built.route;
        _perfil = RouteProfile(built.route.points);
        _plana = built.flat;
      });
      final pts = [for (final p in built.route.points) LatLng(p.lat, p.lon)];
      if (pts.length >= 2) {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(40),
          maxZoom: 17,
        ));
      }
    } on RouteException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro ao calcular a rota: $e');
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  Future<void> _salvar() async {
    final rota = _rota;
    if (rota == null) return;
    final digitado = _nome.text.trim();
    final nome = digitado.isEmpty ? 'Rota de ${formatDate(DateTime.now())}' : digitado;
    await ref.read(routesStoreProvider).upsert(rota.copyWith(name: nome));
    ref.invalidate(routesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rota “$nome” salva')));
    context.pop();
  }

  String get _dica {
    if (_pontos.isEmpty) return 'Toque no mapa para marcar o início.';
    if (_pontos.length == 1) return 'Agora toque nos próximos pontos do caminho.';
    return '${_pontos.length} pontos. Quando terminar, toque em Calcular rota.';
  }

  @override
  Widget build(BuildContext context) {
    final rota = _rota;
    final perfil = _perfil;
    final podeFechar = _pontos.length >= 2 && _pontos.first != _pontos.last;
    return Scaffold(
      appBar: AppBar(title: const Text('Nova rota')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  key: const Key('mapa-criar-rota'),
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: toLatLng(defaultMapCenter),
                    initialZoom: 13,
                    onTap: (_, p) => _tocar(p),
                    onMapReady: _quandoMapaPronto,
                  ),
                  children: [
                    ...baseMapLayers(ref),
                    if (rota != null)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [for (final p in rota.points) LatLng(p.lat, p.lon)],
                          strokeWidth: 6,
                          color: AppColors.destaque,
                        ),
                      ])
                    else if (_pontos.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [for (final p in _pontos) toLatLng(p)],
                          strokeWidth: 3,
                          color: AppColors.destaque.withValues(alpha: 0.7),
                          pattern: const StrokePattern.dashed(segments: [10, 8]),
                        ),
                      ]),
                    CircleLayer(circles: [
                      for (var i = 0; i < _pontos.length; i++)
                        CircleMarker(
                          point: toLatLng(_pontos[i]),
                          radius: i == 0 ? 9 : 7,
                          color: i == 0 ? AppColors.destaque : Colors.white,
                          borderColor: AppColors.destaque,
                          borderStrokeWidth: 3,
                        ),
                    ]),
                    mapAttribution,
                  ],
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _Ferramenta(icone: Icons.undo, rotulo: 'Desfazer', onTap: _pontos.isEmpty ? null : _desfazer),
                      const SizedBox(height: 8),
                      _Ferramenta(icone: Icons.loop, rotulo: 'Fechar volta', onTap: podeFechar ? _fecharVolta : null),
                      const SizedBox(height: 8),
                      _Ferramenta(icone: Icons.my_location, rotulo: 'Onde estou', onTap: _localizar),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.superficie,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_erro != null) AvisoFaixa(texto: _erro!),
                    if (rota == null || perfil == null) ...[
                      Text(_dica, style: AppText.corpoForte),
                      if (_semLocalizacao)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Sem localização: arraste o mapa até o seu bairro.',
                            style: AppText.suave,
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _pontos.length >= 2 && !_calculando ? _calcular : null,
                        child: Text(_calculando ? 'Calculando…' : 'Calcular rota'),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(formatKm(rota.distanceM), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text(
                            '↑ ${formatNumber(rota.gainM)} m · ↓ ${formatNumber(rota.lossM)} m',
                            style: AppText.suave,
                          ),
                        ],
                      ),
                      if (_plana)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: AvisoFaixa(texto: 'Não consegui a altimetria: a rota ficou plana.'),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(height: 70, child: ElevationChart(profile: perfil)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nome,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Nome da rota', hintText: 'Volta do bairro'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(onPressed: _salvar, child: const Text('Salvar rota')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ferramenta extends StatelessWidget {
  const _Ferramenta({required this.icone, required this.rotulo, required this.onTap});

  final IconData icone;
  final String rotulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: AppColors.superficie,
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 72,
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: AppColors.texto),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(rotulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implementar Pedalar na rota**

<!-- file: app/lib/features/pedal/pedal_rota_screen.dart -->
```dart
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../bike/bike_controller.dart';
import '../../bike/sim_source.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/elevation_chart.dart';
import '../../domain/ride_session.dart';
import '../pedal_livre/pedal_livre_screen.dart';
import 'ride_controller.dart';
import 'ride_widgets.dart';

const _alertaVisivel = Duration(seconds: 8);

class PedalRotaScreen extends ConsumerStatefulWidget {
  const PedalRotaScreen({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<PedalRotaScreen> createState() => _PedalRotaScreenState();
}

class _PedalRotaScreenState extends ConsumerState<PedalRotaScreen> {
  final _map = MapController();
  bool _mapaPronto = false;
  bool _encerrando = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(rideProvider(widget.routeId).notifier).start());
  }

  Future<void> _finalizar() async {
    if (_encerrando) return;
    setState(() => _encerrando = true);
    final id = await ref.read(rideProvider(widget.routeId).notifier).finish();
    if (!mounted) return;
    context.go('/resumo/$id');
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
    if (await confirmarEncerrar(context)) await _finalizar();
  }

  @override
  Widget build(BuildContext context) {
    final provider = rideProvider(widget.routeId);
    final v = ref.watch(provider);
    ref.listen(provider, (anterior, proximo) {
      if (proximo.state == RideState.concluido && anterior?.state != RideState.concluido) _finalizar();
      final pos = proximo.position;
      if (pos != null && _mapaPronto) _map.move(toLatLng(pos), _map.camera.zoom);
    });

    if (v.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Essa rota não existe mais.', style: AppText.corpoForte)),
      );
    }

    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(provider.notifier);
    final perfil = v.profile;
    String? textoAlerta;
    final alerta = v.alert;
    final quando = v.alertAt;
    if (alerta != null && quando != null && clock.now().difference(quando) < _alertaVisivel) {
      textoAlerta = alerta.kind == AlertKind.subida
          ? 'Subida de ${formatNumber(alerta.grade * 100)}% chegando: aumente a carga'
          : 'Descida chegando: pode aliviar';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _encerrar();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.routeName ?? 'Rota',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            v.total.isFinite ? '${formatKm(v.distance)} de ${formatKm(v.total)}' : '',
                            style: AppText.suave,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(onPressed: _encerrar, child: const Text('Encerrar')),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: perfil == null
                        ? const Center(child: CircularProgressIndicator())
                        : FlutterMap(
                            mapController: _map,
                            options: MapOptions(
                              initialCenter: toLatLng(perfil.positionAt(0)),
                              initialZoom: 16,
                              onMapReady: () => _mapaPronto = true,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                              ),
                            ),
                            children: [
                              ...baseMapLayers(ref),
                              PolylineLayer(polylines: [
                                Polyline(
                                  points: [for (final p in perfil.points) toLatLng(p)],
                                  strokeWidth: 7,
                                  color: AppColors.destaque.withValues(alpha: 0.3),
                                ),
                                Polyline(
                                  points: [for (final p in perfil.traveled(v.distance)) toLatLng(p)],
                                  strokeWidth: 7,
                                  color: AppColors.destaque,
                                ),
                              ]),
                              if (v.position != null)
                                CircleLayer(circles: [
                                  CircleMarker(
                                    point: LatLng(v.position!.lat, v.position!.lon),
                                    radius: 10,
                                    color: AppColors.posicao,
                                    borderColor: Colors.white,
                                    borderStrokeWidth: 3,
                                  ),
                                ]),
                              mapAttribution,
                            ],
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (v.pausedByBike)
                      AvisoFaixa(
                        texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                        acao: 'Reconectar',
                        onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                      )
                    else if (textoAlerta != null)
                      AvisoFaixa(icone: Icons.terrain, texto: textoAlerta)
                    else if (v.state == RideState.pausado)
                      const AvisoFaixa(texto: 'Pedal pausado. Toque em Continuar para seguir.'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatNumber(v.speedKmh, 1),
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.destaque,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const Text('km/h', style: AppText.suave),
                              ],
                            ),
                          ),
                          MetricTile(value: '${formatNumber(v.grade * 100, 1)}%', label: 'inclinação'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(child: MetricTile(value: formatNumber(v.power), label: 'watts')),
                          Expanded(child: MetricTile(value: formatNumber(v.cadence), label: 'rpm')),
                          Expanded(child: MetricTile(value: formatTime(v.movingTime), label: 'tempo')),
                        ],
                      ),
                    ),
                    if (perfil != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(height: 70, child: ElevationChart(profile: perfil, marker: v.distance)),
                    ],
                    const SizedBox(height: 10),
                    if (source is SimSource) SimControls(source: source),
                    RideControls(
                      level: v.level,
                      paused: v.state == RideState.pausado,
                      enabled: v.started && !_encerrando,
                      onLevel: ctrl.changeLevel,
                      onPause: ctrl.togglePause,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Atualizar escolha do pedal, Início, Resumo e rotas do app**

<!-- file: app/lib/features/escolher_pedal/escolher_pedal_sheet.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

Future<void> showEscolherPedal(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const EscolherPedalSheet(),
    );

class EscolherPedalSheet extends ConsumerWidget {
  const EscolherPedalSheet({super.key});

  void _ir(BuildContext context, String destino, {bool trocarAba = false}) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (trocarAba) {
      router.go(destino);
    } else {
      router.push(destino);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Como vai ser hoje?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _Opcao(
              icon: Icons.route,
              titulo: 'Seguir uma rota',
              texto: 'Escolha a rota na aba Explorar',
              onTap: () => _ir(context, '/explorar', trocarAba: true),
            ),
            const _Opcao(
              icon: Icons.bar_chart_rounded,
              titulo: 'Pedal livre',
              texto: 'Só os dados da bike, sem mapa',
              selecionada: true,
            ),
            const _Opcao(icon: Icons.flag_outlined, titulo: 'Contra o fantasma', texto: 'Bata o seu recorde numa rota', emBreve: true),
            const _Opcao(icon: Icons.timer_outlined, titulo: 'Treino', texto: 'Intervalos e sessões guiadas', emBreve: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bike.connected ? AppColors.destaqueSuave : AppColors.avisoFundo,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth, size: 18, color: bike.connected ? AppColors.destaqueTexto : AppColors.avisoTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bike.connected ? '${bike.source!.name} conectada' : 'Nenhuma bike conectada',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: bike.connected ? AppColors.destaqueTexto : AppColors.avisoTexto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(bike.connected ? 'Começar pedal livre' : 'Conectar a bike'),
              onPressed: () => _ir(context, bike.connected ? '/pedal-livre' : '/bike'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icon,
    required this.titulo,
    required this.texto,
    this.selecionada = false,
    this.emBreve = false,
    this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String texto;
  final bool selecionada;
  final bool emBreve;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: emBreve ? 0.6 : 1,
        child: Material(
          color: selecionada ? const Color(0xFFF3FAF6) : AppColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selecionada ? AppColors.destaque : AppColors.borda,
              width: selecionada ? 2.5 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selecionada ? AppColors.destaque : AppColors.neutro,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: selecionada ? Colors.white : AppColors.texto),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(texto, style: AppText.suave),
                      ],
                    ),
                  ),
                  if (emBreve) const EmBreveTag(),
                  if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textoSuave),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

<!-- file: app/lib/features/inicio/inicio_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../bike/bike_chip.dart';
import '../pedal_livre/pedal_livre_card.dart';
import '../voce/ride_tile.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bike = ref.watch(bikeControllerProvider);
    final rides = ref.watch(recentRidesProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá!', style: AppText.subtitulo),
                      SizedBox(height: 2),
                      Text('Bora pedalar?', style: AppText.titulo),
                    ],
                  ),
                ),
                BikeChip(state: bike),
              ],
            ),
            const SizedBox(height: 16),
            if (!bike.connected) ...[
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth, color: AppColors.destaque),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Conecte sua bike para começar', style: AppText.corpoForte)),
                    FilledButton(onPressed: () => context.push('/bike'), child: const Text('Conectar')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const _RotaCard(),
            const SizedBox(height: 14),
            const PedalLivreCard(),
            const SizedBox(height: 14),
            ...rides.when(
              data: (lista) => lista.isEmpty
                  ? const <Widget>[]
                  : [const SectionTitle('Último pedal'), RideTile(ride: lista.first), const SizedBox(height: 14)],
              loading: () => const <Widget>[],
              error: (e, s) => const <Widget>[],
            ),
            const EmBreveCard(
              icon: Icons.emoji_events_outlined,
              titulo: 'Comunidade',
              texto: 'Ranking do bairro e desafio do mês.',
            ),
          ],
        ),
      ),
    );
  }
}

/// A rota mais recente com atalho para pedalar, ou o convite para criar a primeira.
class _RotaCard extends ConsumerWidget {
  const _RotaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    final connected = ref.watch(bikeControllerProvider.select((s) => s.connected));
    return routes.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (lista) {
        if (lista.isEmpty) {
          return AppCard(
            onTap: () => context.push('/criar-rota'),
            child: const Row(
              children: [
                Icon(Icons.map_outlined, color: AppColors.destaque, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crie sua primeira rota', style: AppText.corpoForte),
                      Text('Marque um caminho no seu bairro e pedale nele.', style: AppText.suave),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textoSuave),
              ],
            ),
          );
        }
        final r = lista.first;
        return AppCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.route, color: AppColors.destaqueTexto),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: AppText.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${formatKm(r.distanceM)} · ↑ ${formatNumber(r.gainM)} m', style: AppText.suave),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.push(connected ? '/pedal-rota/${r.id}' : '/bike'),
                child: const Text('Pedalar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

<!-- file: app/lib/features/resumo/resumo_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/power_chart.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';

class ResumoScreen extends ConsumerWidget {
  const ResumoScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideByIdProvider(rideId));
    return Scaffold(
      body: SafeArea(
        child: ride.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Não consegui abrir o pedal: $e')),
          data: (r) => r == null ? const Center(child: Text('Pedal não encontrado.')) : _Conteudo(ride: r),
        ),
      ),
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = ride.routeId;
    final nomeRota = routeId == null
        ? null
        : ref.watch(routeByIdProvider(routeId)).when(
              data: (r) => r?.name,
              loading: () => null,
              error: (e, s) => null,
            );
    final titulo = !ride.completed
        ? 'Pedal salvo'
        : ride.mode == RideMode.rota
            ? 'Rota concluída!'
            : 'Pedal concluído!';
    final subtitulo = [nomeRota ?? rideModeLabel(ride.mode), formatDateTime(ride.startedAt)].join(' · ');
    final potencias = ride.samples.map((s) => s.power).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.destaque, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppText.titulo.copyWith(fontSize: 24)),
                  Text(subtitulo, style: AppText.subtitulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: MetricTile(value: formatNumber(ride.distanceM / 1000, 2), label: 'km')),
                  Expanded(child: MetricTile(value: formatTime(ride.movingTimeS), label: 'tempo')),
                  Expanded(child: MetricTile(value: formatNumber(ride.avgSpeedKmh, 1), label: 'km/h média')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: MetricTile(value: formatNumber(ride.avgPowerW), label: 'watts média')),
                  Expanded(child: MetricTile(value: '${formatNumber(ride.gainM)} m', label: 'de subida')),
                  Expanded(child: MetricTile(value: formatNumber(ride.kcal), label: 'kcal')),
                ],
              ),
            ],
          ),
        ),
        if (potencias.length > 1) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Potência ao longo do pedal', style: AppText.suave),
                const SizedBox(height: 8),
                SizedBox(height: 120, child: PowerChart(values: potencias)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: OutlinedButton(onPressed: null, child: Text('Strava · em breve', maxLines: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(onPressed: () => context.go('/inicio'), child: const Text('Concluir')),
            ),
          ],
        ),
      ],
    );
  }
}
```

<!-- file: app/lib/core/router/app_router.dart -->
```dart
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
```

- [ ] **Step 7: Rodar tudo**

Run: `cd /c/dev/pedal-local/app && dart fix --apply && flutter analyze && flutter test`
Expected: `No issues found!` e `All tests passed!`

- [ ] **Step 8: Commit e envio**

```bash
cd /c/dev/pedal-local && git add -A app && git commit -m "feat(app): mapa no Explorar, criar rota tocando no mapa e pedalar nela" && git push origin main
```

---

### Task 6: No celular

- [ ] **Step 1: Compilar e instalar**

```bash
cd /c/dev/pedal-local/app && flutter build apk --debug && /c/dev/android-sdk/platform-tools/adb.exe -s RQ8R905CDWJ install -r build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 2: Roteiro (agente, com bike simulada)**

1. Explorar vazio mostra “Nenhuma rota ainda” e “Criar minha primeira rota”.
2. Criar rota: a caixa de localização do Android aparece → **“Não permitir”** (a decisão de verdade fica com o usuário); o aviso “Sem localização” aparece e o mapa fica em São Paulo.
3. Tocar 3–4 pontos em ruas → “Calcular rota” → linha verde pelas ruas, km, subida e gráfico de relevo → nome → “Salvar rota”.
4. Explorar mostra o mapa com a rota e o cartão com “Pedalar”.
5. Conectar a bike simulada → Pedalar a rota → bolinha anda, linha percorrida fica verde forte, inclinação muda, aviso de subida aparece nas subidas → ao chegar ao fim, “Rota concluída!”.
6. Limpar os dados de teste (`pm clear com.pedallocal.app`) para o usuário começar do zero.

---

## Notas da execução (2026-10-08)

- `StrokePattern.dashed` não pode ser `const` (o construtor confere o tamanho da lista): usado sem `const`.
- O `SimpleAttributionWidget` do flutter_map estourava 128 px em tela estreita: trocado por `MapAttribution` próprio e compacto (“© OpenStreetMap”).
- Linha de resultado do Criar rota estourava 28 px: subida/descida em `Expanded` alinhado à direita.
- Resultado: `flutter analyze` sem avisos, **107 testes passando**.
