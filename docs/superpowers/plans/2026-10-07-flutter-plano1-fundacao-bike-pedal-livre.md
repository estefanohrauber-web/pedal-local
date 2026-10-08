# Pedal Local Flutter — Plano 1: Fundação, Bike e Pedal Livre

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Android instalado no celular com as 5 abas no visual do Design 2, conexão FTMS com a bike (e bike simulada), pedal livre com física e potência, pedal salvo no histórico, resumo e ajustes.

**Architecture:** Flutter em `app/`. Camada `domain/` em Dart puro (tradução do protótipo web, testada sem Flutter). `bike/` encapsula o Bluetooth (`universal_ble`) atrás da interface `BikeSource`. `data/` guarda ajustes e pedais em SQLite (`sqflite`). Estado com Riverpod 3 (`Notifier`), navegação com go_router (`StatefulShellRoute` para as abas).

**Tech Stack:** Flutter 3.47.6 / Dart 3.13, flutter_riverpod 3.4, go_router 18, universal_ble 2.3, sqflite 2.4 (+ sqflite_common_ffi nos testes), wakelock_plus 1.8.0, google_fonts 9, intl 0.20, flutter_localizations.

Spec: `docs/superpowers/specs/2026-10-07-app-flutter-fase1-design.md`

## Global Constraints

- Código do app em `C:\dev\pedal-local\app` (caminho sem acento/espaço). Comandos `flutter` rodam dentro de `app/`.
- Antes de compilar para Android: `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\dev\tmp` (já é variável de usuário).
- Pacote Android `com.pedallocal.app`; nome exibido “Pedal Local”; textos da interface em português do Brasil.
- Tema claro do Design 2: fundo `#F4F6F5`, superfície `#FFFFFF`, borda `#E1E6E3`, texto `#14201A`, texto secundário `#5A6660`, destaque `#138A52`, destaque suave `#E3F4EA`/`#0E6B3F`, aviso `#FFF1E0`/`#8A3C00`; fonte Plus Jakarta Sans; alvos de toque ≥ 48 px.
- Física: passo 0,25 s; g 9,81; ρ 1,225; CdA 0,32; Crr 0,005; bike 10 kg; teto 25 m/s.
- Potência: `P = cadência × (base + fator × nível)`, base 0,6, fator 0,25, nível 1–10; auto troca para estimada após 10 s seguidos sem potência com cadência > 0.
- Bike: serviço FTMS `0x1826`, característica Indoor Bike Data `0x2AD2`; reconexão automática 3 vezes (2 s, 5 s, 10 s); sem leitura por 3 s ⇒ entradas zeradas.
- Pedal salvo no banco a cada 15 s; amostras de 1 s; calorias = energia (J) / 1000.
- `domain/` não importa Flutter nem pacotes de outras camadas.

## Ajustes em relação à spec (decididos ao planejar)

- `universal_ble` no lugar de `flutter_blue_plus` (licença); `sqflite` no lugar de `drift`; `wakelock_plus` 1.8.0; Google Fonts baixada na primeira abertura. Registrado na seção “Decisões tomadas ao planejar” da spec.
- Neste plano, Explorar mostra só “em breve”; rotas são o Plano 2. Início mostra bike, pedal livre, último pedal e cartões “em breve”; meta semanal e totais são o Plano 3.

## Estrutura de arquivos deste plano

```
app/lib/
  main.dart                         abre o banco, tema com Google Fonts, ProviderScope
  app.dart                          MaterialApp.router, pt-BR, reconecta a última bike
  core/theme/app_theme.dart         cores, estilos de texto, ThemeData, appThemeProvider
  core/format/format.dart           números, km, tempo e data em pt-BR
  core/router/app_router.dart       rotas e abas
  core/widgets/common.dart          AppCard, EmBreveTag, EmBreveCard, MetricTile, SectionTitle
  core/widgets/shell_scaffold.dart  barra de 5 abas com botão central
  core/widgets/power_chart.dart     gráfico de potência
  domain/physics.dart               stepSpeed
  domain/power.dart                 estimatePower, PowerResolver
  domain/ftms_parser.dart           parseIndoorBikeData, UUIDs FTMS
  domain/ride_session.dart          Terrain, RideSession, amostras, avisos
  domain/ride_samples.dart          packSamples / unpackSamples
  bike/bike_reading.dart            BikeReading
  bike/bike_source.dart             BikeSource, BikeConnection
  bike/sim_source.dart              bike simulada
  bike/ftms_source.dart             bike real via universal_ble
  bike/bike_scanner.dart            busca, permissões, classificação de aparelhos
  bike/bike_controller.dart         BikeController (Riverpod), reconexão
  data/db/app_database.dart         abre o SQLite e cria tabelas
  data/settings_store.dart          AppSettings, SettingsStore (SQLite e memória)
  data/rides_store.dart             RideRecord, RidesStore (SQLite e memória)
  data/providers.dart               providers do banco e dos stores
  features/inicio/inicio_screen.dart
  features/explorar/explorar_screen.dart
  features/treinos/treinos_screen.dart
  features/voce/voce_screen.dart
  features/voce/ajustes_screen.dart
  features/voce/ride_tile.dart
  features/bike/bike_chip.dart
  features/bike/conectar_bike_screen.dart
  features/escolher_pedal/escolher_pedal_sheet.dart
  features/pedal_livre/pedal_livre_card.dart
  features/pedal_livre/free_ride_controller.dart
  features/pedal_livre/pedal_livre_screen.dart
  features/resumo/resumo_screen.dart
app/test/
  support/fakes.dart
  domain/physics_test.dart  domain/power_test.dart  domain/ftms_parser_test.dart
  domain/ride_session_test.dart  domain/ride_samples_test.dart
  core/format_test.dart
  data/settings_store_test.dart  data/rides_store_test.dart
  bike/sim_source_test.dart  bike/bike_scanner_test.dart  bike/bike_controller_test.dart
  features/free_ride_controller_test.dart
  widget/app_test.dart
```

Cada bloco de código é precedido por `<!-- file: caminho -->` (caminho a partir da raiz do repositório).

---

### Task 1: Criar o app Flutter

**Files:**
- Create: `app/` (via `flutter create`), `app/android/app/src/main/AndroidManifest.xml` (substituir)
- Modify: `app/android/app/build.gradle.kts` (applicationId)
- Delete: `app/test/widget_test.dart`

**Interfaces:**
- Produces: pacote Dart `pedal_local` (imports `package:pedal_local/...`).

- [ ] **Step 1: Criar o projeto**

```bash
cd /c/dev/pedal-local && flutter create --org com.pedallocal --project-name pedal_local --platforms android app
```
Expected: `All done!`

- [ ] **Step 2: Adicionar dependências**

```bash
cd /c/dev/pedal-local/app && flutter pub add flutter_riverpod go_router universal_ble sqflite path "wakelock_plus:1.8.0" google_fonts intl && flutter pub add flutter_localizations --sdk=flutter && flutter pub add --dev sqflite_common_ffi
```
Expected: `Changed N dependencies!` sem erro de resolução.

- [ ] **Step 3: Pacote Android e permissões**

```bash
cd /c/dev/pedal-local/app && sed -i 's/applicationId = "com.pedallocal.pedal_local"/applicationId = "com.pedallocal.app"/' android/app/build.gradle.kts && grep -n applicationId android/app/build.gradle.kts && rm test/widget_test.dart
```
Expected: `applicationId = "com.pedallocal.app"`

<!-- file: app/android/app/src/main/AndroidManifest.xml -->
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
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

- [ ] **Step 4: Verificar que compila**

```bash
cd /c/dev/pedal-local/app && flutter analyze && flutter build apk --debug
```
Expected: `No issues found!` e `√ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app && git commit -m "feat(app): projeto Flutter com dependências e permissões Bluetooth"
```

---

### Task 2: Domínio — física e potência

**Files:**
- Create: `app/lib/domain/physics.dart`, `app/lib/domain/power.dart`
- Test: `app/test/domain/physics_test.dart`, `app/test/domain/power_test.dart`

**Interfaces:**
- Produces: `physicsDt = 0.25`; `physics` (`PhysicsConstants`, campo `maxSpeedMs`); `double stepSpeed(double speedMs, {required double powerW, required double grade, required double riderMassKg, double dt, PhysicsConstants c})`.
- Produces: `enum PowerMode { auto, bike, estimada }`; `PowerCalibration({double base = 0.6, double factor = 0.25})`; `int estimatePower(double? cadence, int level, [PowerCalibration])`; `PowerResolver({PowerMode mode, PowerCalibration calibration})` com `effectiveMode`, `switchedToEstimate`, `int resolve({required double? cadence, required int? power, required DateTime timestamp, required int level})`.

- [ ] **Step 1: Testes que falham**

<!-- file: app/test/domain/physics_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/physics.dart';

double kmh(double ms) => ms * 3.6;

double simulate(
  double v0, {
  required double powerW,
  required double grade,
  required double seconds,
  void Function(double v)? onStep,
}) {
  var v = v0;
  for (var t = 0.0; t < seconds; t += physicsDt) {
    v = stepSpeed(v, powerW: powerW, grade: grade, riderMassKg: 75);
    onStep?.call(v);
  }
  return v;
}

void main() {
  test('plano, 150 W: entre 28 e 32 km/h', () {
    expect(kmh(simulate(0, powerW: 150, grade: 0, seconds: 300)), inInclusiveRange(28, 32));
  });

  test('subida de 6 %, 150 W: entre 8 e 12 km/h', () {
    expect(kmh(simulate(0, powerW: 150, grade: 0.06, seconds: 300)), inInclusiveRange(8, 12));
  });

  test('descida de 5 % sem pedalar: passa de 30 km/h', () {
    expect(kmh(simulate(0, powerW: 0, grade: -0.05, seconds: 120)), greaterThan(30));
  });

  test('plano sem pedalar a partir de 30 km/h: abaixo de 12 km/h em 60 s', () {
    expect(kmh(simulate(30 / 3.6, powerW: 0, grade: 0, seconds: 60)), lessThan(12));
  });

  test('subida íngreme sem pedalar: para e nunca fica negativa', () {
    var menor = double.infinity;
    final v = simulate(5, powerW: 0, grade: 0.15, seconds: 10, onStep: (x) {
      if (x < menor) menor = x;
    });
    expect(v, 0);
    expect(menor, greaterThanOrEqualTo(0));
  });

  test('velocidade máxima limitada', () {
    expect(simulate(0, powerW: 0, grade: -0.2, seconds: 600), lessThanOrEqualTo(physics.maxSpeedMs));
  });
}
```

<!-- file: app/test/domain/power_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/power.dart';

final t0 = DateTime(2026, 10, 7, 20);
DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

void main() {
  test('estimatePower: nível 4 a 80 rpm ≈ 128 W', () {
    expect(estimatePower(80, 4), 128);
  });

  test('estimatePower: sem cadência = 0', () {
    expect(estimatePower(0, 4), 0);
    expect(estimatePower(null, 4), 0);
  });

  test('estimatePower: calibração personalizada', () {
    expect(estimatePower(80, 4, const PowerCalibration(base: 1, factor: 0)), 80);
  });

  test('modo bike: usa a potência recebida, 0 se não vier', () {
    final r = PowerResolver(mode: PowerMode.bike);
    expect(r.resolve(cadence: 80, power: 150, timestamp: at(0), level: 4), 150);
    expect(r.resolve(cadence: 80, power: null, timestamp: at(1000), level: 4), 0);
  });

  test('modo estimada: ignora a potência da bike', () {
    final r = PowerResolver(mode: PowerMode.estimada);
    expect(r.resolve(cadence: 80, power: 300, timestamp: at(0), level: 4), 128);
    expect(r.effectiveMode, PowerMode.estimada);
  });

  test('auto com potência válida: usa a da bike', () {
    final r = PowerResolver();
    expect(r.resolve(cadence: 80, power: 150, timestamp: at(0), level: 4), 150);
    expect(r.effectiveMode, PowerMode.bike);
  });

  test('auto sem potência por 10 s: troca para estimada de vez', () {
    final r = PowerResolver();
    for (var t = 0; t <= 9000; t += 1000) {
      expect(r.resolve(cadence: 80, power: null, timestamp: at(t), level: 4), 128);
    }
    expect(r.switchedToEstimate, isFalse);
    r.resolve(cadence: 80, power: 0, timestamp: at(10000), level: 4);
    expect(r.switchedToEstimate, isTrue);
    expect(r.effectiveMode, PowerMode.estimada);
    expect(r.resolve(cadence: 80, power: 300, timestamp: at(11000), level: 4), 128);
  });

  test('auto: parar de pedalar zera a contagem dos 10 s', () {
    final r = PowerResolver();
    for (var t = 0; t <= 5000; t += 1000) {
      r.resolve(cadence: 80, power: null, timestamp: at(t), level: 4);
    }
    expect(r.resolve(cadence: 0, power: null, timestamp: at(6000), level: 4), 0);
    for (var t = 7000; t <= 15000; t += 1000) {
      r.resolve(cadence: 80, power: null, timestamp: at(t), level: 4);
    }
    expect(r.switchedToEstimate, isFalse);
    r.resolve(cadence: 80, power: null, timestamp: at(17000), level: 4);
    expect(r.switchedToEstimate, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain`
Expected: FAIL — `Error: Couldn't resolve the package 'pedal_local/domain/physics.dart'` (ou "Target of URI doesn't exist").

- [ ] **Step 3: Implementar**

<!-- file: app/lib/domain/physics.dart -->
```dart
import 'dart:math' as math;

/// Constantes do modelo físico (as mesmas do protótipo web).
class PhysicsConstants {
  const PhysicsConstants({
    this.g = 9.81,
    this.rho = 1.225,
    this.cda = 0.32,
    this.crr = 0.005,
    this.bikeMassKg = 10,
    this.maxSpeedMs = 25,
  });

  final double g;
  final double rho; // densidade do ar (kg/m³)
  final double cda; // área frontal × coeficiente de arrasto (m²)
  final double crr; // resistência ao rolamento
  final double bikeMassKg;
  final double maxSpeedMs; // 90 km/h
}

const physics = PhysicsConstants();
const physicsDt = 0.25;

/// Nova velocidade (m/s) depois de [dt] segundos com [powerW] numa [grade] (fração).
double stepSpeed(
  double speedMs, {
  required double powerW,
  required double grade,
  required double riderMassKg,
  double dt = physicsDt,
  PhysicsConstants c = physics,
}) {
  final m = riderMassKg + c.bikeMassKg;
  final theta = math.atan(grade);
  final resist = m * c.g * (math.sin(theta) + c.crr * math.cos(theta)) +
      0.5 * c.rho * c.cda * speedMs * speedMs;
  final drive = powerW / math.max(speedMs, 1.0);
  final accel = (drive - resist) / m;
  return (speedMs + accel * dt).clamp(0.0, c.maxSpeedMs).toDouble();
}
```

<!-- file: app/lib/domain/power.dart -->
```dart
/// Potência usada na simulação: a da bike, ou estimada pela cadência e pela carga.
enum PowerMode { auto, bike, estimada }

class PowerCalibration {
  const PowerCalibration({this.base = 0.6, this.factor = 0.25});
  final double base;
  final double factor;
}

const fallbackAfter = Duration(seconds: 10);

int estimatePower(double? cadence, int level, [PowerCalibration calibration = const PowerCalibration()]) {
  if (cadence == null || cadence <= 0) return 0;
  return (cadence * (calibration.base + calibration.factor * level)).round();
}

class PowerResolver {
  PowerResolver({this.mode = PowerMode.auto, this.calibration = const PowerCalibration()})
      : _effective = mode == PowerMode.estimada ? PowerMode.estimada : PowerMode.bike;

  final PowerMode mode;
  final PowerCalibration calibration;
  PowerMode _effective;
  DateTime? _missingSince;
  bool _switched = false;

  PowerMode get effectiveMode => _effective;
  bool get switchedToEstimate => _switched;

  int resolve({
    required double? cadence,
    required int? power,
    required DateTime timestamp,
    required int level,
  }) {
    if (cadence == null || cadence <= 0) {
      _missingSince = null;
      return 0;
    }
    final hasPower = power != null && power > 0;
    if (mode == PowerMode.auto && _effective == PowerMode.bike) {
      if (hasPower) {
        _missingSince = null;
      } else if (_missingSince == null) {
        _missingSince = timestamp;
      } else if (timestamp.difference(_missingSince!) >= fallbackAfter) {
        _effective = PowerMode.estimada;
        _switched = true;
      }
    }
    if (_effective == PowerMode.estimada) return estimatePower(cadence, level, calibration);
    if (hasPower) return power!;
    return mode == PowerMode.auto ? estimatePower(cadence, level, calibration) : 0;
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain`
Expected: `All tests passed!` (14 testes)

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/domain app/test/domain && git commit -m "feat(app): física e potência estimada no domínio"
```

---

### Task 3: Domínio — leitura FTMS

**Files:**
- Create: `app/lib/domain/ftms_parser.dart`
- Test: `app/test/domain/ftms_parser_test.dart`

**Interfaces:**
- Produces: `const ftmsServiceUuid = '00001826-0000-1000-8000-00805f9b34fb'`; `const indoorBikeDataUuid = '00002ad2-0000-1000-8000-00805f9b34fb'`; `IndoorBikeData({double? speedKmh, double? cadence, int? power, int? heartRate})` com `==`; `IndoorBikeData parseIndoorBikeData(Uint8List bytes)`.

- [ ] **Step 1: Teste que falha**

<!-- file: app/test/domain/ftms_parser_test.dart -->
```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ftms_parser.dart';

Uint8List pkt(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  test('velocidade e cadência', () {
    // flags 0x0004: bit 0 = 0 (velocidade presente), bit 2 (cadência)
    expect(
      parseIndoorBikeData(pkt([0x04, 0x00, 0xc4, 0x09, 0xa0, 0x00])),
      const IndoorBikeData(speedKmh: 25, cadence: 80),
    );
  });

  test('velocidade, cadência e potência', () {
    expect(
      parseIndoorBikeData(pkt([0x44, 0x00, 0xc4, 0x09, 0xa0, 0x00, 0x96, 0x00])),
      const IndoorBikeData(speedKmh: 25, cadence: 80, power: 150),
    );
  });

  test('pula os campos opcionais antes da potência', () {
    // flags 0x007E: vel. média, cadência, cad. média, distância, resistência, potência
    final r = parseIndoorBikeData(pkt([
      0x7e, 0x00,
      0xc4, 0x09, // velocidade 25,00 km/h
      0x10, 0x27, // velocidade média (ignorada)
      0xb4, 0x00, // cadência 90 rpm
      0x00, 0x00, // cadência média
      0x10, 0x27, 0x00, // distância
      0x05, 0x00, // resistência
      0xc8, 0x00, // potência 200 W
    ]));
    expect(r, const IndoorBikeData(speedKmh: 25, cadence: 90, power: 200));
  });

  test('bit 0 ligado: sem velocidade', () {
    expect(
      parseIndoorBikeData(pkt([0x45, 0x00, 0xa0, 0x00, 0x96, 0x00])),
      const IndoorBikeData(cadence: 80, power: 150),
    );
  });

  test('potência negativa (sint16)', () {
    expect(parseIndoorBikeData(pkt([0x45, 0x00, 0xa0, 0x00, 0xf6, 0xff])).power, -10);
  });

  test('frequência cardíaca depois da energia', () {
    // flags 0x0304: velocidade, cadência, energia (5 bytes), FC
    final r = parseIndoorBikeData(pkt([0x04, 0x03, 0xc4, 0x09, 0xa0, 0x00, 1, 0, 2, 0, 3, 142]));
    expect(r.cadence, 80);
    expect(r.heartRate, 142);
  });

  test('pacote cortado não quebra', () {
    expect(
      parseIndoorBikeData(pkt([0x44, 0x00, 0xc4, 0x09, 0xa0])),
      const IndoorBikeData(speedKmh: 25),
    );
  });

  test('pacote vazio', () {
    expect(parseIndoorBikeData(pkt([])), const IndoorBikeData());
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain/ftms_parser_test.dart`
Expected: FAIL — arquivo `ftms_parser.dart` não existe.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/domain/ftms_parser.dart -->
```dart
import 'dart:typed_data';

/// Serviço Fitness Machine (FTMS) e característica Indoor Bike Data, em UUID de 128 bits.
const ftmsServiceUuid = '00001826-0000-1000-8000-00805f9b34fb';
const indoorBikeDataUuid = '00002ad2-0000-1000-8000-00805f9b34fb';

class IndoorBikeData {
  const IndoorBikeData({this.speedKmh, this.cadence, this.power, this.heartRate});

  final double? speedKmh;
  final double? cadence;
  final int? power;
  final int? heartRate;

  @override
  bool operator ==(Object other) =>
      other is IndoorBikeData &&
      other.speedKmh == speedKmh &&
      other.cadence == cadence &&
      other.power == power &&
      other.heartRate == heartRate;

  @override
  int get hashCode => Object.hash(speedKmh, cadence, power, heartRate);

  @override
  String toString() => 'IndoorBikeData(speed: $speedKmh, cadence: $cadence, power: $power, hr: $heartRate)';
}

/// Decodifica Indoor Bike Data (0x2AD2). Os campos vêm na ordem da especificação e cada
/// flag diz se o campo está presente. O bit 0 é invertido: 0 = velocidade presente.
IndoorBikeData parseIndoorBikeData(Uint8List bytes) {
  if (bytes.length < 2) return const IndoorBikeData();
  final view = ByteData.sublistView(bytes);
  final flags = view.getUint16(0, Endian.little);
  bool has(int bit) => (flags & (1 << bit)) != 0;

  double? speed;
  double? cadence;
  int? power;
  int? heartRate;

  // (presente, tamanho em bytes, leitura — null = só pular)
  final fields = <(bool, int, void Function(int)?)>[
    (!has(0), 2, (at) => speed = view.getUint16(at, Endian.little) / 100),
    (has(1), 2, null), // velocidade média
    (has(2), 2, (at) => cadence = view.getUint16(at, Endian.little) / 2),
    (has(3), 2, null), // cadência média
    (has(4), 3, null), // distância total
    (has(5), 2, null), // nível de resistência
    (has(6), 2, (at) => power = view.getInt16(at, Endian.little)),
    (has(7), 2, null), // potência média
    (has(8), 5, null), // energia: total, por hora, por minuto
    (has(9), 1, (at) => heartRate = view.getUint8(at)),
  ];

  var offset = 2;
  for (final (present, size, read) in fields) {
    if (!present) continue;
    if (offset + size > bytes.length) break;
    read?.call(offset);
    offset += size;
  }
  return IndoorBikeData(speedKmh: speed, cadence: cadence, power: power, heartRate: heartRate);
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain/ftms_parser_test.dart`
Expected: `All tests passed!` (8 testes)

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/domain/ftms_parser.dart app/test/domain/ftms_parser_test.dart && git commit -m "feat(app): leitura do Indoor Bike Data (FTMS)"
```

---

### Task 4: Domínio — sessão de pedal e amostras

**Files:**
- Create: `app/lib/domain/ride_session.dart`, `app/lib/domain/ride_samples.dart`
- Test: `app/test/domain/ride_session_test.dart`, `app/test/domain/ride_samples_test.dart`

**Interfaces:**
- Consumes: `stepSpeed`, `physicsDt` (Task 2).
- Produces: `abstract interface class Terrain { double get distance; double gradeAt(double distance); double lookahead(double distance, double span); }`; `FlatTerrain` (distância infinita, plano); `enum RideState { pronto, pedalando, pausado, concluido }`; `enum AlertKind { subida, descida }`; `RideAlert(kind, grade)`; `RideSample({t, distance, speedKmh, power, cadence, heartRate?})`; `RideSnapshot` com `state, distance, total, speedKmh, power, cadence, heartRate, grade, movingTime, avgPower, avgSpeedKmh, kcal, climbed`; `RideSession({required Terrain terrain, required double riderMassKg})` com `state`, `samples`, `start()`, `pause()`, `resume()`, `finish()`, `setInputs({required double powerW, required double cadence, double? heartRate})`, `List<RideAlert> advance(double seconds)`, `RideSnapshot snapshot()`.
- Produces: `Uint8List packSamples(List<RideSample>)`, `List<RideSample> unpackSamples(Uint8List)`.

- [ ] **Step 1: Testes que falham**

<!-- file: app/test/domain/ride_session_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ride_session.dart';

double _zero(double _) => 0;

class FakeTerrain implements Terrain {
  FakeTerrain({this.distance = 5000, this.grade = _zero, this.ahead = _zero});

  @override
  final double distance;
  final double Function(double) grade;
  final double Function(double) ahead;

  @override
  double gradeAt(double distance) => grade(distance);

  @override
  double lookahead(double distance, double span) => ahead(distance);
}

List<RideAlert> pedal(RideSession ride, int seconds) {
  final alerts = <RideAlert>[];
  for (var i = 0; i < seconds; i++) {
    alerts.addAll(ride.advance(1));
  }
  return alerts;
}

RideSession nova({Terrain? terrain}) =>
    RideSession(terrain: terrain ?? FakeTerrain(), riderMassKg: 75)..start();

void main() {
  test('antes de começar não anda', () {
    final ride = RideSession(terrain: FakeTerrain(), riderMassKg: 75);
    ride.setInputs(powerW: 200, cadence: 85);
    ride.advance(10);
    expect(ride.state, RideState.pronto);
    expect(ride.snapshot().distance, 0);
  });

  test('pedalando no plano avança e ganha velocidade', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 60);
    final s = ride.snapshot();
    expect(s.state, RideState.pedalando);
    expect(s.distance, greaterThan(300));
    expect(s.speedKmh, greaterThan(20));
    expect(s.cadence, 80);
  });

  test('chega ao fim e conclui', () {
    final ride = nova(terrain: FakeTerrain(distance: 100))..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 120);
    expect(ride.state, RideState.concluido);
    expect(ride.snapshot().distance, 100);
  });

  test('pausar zera a velocidade e congela a distância', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 30);
    ride.pause();
    final d = ride.snapshot().distance;
    pedal(ride, 10);
    expect(ride.state, RideState.pausado);
    expect(ride.snapshot().distance, d);
    expect(ride.snapshot().speedKmh, 0);
    ride.resume();
    pedal(ride, 5);
    expect(ride.snapshot().distance, greaterThan(d));
  });

  test('aviso de subida só repete depois de passar o trecho', () {
    double ahead(double d) => d < 300 ? 0.06 : (d < 600 ? 0 : 0.06);
    final ride = nova(terrain: FakeTerrain(distance: 2000, ahead: ahead))..setInputs(powerW: 200, cadence: 85);
    final alerts = pedal(ride, 400);
    expect(alerts.map((a) => a.kind), [AlertKind.subida, AlertKind.subida]);
    expect(alerts.first.grade, 0.06);
  });

  test('aviso de descida', () {
    final ride = nova(terrain: FakeTerrain(ahead: (_) => -0.05))..setInputs(powerW: 100, cadence: 70);
    expect(pedal(ride, 30).map((a) => a.kind), [AlertKind.descida]);
  });

  test('médias e calorias', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80);
    pedal(ride, 60);
    final s = ride.snapshot();
    expect(s.avgPower, closeTo(150, 1e-9));
    expect(s.kcal, closeTo(9, 1e-9)); // 150 W × 60 s = 9000 J
    expect(s.avgSpeedKmh, greaterThan(15));
    expect(s.avgSpeedKmh, lessThan(s.speedKmh));
  });

  test('grava uma amostra por segundo, com frequência cardíaca', () {
    final ride = nova()..setInputs(powerW: 150, cadence: 80, heartRate: 120);
    pedal(ride, 10);
    expect(ride.samples.length, 10);
    expect(ride.samples.last.t, closeTo(10, 1e-9));
    expect(ride.samples.last.heartRate, 120);
    expect(ride.samples.last.power, 150);
  });

  test('terreno plano nunca conclui sozinho; finish() encerra', () {
    final ride = RideSession(terrain: const FlatTerrain(), riderMassKg: 75)
      ..start()
      ..setInputs(powerW: 200, cadence: 85);
    pedal(ride, 600);
    expect(ride.state, RideState.pedalando);
    ride.finish();
    final d = ride.snapshot().distance;
    pedal(ride, 10);
    expect(ride.state, RideState.concluido);
    expect(ride.snapshot().distance, d);
  });

  test('acumula a subida feita', () {
    final ride = nova(terrain: FakeTerrain(distance: 1000, grade: (_) => 0.05))..setInputs(powerW: 250, cadence: 85);
    pedal(ride, 1200);
    expect(ride.state, RideState.concluido);
    expect(ride.snapshot().climbed, closeTo(50, 0.5));
  });
}
```

<!-- file: app/test/domain/ride_samples_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/domain/ride_samples.dart';
import 'package:pedal_local/domain/ride_session.dart';

void main() {
  test('compacta e descompacta mantendo os valores', () {
    final original = [
      const RideSample(t: 1, distance: 6.5, speedKmh: 23.4, power: 150, cadence: 80, heartRate: 121),
      const RideSample(t: 2, distance: 13.1, speedKmh: 23.9, power: 155, cadence: 81),
    ];
    final back = unpackSamples(packSamples(original));
    expect(back.length, 2);
    expect(back[0].t, 1);
    expect(back[0].distance, closeTo(6.5, 1e-4));
    expect(back[0].speedKmh, closeTo(23.4, 1e-4));
    expect(back[0].heartRate, 121);
    expect(back[1].power, 155);
    expect(back[1].heartRate, isNull);
  });

  test('lista vazia', () {
    expect(unpackSamples(packSamples(const [])), isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain`
Expected: FAIL — `ride_session.dart` e `ride_samples.dart` não existem.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/domain/ride_session.dart -->
```dart
import 'dart:math' as math;

import 'physics.dart';

/// Terreno sob a sessão: inclinação em função da distância percorrida.
abstract interface class Terrain {
  /// Comprimento em metros; `double.infinity` = sem fim (pedal livre).
  double get distance;
  double gradeAt(double distance);
  double lookahead(double distance, double span);
}

/// Pedal livre: plano e sem fim.
class FlatTerrain implements Terrain {
  const FlatTerrain();

  @override
  double get distance => double.infinity;

  @override
  double gradeAt(double distance) => 0;

  @override
  double lookahead(double distance, double span) => 0;
}

enum RideState { pronto, pedalando, pausado, concluido }

enum AlertKind { subida, descida }

class RideAlert {
  const RideAlert(this.kind, this.grade);
  final AlertKind kind;
  final double grade;
}

class RideSample {
  const RideSample({
    required this.t,
    required this.distance,
    required this.speedKmh,
    required this.power,
    required this.cadence,
    this.heartRate,
  });

  final double t; // tempo em movimento (s)
  final double distance; // m
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
}

class RideSnapshot {
  const RideSnapshot({
    required this.state,
    required this.distance,
    required this.total,
    required this.speedKmh,
    required this.power,
    required this.cadence,
    required this.heartRate,
    required this.grade,
    required this.movingTime,
    required this.avgPower,
    required this.avgSpeedKmh,
    required this.kcal,
    required this.climbed,
  });

  final RideState state;
  final double distance;
  final double total;
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
  final double grade;
  final double movingTime;
  final double avgPower;
  final double avgSpeedKmh;
  final double kcal;
  final double climbed;
}

const alertLookaheadM = 200.0;
const climbAlertGrade = 0.04;
const descentAlertGrade = -0.03;

/// Sessão de pedal. Estados: pronto → pedalando ⇄ pausado → concluido.
class RideSession {
  RideSession({required this.terrain, required this.riderMassKg});

  final Terrain terrain;
  final double riderMassKg;
  final List<RideSample> samples = [];

  RideState _state = RideState.pronto;
  double _speed = 0;
  double _distance = 0;
  double _movingTime = 0;
  double _energyJ = 0;
  double _climbed = 0;
  double _sinceSample = 0;
  double _power = 0;
  double _cadence = 0;
  double? _heartRate;
  // Um aviso só volta depois que o trecho à frente deixa de ser subida/descida.
  bool _armClimb = true;
  bool _armDescent = true;

  RideState get state => _state;

  void start() {
    if (_state == RideState.pronto) _state = RideState.pedalando;
  }

  void pause() {
    if (_state == RideState.pedalando) {
      _state = RideState.pausado;
      _speed = 0;
    }
  }

  void resume() {
    if (_state == RideState.pausado) _state = RideState.pedalando;
  }

  void finish() {
    _state = RideState.concluido;
    _speed = 0;
  }

  void setInputs({required double powerW, required double cadence, double? heartRate}) {
    _power = math.max(0.0, powerW);
    _cadence = cadence;
    _heartRate = heartRate;
  }

  List<RideAlert> advance(double seconds) {
    final alerts = <RideAlert>[];
    var remaining = seconds;
    while (_state == RideState.pedalando && remaining > 1e-9) {
      final dt = math.min(physicsDt, remaining);
      remaining -= dt;
      final grade = terrain.gradeAt(_distance);
      _speed = stepSpeed(_speed, powerW: _power, grade: grade, riderMassKg: riderMassKg, dt: dt);
      final step = _speed * dt;
      _distance += step;
      if (grade > 0) _climbed += grade * step;
      if (_speed > 0 || _power > 0) {
        _movingTime += dt;
        _energyJ += _power * dt;
        _sinceSample += dt;
        if (_sinceSample >= 1 - 1e-9) {
          _sinceSample -= 1;
          samples.add(_sample());
        }
      }
      if (_distance >= terrain.distance) {
        _distance = terrain.distance;
        _state = RideState.concluido;
        samples.add(_sample());
        break;
      }
      final alert = _checkAlert();
      if (alert != null) alerts.add(alert);
    }
    return alerts;
  }

  RideSnapshot snapshot() => RideSnapshot(
        state: _state,
        distance: _distance,
        total: terrain.distance,
        speedKmh: _speed * 3.6,
        power: _power,
        cadence: _cadence,
        heartRate: _heartRate,
        grade: terrain.gradeAt(_distance),
        movingTime: _movingTime,
        avgPower: _movingTime > 0 ? _energyJ / _movingTime : 0,
        avgSpeedKmh: _movingTime > 0 ? _distance / _movingTime * 3.6 : 0,
        kcal: _energyJ / 1000,
        climbed: _climbed,
      );

  RideSample _sample() => RideSample(
        t: _movingTime,
        distance: _distance,
        speedKmh: _speed * 3.6,
        power: _power,
        cadence: _cadence,
        heartRate: _heartRate,
      );

  RideAlert? _checkAlert() {
    final g = terrain.lookahead(_distance, alertLookaheadM);
    if (g < climbAlertGrade / 2) _armClimb = true;
    if (g > descentAlertGrade / 2) _armDescent = true;
    if (_armClimb && g >= climbAlertGrade) {
      _armClimb = false;
      return RideAlert(AlertKind.subida, g);
    }
    if (_armDescent && g <= descentAlertGrade) {
      _armDescent = false;
      return RideAlert(AlertKind.descida, g);
    }
    return null;
  }
}
```

<!-- file: app/lib/domain/ride_samples.dart -->
```dart
import 'dart:typed_data';

import 'ride_session.dart';

const _fields = 6; // t, distância, velocidade, potência, cadência, FC

/// Amostras em float32 compactados, para guardar no banco.
Uint8List packSamples(List<RideSample> samples) {
  final data = Float32List(samples.length * _fields);
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i];
    final o = i * _fields;
    data[o] = s.t;
    data[o + 1] = s.distance;
    data[o + 2] = s.speedKmh;
    data[o + 3] = s.power;
    data[o + 4] = s.cadence;
    data[o + 5] = s.heartRate ?? double.nan;
  }
  return data.buffer.asUint8List();
}

List<RideSample> unpackSamples(Uint8List bytes) {
  final copy = Uint8List.fromList(bytes); // garante alinhamento de 4 bytes
  final data = copy.buffer.asFloat32List(0, copy.lengthInBytes ~/ 4);
  return [
    for (var o = 0; o + _fields <= data.length; o += _fields)
      RideSample(
        t: data[o],
        distance: data[o + 1],
        speedKmh: data[o + 2],
        power: data[o + 3],
        cadence: data[o + 4],
        heartRate: data[o + 5].isNaN ? null : data[o + 5],
      ),
  ];
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/domain`
Expected: `All tests passed!` (34 testes no total de `test/domain`)

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/domain app/test/domain && git commit -m "feat(app): sessão de pedal com amostras de 1 s"
```

---

### Task 5: Formatação e tema

**Files:**
- Create: `app/lib/core/format/format.dart`, `app/lib/core/theme/app_theme.dart`, `app/lib/core/widgets/common.dart`, `app/lib/core/widgets/power_chart.dart`
- Test: `app/test/core/format_test.dart`

**Interfaces:**
- Produces: `String formatNumber(double n, [int casas = 0])`, `String formatKm(double metros, [int casas = 2])`, `String formatTime(double segundos)`, `String formatDateTime(DateTime d)`.
- Produces: `AppColors` (constantes `fundo, superficie, borda, texto, textoSuave, destaque, destaqueSuave, destaqueTexto, posicao, avisoFundo, avisoTexto, escuro, neutro`), `AppText` (`titulo, subtitulo, secao, corpoForte, suave`), `ThemeData buildAppTheme({TextTheme? textTheme})`, `appThemeProvider` (`Provider<ThemeData>`).
- Produces: widgets `AppCard({child, padding, onTap, color})`, `EmBreveTag()`, `EmBreveCard({icon, titulo, texto})`, `MetricTile({value, label})`, `SectionTitle(text)`, `PowerChart({values, color})`.

- [ ] **Step 1: Teste que falha**

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

  test('formatDateTime', () {
    expect(formatDateTime(DateTime(2026, 10, 7, 9, 5)), '07/10 às 09:05');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/core`
Expected: FAIL — `format.dart` não existe.

- [ ] **Step 3: Implementar**

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

String formatDateTime(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)} às ${dois(d.hour)}:${dois(d.minute)}';
}
```

<!-- file: app/lib/core/theme/app_theme.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cores do Design 2 (claro e amigável).
abstract final class AppColors {
  static const fundo = Color(0xFFF4F6F5);
  static const superficie = Color(0xFFFFFFFF);
  static const borda = Color(0xFFE1E6E3);
  static const texto = Color(0xFF14201A);
  static const textoSuave = Color(0xFF5A6660);
  static const destaque = Color(0xFF138A52);
  static const destaqueSuave = Color(0xFFE3F4EA);
  static const destaqueTexto = Color(0xFF0E6B3F);
  static const posicao = Color(0xFF2F6FE4);
  static const avisoFundo = Color(0xFFFFF1E0);
  static const avisoTexto = Color(0xFF8A3C00);
  static const escuro = Color(0xFF14201A);
  static const neutro = Color(0xFFF1F4F2);
}

abstract final class AppText {
  static const titulo = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.texto);
  static const subtitulo = TextStyle(fontSize: 15, color: AppColors.textoSuave);
  static const secao = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.texto);
  static const corpoForte = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.texto);
  static const suave = TextStyle(fontSize: 13, color: AppColors.textoSuave);
}

ThemeData buildAppTheme({TextTheme? textTheme}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.destaque,
    primary: AppColors.destaque,
    onPrimary: Colors.white,
    surface: AppColors.superficie,
    onSurface: AppColors.texto,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.fundo,
    textTheme: textTheme,
  );
  const pill = StadiumBorder();
  return base.copyWith(
    cardTheme: CardThemeData(
      color: AppColors.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borda),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.destaque,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texto,
        minimumSize: const Size(48, 52),
        shape: pill,
        side: const BorderSide(color: Color(0xFFD5DCD8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fundo,
      foregroundColor: AppColors.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.superficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borda),
      ),
    ),
  );
}

/// Sobrescrito no main() com a fonte Plus Jakarta Sans; os testes usam a fonte padrão.
final appThemeProvider = Provider<ThemeData>((ref) => buildAppTheme());
```

<!-- file: app/lib/core/widgets/common.dart -->
```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class EmBreveTag extends StatelessWidget {
  const EmBreveTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.neutro, borderRadius: BorderRadius.circular(999)),
      child: const Text(
        'em breve',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textoSuave),
      ),
    );
  }
}

class EmBreveCard extends StatelessWidget {
  const EmBreveCard({super.key, required this.icon, required this.titulo, required this.texto});

  final IconData icon;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.neutro, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.textoSuave),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.corpoForte),
                const SizedBox(height: 2),
                Text(texto, style: AppText.suave),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const EmBreveTag(),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.texto,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textoSuave)),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppText.secao),
      );
}
```

<!-- file: app/lib/core/widgets/power_chart.dart -->
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Linha de potência ao longo do tempo (uma amostra por segundo).
class PowerChart extends StatelessWidget {
  const PowerChart({super.key, required this.values, this.color = AppColors.destaque});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gráfico de potência',
      child: CustomPaint(painter: _PowerPainter(values, color), child: const SizedBox.expand()),
    );
  }
}

class _PowerPainter extends CustomPainter {
  _PowerPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final maxV = math.max(100.0, values.reduce(math.max)) * 1.1;
    final dx = size.width / (values.length - 1);
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - (values[i] / maxV) * size.height;
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PowerPainter old) => old.values != values || old.color != color;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/core && flutter analyze lib/core`
Expected: `All tests passed!` (5 testes) e `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/core app/test/core && git commit -m "feat(app): formatação pt-BR, tema do Design 2 e componentes base"
```

---

### Task 6: Dados — banco, ajustes e pedais

**Files:**
- Create: `app/lib/data/db/app_database.dart`, `app/lib/data/settings_store.dart`, `app/lib/data/rides_store.dart`, `app/lib/data/providers.dart`
- Test: `app/test/data/settings_store_test.dart`, `app/test/data/rides_store_test.dart`

**Interfaces:**
- Consumes: `PowerMode` (Task 2), `RideSample`, `packSamples`, `unpackSamples` (Task 4).
- Produces: `Future<Database> openAppDatabase({DatabaseFactory? factory, String? path})`.
- Produces: `AppSettings({double pesoKg = 75, PowerMode modoPotencia = auto, double base = 0.6, double fator = 0.25, int cargaPadrao = 4, double metaSemanalKm = 60, String? ultimaBikeId, String? ultimaBikeNome})` + `copyWith`; `abstract class SettingsStore { Future<AppSettings> load(); Future<void> save(AppSettings s); }`; `SqliteSettingsStore(Database)`; `MemorySettingsStore([AppSettings])`.
- Produces: `enum RideMode { rota, fantasma, livre }`; `String rideModeLabel(RideMode)`; `RideRecord({id, routeId?, mode, startedAt, movingTimeS, distanceM, avgPowerW, avgSpeedKmh, gainM, kcal, completed, samples})`; `abstract class RidesStore { Future<void> upsert(RideRecord); Future<RideRecord?> byId(String); Future<List<RideRecord>> recent({int limit = 50}); Future<void> delete(String); }`; `SqliteRidesStore(Database)` (o `recent` não carrega amostras); `MemoryRidesStore`.
- Produces: providers `databaseProvider`, `settingsStoreProvider`, `ridesStoreProvider`, `settingsProvider` (`FutureProvider<AppSettings>`), `recentRidesProvider` (`FutureProvider<List<RideRecord>>`), `rideByIdProvider` (`FutureProvider.family<RideRecord?, String>`).

- [ ] **Step 1: Testes que falham**

<!-- file: app/test/data/settings_store_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/power.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('sem nada salvo, devolve os padrões', () async {
    final s = await SqliteSettingsStore(db).load();
    expect(s.pesoKg, 75);
    expect(s.modoPotencia, PowerMode.auto);
    expect(s.cargaPadrao, 4);
    expect(s.metaSemanalKm, 60);
    expect(s.ultimaBikeId, isNull);
  });

  test('salva e lê de volta', () async {
    final store = SqliteSettingsStore(db);
    await store.save(const AppSettings().copyWith(
      pesoKg: 82,
      modoPotencia: PowerMode.estimada,
      fator: 0.3,
      cargaPadrao: 6,
      ultimaBikeId: 'AA:BB',
      ultimaBikeNome: 'FS-1234',
    ));
    final s = await store.load();
    expect(s.pesoKg, 82);
    expect(s.modoPotencia, PowerMode.estimada);
    expect(s.fator, 0.3);
    expect(s.cargaPadrao, 6);
    expect(s.ultimaBikeId, 'AA:BB');
    expect(s.ultimaBikeNome, 'FS-1234');
  });

  test('versão em memória', () async {
    final store = MemorySettingsStore();
    await store.save(const AppSettings(pesoKg: 90));
    expect((await store.load()).pesoKg, 90);
  });
}
```

<!-- file: app/test/data/rides_store_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/data/db/app_database.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RideRecord pedal(String id, DateTime inicio, {bool completed = true}) => RideRecord(
      id: id,
      mode: RideMode.livre,
      startedAt: inicio,
      movingTimeS: 600,
      distanceM: 5000,
      avgPowerW: 150,
      avgSpeedKmh: 30,
      gainM: 0,
      kcal: 90,
      completed: completed,
      samples: const [
        RideSample(t: 1, distance: 8, speedKmh: 29, power: 150, cadence: 80),
        RideSample(t: 2, distance: 16, speedKmh: 29.5, power: 152, cadence: 81, heartRate: 130),
      ],
    );

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  test('salva e lê pelo id, com as amostras', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('a', DateTime(2026, 10, 7, 20)));
    final r = await store.byId('a');
    expect(r, isNotNull);
    expect(r!.mode, RideMode.livre);
    expect(r.distanceM, 5000);
    expect(r.completed, isTrue);
    expect(r.startedAt, DateTime(2026, 10, 7, 20));
    expect(r.samples.length, 2);
    expect(r.samples[1].heartRate, 130);
    expect(await store.byId('zzz'), isNull);
  });

  test('upsert com o mesmo id substitui', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('a', DateTime(2026, 10, 7), completed: false));
    await store.upsert(pedal('a', DateTime(2026, 10, 7)));
    expect((await store.recent()).length, 1);
    expect((await store.byId('a'))!.completed, isTrue);
  });

  test('recent: mais novo primeiro e sem amostras', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('velho', DateTime(2026, 10, 1)));
    await store.upsert(pedal('novo', DateTime(2026, 10, 7)));
    final lista = await store.recent();
    expect(lista.map((r) => r.id), ['novo', 'velho']);
    expect(lista.first.samples, isEmpty);
  });

  test('apaga', () async {
    final store = SqliteRidesStore(db);
    await store.upsert(pedal('a', DateTime(2026, 10, 7)));
    await store.delete('a');
    expect(await store.byId('a'), isNull);
  });

  test('versão em memória ordena igual', () async {
    final store = MemoryRidesStore();
    await store.upsert(pedal('velho', DateTime(2026, 10, 1)));
    await store.upsert(pedal('novo', DateTime(2026, 10, 7)));
    expect((await store.recent()).map((r) => r.id), ['novo', 'velho']);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/data`
Expected: FAIL — arquivos de `lib/data` não existem.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/data/db/app_database.dart -->
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _schemaVersion = 1;

/// Abre (ou cria) o banco do app. Nos testes, passe `databaseFactoryFfi` e `inMemoryDatabasePath`.
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
      },
    ),
  );
}
```

<!-- file: app/lib/data/settings_store.dart -->
```dart
import 'package:sqflite/sqflite.dart';

import '../domain/power.dart';

class AppSettings {
  const AppSettings({
    this.pesoKg = 75,
    this.modoPotencia = PowerMode.auto,
    this.base = 0.6,
    this.fator = 0.25,
    this.cargaPadrao = 4,
    this.metaSemanalKm = 60,
    this.ultimaBikeId,
    this.ultimaBikeNome,
  });

  final double pesoKg;
  final PowerMode modoPotencia;
  final double base;
  final double fator;
  final int cargaPadrao;
  final double metaSemanalKm;
  final String? ultimaBikeId;
  final String? ultimaBikeNome;

  AppSettings copyWith({
    double? pesoKg,
    PowerMode? modoPotencia,
    double? base,
    double? fator,
    int? cargaPadrao,
    double? metaSemanalKm,
    String? ultimaBikeId,
    String? ultimaBikeNome,
  }) =>
      AppSettings(
        pesoKg: pesoKg ?? this.pesoKg,
        modoPotencia: modoPotencia ?? this.modoPotencia,
        base: base ?? this.base,
        fator: fator ?? this.fator,
        cargaPadrao: cargaPadrao ?? this.cargaPadrao,
        metaSemanalKm: metaSemanalKm ?? this.metaSemanalKm,
        ultimaBikeId: ultimaBikeId ?? this.ultimaBikeId,
        ultimaBikeNome: ultimaBikeNome ?? this.ultimaBikeNome,
      );

  Map<String, String> toMap() => {
        'pesoKg': '$pesoKg',
        'modoPotencia': modoPotencia.name,
        'base': '$base',
        'fator': '$fator',
        'cargaPadrao': '$cargaPadrao',
        'metaSemanalKm': '$metaSemanalKm',
        if (ultimaBikeId != null) 'ultimaBikeId': ultimaBikeId!,
        if (ultimaBikeNome != null) 'ultimaBikeNome': ultimaBikeNome!,
      };

  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    double dbl(String k, double padrao) => double.tryParse(m[k] ?? '') ?? padrao;
    return AppSettings(
      pesoKg: dbl('pesoKg', d.pesoKg),
      modoPotencia: PowerMode.values.asNameMap()[m['modoPotencia']] ?? d.modoPotencia,
      base: dbl('base', d.base),
      fator: dbl('fator', d.fator),
      cargaPadrao: int.tryParse(m['cargaPadrao'] ?? '') ?? d.cargaPadrao,
      metaSemanalKm: dbl('metaSemanalKm', d.metaSemanalKm),
      ultimaBikeId: m['ultimaBikeId'],
      ultimaBikeNome: m['ultimaBikeNome'],
    );
  }
}

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SqliteSettingsStore implements SettingsStore {
  SqliteSettingsStore(this._db);

  final Database _db;

  @override
  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    return AppSettings.fromMap({for (final r in rows) r['key'] as String: r['value'] as String});
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _db.transaction((txn) async {
      await txn.delete('settings');
      final batch = txn.batch();
      settings.toMap().forEach((k, v) => batch.insert('settings', {'key': k, 'value': v}));
      await batch.commit(noResult: true);
    });
  }
}

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}
```

<!-- file: app/lib/data/rides_store.dart -->
```dart
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/ride_samples.dart';
import '../domain/ride_session.dart';

enum RideMode { rota, fantasma, livre }

String rideModeLabel(RideMode mode) => switch (mode) {
      RideMode.rota => 'Rota',
      RideMode.fantasma => 'Contra o fantasma',
      RideMode.livre => 'Pedal livre',
    };

class RideRecord {
  const RideRecord({
    required this.id,
    this.routeId,
    required this.mode,
    required this.startedAt,
    required this.movingTimeS,
    required this.distanceM,
    required this.avgPowerW,
    required this.avgSpeedKmh,
    required this.gainM,
    required this.kcal,
    required this.completed,
    this.samples = const [],
  });

  final String id;
  final String? routeId;
  final RideMode mode;
  final DateTime startedAt;
  final double movingTimeS;
  final double distanceM;
  final double avgPowerW;
  final double avgSpeedKmh;
  final double gainM;
  final double kcal;
  final bool completed;
  final List<RideSample> samples;

  Map<String, Object?> toRow() => {
        'id': id,
        'route_id': routeId,
        'mode': mode.name,
        'started_at': startedAt.millisecondsSinceEpoch,
        'moving_time_s': movingTimeS,
        'distance_m': distanceM,
        'avg_power_w': avgPowerW,
        'avg_speed_kmh': avgSpeedKmh,
        'gain_m': gainM,
        'kcal': kcal,
        'completed': completed ? 1 : 0,
        'samples': packSamples(samples),
      };

  factory RideRecord.fromRow(Map<String, Object?> r) => RideRecord(
        id: r['id'] as String,
        routeId: r['route_id'] as String?,
        mode: RideMode.values.byName(r['mode'] as String),
        startedAt: DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
        movingTimeS: (r['moving_time_s'] as num).toDouble(),
        distanceM: (r['distance_m'] as num).toDouble(),
        avgPowerW: (r['avg_power_w'] as num).toDouble(),
        avgSpeedKmh: (r['avg_speed_kmh'] as num).toDouble(),
        gainM: (r['gain_m'] as num).toDouble(),
        kcal: (r['kcal'] as num).toDouble(),
        completed: (r['completed'] as int) == 1,
        samples: r['samples'] == null ? const [] : unpackSamples(r['samples'] as Uint8List),
      );
}

abstract class RidesStore {
  Future<void> upsert(RideRecord ride);
  Future<RideRecord?> byId(String id);
  Future<List<RideRecord>> recent({int limit = 50});
  Future<void> delete(String id);
}

const _listColumns = [
  'id', 'route_id', 'mode', 'started_at', 'moving_time_s', 'distance_m',
  'avg_power_w', 'avg_speed_kmh', 'gain_m', 'kcal', 'completed',
];

class SqliteRidesStore implements RidesStore {
  SqliteRidesStore(this._db);

  final Database _db;

  @override
  Future<void> upsert(RideRecord ride) =>
      _db.insert('rides', ride.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<RideRecord?> byId(String id) async {
    final rows = await _db.query('rides', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : RideRecord.fromRow(rows.first);
  }

  @override
  Future<List<RideRecord>> recent({int limit = 50}) async {
    final rows = await _db.query('rides', columns: _listColumns, orderBy: 'started_at DESC', limit: limit);
    return rows.map(RideRecord.fromRow).toList();
  }

  @override
  Future<void> delete(String id) => _db.delete('rides', where: 'id = ?', whereArgs: [id]);
}

class MemoryRidesStore implements RidesStore {
  final _rides = <String, RideRecord>{};

  @override
  Future<void> upsert(RideRecord ride) async => _rides[ride.id] = ride;

  @override
  Future<RideRecord?> byId(String id) async => _rides[id];

  @override
  Future<List<RideRecord>> recent({int limit = 50}) async {
    final lista = _rides.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return lista.take(limit).toList();
  }

  @override
  Future<void> delete(String id) async => _rides.remove(id);
}
```

<!-- file: app/lib/data/providers.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'rides_store.dart';
import 'settings_store.dart';

/// Aberto no main() e sobrescrito no ProviderScope.
final databaseProvider = Provider<Database>(
  (ref) => throw StateError('Abra o banco no main() e sobrescreva databaseProvider.'),
);

final settingsStoreProvider = Provider<SettingsStore>((ref) => SqliteSettingsStore(ref.watch(databaseProvider)));

final ridesStoreProvider = Provider<RidesStore>((ref) => SqliteRidesStore(ref.watch(databaseProvider)));

final settingsProvider = FutureProvider<AppSettings>((ref) => ref.watch(settingsStoreProvider).load());

final recentRidesProvider = FutureProvider<List<RideRecord>>((ref) => ref.watch(ridesStoreProvider).recent());

final rideByIdProvider = FutureProvider.family<RideRecord?, String>(
  (ref, id) => ref.watch(ridesStoreProvider).byId(id),
);
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/data`
Expected: `All tests passed!` (8 testes)

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/data app/test/data && git commit -m "feat(app): banco SQLite com ajustes e pedais"
```

---

### Task 7: Bike — leitura, fontes e busca

**Files:**
- Create: `app/lib/bike/bike_reading.dart`, `app/lib/bike/bike_source.dart`, `app/lib/bike/sim_source.dart`, `app/lib/bike/ftms_source.dart`, `app/lib/bike/bike_scanner.dart`
- Test: `app/test/bike/sim_source_test.dart`, `app/test/bike/bike_scanner_test.dart`

**Interfaces:**
- Consumes: `parseIndoorBikeData`, `ftmsServiceUuid`, `indoorBikeDataUuid` (Task 3).
- Produces: `BikeReading({double? cadence, int? power, double? speedKmh, int? heartRate, required DateTime timestamp})`.
- Produces: `enum BikeConnection { desconectada, conectando, conectada, caiu }`; `abstract class BikeSource { String get name; bool get simulated; Stream<BikeReading> get readings; Stream<BikeConnection> get connection; BikeConnection get state; Future<void> connect(); Future<void> disconnect(); Future<void> dispose(); }`.
- Produces: `SimSource({Duration interval, math.Random? random, DateTime Function()? now})` com `target`, `harder()`, `easier()`, `BikeReading sample()`.
- Produces: `NoFtmsException(String diagnostic)`; `FtmsSource({required String deviceId, required String deviceName})`.
- Produces: `FoundDevice({id, name, likelyBike, rssi?})`; `bool isLikelyBike({String? name, List<String> services})`; `List<FoundDevice> sortFound(Iterable<FoundDevice>)`; `enum BleProblem { semPermissao, desligado, semSuporte }`; `String bleProblemText(BleProblem)`; `BikeScanner` com `Future<BleProblem?> check()` e `Stream<List<FoundDevice>> scan({Duration duration})`; `bikeScannerProvider`.

- [ ] **Step 1: Testes que falham**

<!-- file: app/test/bike/sim_source_test.dart -->
```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/bike/sim_source.dart';

class _HalfRandom implements math.Random {
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

final _agora = DateTime(2026, 10, 7, 20);

BikeReading amostrar(SimSource sim, int n) {
  late BikeReading r;
  for (var i = 0; i < n; i++) {
    r = sim.sample();
  }
  return r;
}

void main() {
  test('converge para a potência alvo com cadência plausível', () {
    final sim = SimSource(random: _HalfRandom(), now: () => _agora);
    final r = amostrar(sim, 20);
    expect(r.power, closeTo(150, 1));
    expect(r.cadence, inInclusiveRange(70, 90));
    expect(r.timestamp, _agora);
  });

  test('mais forte e mais fraco mudam o alvo', () {
    final sim = SimSource(random: _HalfRandom(), now: () => _agora);
    sim
      ..harder()
      ..harder();
    expect(sim.target, 200);
    expect(amostrar(sim, 20).power, closeTo(200, 1));
    for (var i = 0; i < 10; i++) {
      sim.easier();
    }
    expect(sim.target, 0);
    final parado = amostrar(sim, 20);
    expect(parado.power, 0);
    expect(parado.cadence, 0);
    for (var i = 0; i < 30; i++) {
      sim.harder();
    }
    expect(sim.target, 400);
  });

  test('connect emite leituras e muda o estado', () async {
    final sim = SimSource(interval: const Duration(milliseconds: 5));
    final leituras = <BikeReading>[];
    final sub = sim.readings.listen(leituras.add);
    await sim.connect();
    expect(sim.state, BikeConnection.conectada);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await sim.disconnect();
    expect(sim.state, BikeConnection.desconectada);
    expect(leituras, isNotEmpty);
    await sub.cancel();
    await sim.dispose();
  });
}
```

<!-- file: app/test/bike/bike_scanner_test.dart -->
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_scanner.dart';

void main() {
  test('reconhece bike pelo serviço FTMS ou pelo nome FS-', () {
    expect(isLikelyBike(name: 'FS-1A2B3C'), isTrue);
    expect(isLikelyBike(name: 'fs-1a2b'), isTrue);
    expect(isLikelyBike(name: 'Qualquer', services: ['00001826-0000-1000-8000-00805F9B34FB']), isTrue);
    expect(isLikelyBike(name: 'JBL Flip'), isFalse);
    expect(isLikelyBike(), isFalse);
  });

  test('ordena: bikes primeiro, depois sinal mais forte', () {
    final lista = sortFound([
      const FoundDevice(id: 'a', name: 'Fone', likelyBike: false, rssi: -40),
      const FoundDevice(id: 'b', name: 'FS-1', likelyBike: true, rssi: -80),
      const FoundDevice(id: 'c', name: 'FS-2', likelyBike: true, rssi: -60),
      const FoundDevice(id: 'd', name: 'TV', likelyBike: false),
    ]);
    expect(lista.map((d) => d.id), ['c', 'b', 'a', 'd']);
  });

  test('textos dos problemas de Bluetooth', () {
    expect(bleProblemText(BleProblem.desligado), contains('desligado'));
    expect(bleProblemText(BleProblem.semPermissao), contains('permissão'));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/bike`
Expected: FAIL — arquivos de `lib/bike` não existem.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/bike/bike_reading.dart -->
```dart
/// Uma leitura da bike. Campos ausentes = a bike não mandou.
class BikeReading {
  const BikeReading({this.cadence, this.power, this.speedKmh, this.heartRate, required this.timestamp});

  final double? cadence;
  final int? power;
  final double? speedKmh;
  final int? heartRate;
  final DateTime timestamp;
}
```

<!-- file: app/lib/bike/bike_source.dart -->
```dart
import 'bike_reading.dart';

enum BikeConnection { desconectada, conectando, conectada, caiu }

/// Fonte de dados da bike: real (FTMS) ou simulada.
abstract class BikeSource {
  String get name;
  bool get simulated;
  Stream<BikeReading> get readings;
  Stream<BikeConnection> get connection;
  BikeConnection get state;
  Future<void> connect();
  Future<void> disconnect();

  /// Desconecta e fecha os streams; a fonte não pode mais ser usada.
  Future<void> dispose();
}
```

<!-- file: app/lib/bike/sim_source.dart -->
```dart
import 'dart:async';
import 'dart:math' as math;

import 'bike_reading.dart';
import 'bike_source.dart';

/// Bike falsa: cadência e potência a cada [interval], para testar sem a bike real.
class SimSource implements BikeSource {
  SimSource({this.interval = const Duration(seconds: 1), math.Random? random, DateTime Function()? now})
      : _random = random ?? math.Random(),
        _now = now ?? DateTime.now;

  final Duration interval;
  final math.Random _random;
  final DateTime Function() _now;
  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  BikeConnection _state = BikeConnection.desconectada;
  Timer? _timer;
  int _target = 150;
  double _power = 0;

  int get target => _target;

  @override
  String get name => 'Bike simulada';

  @override
  bool get simulated => true;

  @override
  Stream<BikeReading> get readings => _readings.stream;

  @override
  Stream<BikeConnection> get connection => _connection.stream;

  @override
  BikeConnection get state => _state;

  BikeReading sample() {
    _power = math.max(0.0, _power + (_target - _power) * 0.4 + (_random.nextDouble() - 0.5) * 12);
    if (_target == 0 && _power < 15) _power = 0;
    final cadence = _power == 0
        ? 0.0
        : (65 + _power / 12 + (_random.nextDouble() - 0.5) * 4).clamp(55.0, 105.0).roundToDouble();
    return BikeReading(cadence: cadence, power: _power.round(), timestamp: _now());
  }

  void harder() => _target = math.min(400, _target + 25);

  void easier() => _target = math.max(0, _target - 25);

  void _set(BikeConnection c) {
    _state = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect() async {
    _timer ??= Timer.periodic(interval, (_) {
      if (!_readings.isClosed) _readings.add(sample());
    });
    _set(BikeConnection.conectada);
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _set(BikeConnection.desconectada);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _readings.close();
    await _connection.close();
  }
}
```

<!-- file: app/lib/bike/ftms_source.dart -->
```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../domain/ftms_parser.dart';
import 'bike_reading.dart';
import 'bike_source.dart';

/// O aparelho conectou, mas não tem o serviço FTMS. [diagnostic] lista o que ele tem.
class NoFtmsException implements Exception {
  const NoFtmsException(this.diagnostic);

  final String diagnostic;

  @override
  String toString() => 'Sem FTMS\n$diagnostic';
}

/// Bike real pelo Bluetooth, padrão FTMS.
class FtmsSource implements BikeSource {
  FtmsSource({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;
  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<bool>? _connSub;
  BikeConnection _state = BikeConnection.desconectada;
  bool _manual = false;

  @override
  String get name => deviceName;

  @override
  bool get simulated => false;

  @override
  Stream<BikeReading> get readings => _readings.stream;

  @override
  Stream<BikeConnection> get connection => _connection.stream;

  @override
  BikeConnection get state => _state;

  void _set(BikeConnection c) {
    _state = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect() async {
    _manual = false;
    _set(BikeConnection.conectando);
    try {
      await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 15));
      final services = await UniversalBle.discoverServices(deviceId);
      final hasFtms = services.any((s) => s.uuid.toLowerCase() == ftmsServiceUuid);
      if (!hasFtms) {
        final lista = services.map((s) => '  ${s.uuid}').join('\n');
        _manual = true;
        await UniversalBle.disconnect(deviceId);
        _set(BikeConnection.desconectada);
        throw NoFtmsException('Aparelho: $deviceName\nServiços:\n${lista.isEmpty ? '  (nenhum)' : lista}');
      }
      await _valueSub?.cancel();
      _valueSub = UniversalBle.characteristicValueStream(deviceId, indoorBikeDataUuid).listen(_onValue);
      await UniversalBle.subscribeNotifications(deviceId, ftmsServiceUuid, indoorBikeDataUuid);
      await _connSub?.cancel();
      _connSub = UniversalBle.connectionStream(deviceId).listen((connected) {
        if (!connected) _set(_manual ? BikeConnection.desconectada : BikeConnection.caiu);
      });
      _set(BikeConnection.conectada);
    } on NoFtmsException {
      rethrow;
    } catch (_) {
      _set(BikeConnection.desconectada);
      rethrow;
    }
  }

  void _onValue(Uint8List bytes) {
    final d = parseIndoorBikeData(bytes);
    if (_readings.isClosed) return;
    _readings.add(BikeReading(
      cadence: d.cadence,
      power: d.power,
      speedKmh: d.speedKmh,
      heartRate: d.heartRate,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> disconnect() async {
    _manual = true;
    await _valueSub?.cancel();
    _valueSub = null;
    try {
      await UniversalBle.disconnect(deviceId);
    } catch (_) {
      // já estava desconectada
    }
    _set(BikeConnection.desconectada);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _connSub?.cancel();
    await _readings.close();
    await _connection.close();
  }
}
```

<!-- file: app/lib/bike/bike_scanner.dart -->
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../domain/ftms_parser.dart';

class FoundDevice {
  const FoundDevice({required this.id, required this.name, required this.likelyBike, this.rssi});

  final String id;
  final String name;
  final bool likelyBike;
  final int? rssi;
}

/// Parece uma bike: anuncia o serviço FTMS ou tem nome de painel FitShow ("FS-").
bool isLikelyBike({String? name, List<String> services = const []}) =>
    services.any((s) => s.toLowerCase() == ftmsServiceUuid) || (name ?? '').toUpperCase().startsWith('FS-');

List<FoundDevice> sortFound(Iterable<FoundDevice> devices) => devices.toList()
  ..sort((a, b) {
    if (a.likelyBike != b.likelyBike) return a.likelyBike ? -1 : 1;
    return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
  });

enum BleProblem { semPermissao, desligado, semSuporte }

String bleProblemText(BleProblem p) => switch (p) {
      BleProblem.semPermissao =>
        'O app precisa da permissão de Bluetooth (Dispositivos próximos) para achar a bike. Libere nas configurações do celular.',
      BleProblem.desligado => 'O Bluetooth está desligado. Ligue e toque em "Procurar de novo".',
      BleProblem.semSuporte => 'Este aparelho não tem Bluetooth compatível.',
    };

class BikeScanner {
  /// Pede permissão e confere se o Bluetooth está ligado. `null` = tudo certo.
  Future<BleProblem?> check() async {
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {
      return BleProblem.semPermissao;
    }
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return switch (state) {
      AvailabilityState.poweredOff => BleProblem.desligado,
      AvailabilityState.unsupported => BleProblem.semSuporte,
      AvailabilityState.unauthorized => BleProblem.semPermissao,
      _ => null,
    };
  }

  /// Procura aparelhos por [duration]; cada evento traz a lista acumulada e ordenada.
  Stream<List<FoundDevice>> scan({Duration duration = const Duration(seconds: 12)}) {
    final found = <String, FoundDevice>{};
    StreamSubscription<BleDevice>? sub;
    Timer? timer;
    late final StreamController<List<FoundDevice>> controller;

    Future<void> stop() async {
      timer?.cancel();
      await sub?.cancel();
      try {
        await UniversalBle.stopScan();
      } catch (_) {
        // a busca já tinha parado
      }
      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<List<FoundDevice>>(
      onListen: () async {
        sub = UniversalBle.scanStream.listen((d) {
          final name = d.name ?? '';
          found[d.deviceId] = FoundDevice(
            id: d.deviceId,
            name: name.isEmpty ? 'Sem nome' : name,
            likelyBike: isLikelyBike(name: d.name, services: d.services),
            rssi: d.rssi,
          );
          if (!controller.isClosed) controller.add(sortFound(found.values));
        });
        timer = Timer(duration, stop);
        try {
          await UniversalBle.startScan();
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
          await stop();
        }
      },
      onCancel: stop,
    );
    return controller.stream;
  }
}

final bikeScannerProvider = Provider<BikeScanner>((ref) => BikeScanner());
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/bike && flutter analyze lib/bike`
Expected: `All tests passed!` (6 testes) e `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/bike app/test/bike && git commit -m "feat(app): fontes da bike (FTMS e simulada) e busca Bluetooth"
```

---

### Task 8: Bike — controlador com reconexão

**Files:**
- Create: `app/lib/bike/bike_controller.dart`, `app/lib/core/wake_lock.dart`, `app/test/support/fakes.dart`
- Test: `app/test/bike/bike_controller_test.dart`

**Interfaces:**
- Consumes: `BikeSource`, `BikeConnection`, `SimSource`, `FtmsSource`, `NoFtmsException` (Task 7); `settingsStoreProvider`, `AppSettings.copyWith` (Task 6).
- Produces: `BikeState({BikeSource? source, BikeConnection connection, String? message, String? diagnostic})` com `connected`; `typedef FtmsFactory = BikeSource Function(String deviceId, String deviceName)`; `ftmsFactoryProvider`; `reconnectDelaysProvider` (`Provider<List<Duration>>`); `BikeController` com `useSimulated()`, `useDevice(id, name)`, `useSource(BikeSource)`, `reconnectLast()`, `reconnectNow()`, `disconnect()`; `bikeControllerProvider`.
- Produces: `abstract interface class WakeLock { Future<void> enable(); Future<void> disable(); }`; `PlatformWakeLock`; `wakeLockProvider` (`Provider<WakeLock>`), em `app/lib/core/wake_lock.dart`.
- Produces (testes): `FakeBikeSource` (`connectCalls`, `failNext`, `failWith`, `emitConnection`, `emitReading`), `FakeWakeLock` (usado na Task 9), `Future<void> settle()`.

- [ ] **Step 1: Apoio de teste e testes que falham**

<!-- file: app/test/support/fakes.dart -->
```dart
import 'dart:async';

import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/wake_lock.dart';

class FakeBikeSource implements BikeSource {
  FakeBikeSource({this.name = 'Bike de teste'});

  @override
  final String name;

  @override
  bool get simulated => false;

  final _readings = StreamController<BikeReading>.broadcast();
  final _connection = StreamController<BikeConnection>.broadcast();
  BikeConnection _state = BikeConnection.desconectada;
  int connectCalls = 0;
  int failNext = 0;
  Exception? failWith;
  bool disposed = false;

  @override
  Stream<BikeReading> get readings => _readings.stream;

  @override
  Stream<BikeConnection> get connection => _connection.stream;

  @override
  BikeConnection get state => _state;

  void emitConnection(BikeConnection c) {
    _state = c;
    _connection.add(c);
  }

  void emitReading(BikeReading r) => _readings.add(r);

  @override
  Future<void> connect() async {
    connectCalls++;
    final f = failWith;
    if (f != null) throw f;
    if (failNext > 0) {
      failNext--;
      emitConnection(BikeConnection.desconectada);
      throw Exception('falhou');
    }
    emitConnection(BikeConnection.conectada);
  }

  @override
  Future<void> disconnect() async => emitConnection(BikeConnection.desconectada);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _readings.close();
    await _connection.close();
  }
}

class FakeWakeLock implements WakeLock {
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}

/// Deixa timers de zero segundos e eventos de stream acontecerem.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
```

<!-- file: app/test/bike/bike_controller_test.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/bike/ftms_source.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/settings_store.dart';

import '../support/fakes.dart';

void main() {
  late FakeBikeSource fake;
  late MemorySettingsStore settings;
  late ProviderContainer container;

  setUp(() {
    fake = FakeBikeSource(name: 'FS-1234');
    settings = MemorySettingsStore();
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      ftmsFactoryProvider.overrideWithValue((id, name) => fake),
      reconnectDelaysProvider.overrideWithValue(const [Duration.zero, Duration.zero, Duration.zero]),
    ]);
    addTearDown(container.dispose);
  });

  BikeController ctrl() => container.read(bikeControllerProvider.notifier);
  BikeState estado() => container.read(bikeControllerProvider);

  test('useDevice conecta e lembra a bike', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    expect(estado().connected, isTrue);
    expect(estado().source!.name, 'FS-1234');
    final s = await settings.load();
    expect(s.ultimaBikeId, 'AA:BB');
    expect(s.ultimaBikeNome, 'FS-1234');
  });

  test('reconnectLast usa a bike salva', () async {
    await settings.save(const AppSettings(ultimaBikeId: 'AA:BB', ultimaBikeNome: 'FS-1234'));
    await ctrl().reconnectLast();
    expect(estado().connected, isTrue);
    expect(fake.connectCalls, 1);
  });

  test('sem FTMS: mostra o diagnóstico e não fica conectada', () async {
    fake.failWith = const NoFtmsException('Aparelho: X\nServiços:\n  fff0');
    await ctrl().useDevice('AA:BB', 'X');
    expect(estado().connected, isFalse);
    expect(estado().source, isNull);
    expect(estado().diagnostic, contains('fff0'));
    expect(estado().message, contains('FTMS'));
    expect(fake.disposed, isTrue);
  });

  test('queda: reconecta sozinho', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    fake.failNext = 1;
    fake.emitConnection(BikeConnection.caiu);
    await settle();
    expect(fake.connectCalls, 3); // conexão inicial + 1 falha + 1 sucesso
    expect(estado().connection, BikeConnection.conectada);
  });

  test('queda: desiste depois de 3 tentativas', () async {
    await ctrl().useDevice('AA:BB', 'FS-1234');
    fake.failNext = 99;
    fake.emitConnection(BikeConnection.caiu);
    await settle();
    expect(fake.connectCalls, 4);
    expect(estado().connected, isFalse);
    expect(estado().message, contains('Reconectar'));
  });

  test('bike simulada', () async {
    await ctrl().useSimulated();
    expect(estado().connected, isTrue);
    expect(estado().source!.simulated, isTrue);
    await ctrl().disconnect();
    expect(estado().source, isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/bike/bike_controller_test.dart`
Expected: FAIL — `bike_controller.dart` e `core/wake_lock.dart` não existem.

- [ ] **Step 3: Implementar o controlador e a trava de tela**

<!-- file: app/lib/core/wake_lock.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantém a tela acesa durante o pedal.
abstract interface class WakeLock {
  Future<void> enable();
  Future<void> disable();
}

class PlatformWakeLock implements WakeLock {
  const PlatformWakeLock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final wakeLockProvider = Provider<WakeLock>((ref) => const PlatformWakeLock());
```

<!-- file: app/lib/bike/bike_controller.dart -->
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'bike_source.dart';
import 'ftms_source.dart';
import 'sim_source.dart';

class BikeState {
  const BikeState({this.source, this.connection = BikeConnection.desconectada, this.message, this.diagnostic});

  final BikeSource? source;
  final BikeConnection connection;
  final String? message;
  final String? diagnostic;

  bool get connected => connection == BikeConnection.conectada;

  BikeState copyWith({BikeConnection? connection, String? message, bool clearMessage = false}) => BikeState(
        source: source,
        connection: connection ?? this.connection,
        message: clearMessage ? null : (message ?? this.message),
        diagnostic: clearMessage ? null : diagnostic,
      );
}

typedef FtmsFactory = BikeSource Function(String deviceId, String deviceName);

final ftmsFactoryProvider = Provider<FtmsFactory>(
  (ref) => (id, name) => FtmsSource(deviceId: id, deviceName: name),
);

final reconnectDelaysProvider = Provider<List<Duration>>(
  (ref) => const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 10)],
);

class BikeController extends Notifier<BikeState> {
  StreamSubscription<BikeConnection>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _reconnecting = false;

  @override
  BikeState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _retry?.cancel();
    });
    return const BikeState();
  }

  Future<void> useSimulated() => useSource(SimSource());

  Future<void> useDevice(String deviceId, String deviceName) async {
    await useSource(ref.read(ftmsFactoryProvider)(deviceId, deviceName));
    if (!ref.mounted || !state.connected) return;
    final store = ref.read(settingsStoreProvider);
    final s = await store.load();
    await store.save(s.copyWith(ultimaBikeId: deviceId, ultimaBikeNome: deviceName));
  }

  /// Ao abrir o app: tenta a última bike usada, se houver.
  Future<void> reconnectLast() async {
    final s = await ref.read(settingsStoreProvider).load();
    final id = s.ultimaBikeId;
    if (!ref.mounted || id == null || state.connected) return;
    await useDevice(id, s.ultimaBikeNome ?? 'Bike');
  }

  Future<void> useSource(BikeSource source) async {
    _retry?.cancel();
    _attempt = 0;
    await _sub?.cancel();
    _sub = null;
    final old = state.source;
    if (old != null && !identical(old, source)) await old.dispose();
    if (!ref.mounted) return;
    state = BikeState(source: source, connection: BikeConnection.conectando);
    _sub = source.connection.listen(_onConnection);
    try {
      await source.connect();
      if (!ref.mounted) return;
      state = BikeState(source: source, connection: source.state);
    } on NoFtmsException catch (e) {
      await _drop(source);
      if (!ref.mounted) return;
      state = BikeState(
        message: 'A bike conectou, mas não usa o padrão FTMS. Me mande o texto abaixo.',
        diagnostic: e.diagnostic,
      );
    } catch (e) {
      await _drop(source);
      if (!ref.mounted) return;
      state = BikeState(message: 'Não foi possível conectar: $e');
    }
  }

  Future<void> _drop(BikeSource source) async {
    await _sub?.cancel();
    _sub = null;
    await source.dispose();
  }

  void _onConnection(BikeConnection c) {
    if (!ref.mounted || state.source == null) return;
    state = state.copyWith(connection: c, clearMessage: c == BikeConnection.conectada);
    if (c == BikeConnection.conectada) _attempt = 0;
    if (c == BikeConnection.caiu && !_reconnecting && !(_retry?.isActive ?? false)) _scheduleRetry();
  }

  void _scheduleRetry() {
    final delays = ref.read(reconnectDelaysProvider);
    if (_attempt >= delays.length) {
      state = state.copyWith(connection: BikeConnection.caiu, message: 'A bike desconectou. Toque em Reconectar.');
      return;
    }
    final delay = delays[_attempt++];
    _retry = Timer(delay, () async {
      final source = state.source;
      if (source == null) return;
      _reconnecting = true;
      try {
        await source.connect();
      } catch (_) {
        if (ref.mounted) _scheduleRetry();
      } finally {
        _reconnecting = false;
      }
    });
  }

  Future<void> reconnectNow() async {
    _retry?.cancel();
    _attempt = 0;
    final source = state.source;
    if (source == null) return;
    try {
      await source.connect();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(message: 'Não reconectou: $e');
    }
  }

  Future<void> disconnect() async {
    _retry?.cancel();
    final source = state.source;
    if (source == null) return;
    await _sub?.cancel();
    _sub = null;
    await source.dispose();
    if (ref.mounted) state = const BikeState();
  }
}

final bikeControllerProvider = NotifierProvider<BikeController, BikeState>(BikeController.new);
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd /c/dev/pedal-local/app && flutter test test/bike && flutter analyze lib/bike lib/core`
Expected: `All tests passed!` (12 testes em `test/bike`) e `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/bike/bike_controller.dart app/lib/core/wake_lock.dart app/test/support app/test/bike/bike_controller_test.dart && git commit -m "feat(app): controlador da bike com reconexão automática"
```

---

### Task 9: Pedal livre — controlador

**Files:**
- Create: `app/lib/features/pedal_livre/free_ride_controller.dart`
- Test: `app/test/features/free_ride_controller_test.dart`

**Interfaces:**
- Consumes: `RideSession`, `FlatTerrain`, `RideState` (Task 4); `PowerResolver`, `PowerCalibration`, `PowerMode` (Task 2); `bikeControllerProvider`, `BikeConnection`, `BikeReading` (Tasks 7–8); `settingsStoreProvider`, `ridesStoreProvider`, `recentRidesProvider`, `RideRecord`, `RideMode` (Task 6).
- Consumes: `WakeLock`, `wakeLockProvider` (Task 8).
- Produces: providers `clockProvider` (`Provider<DateTime Function()>`), `rideIdProvider` (`Provider<String Function()>`), `rideTickProvider` (`Provider<Duration>`); `FreeRideView` (`started, state, speedKmh, power, cadence, heartRate, distance, movingTime, kcal, level, estimating, pausedByBike, powerHistory`); `FreeRideController` com `start()`, `onReading(BikeReading)`, `tick()`, `changeLevel(int)`, `togglePause()`, `Future<String> finish()`; `freeRideProvider` (`NotifierProvider.autoDispose`).

- [ ] **Step 1: Teste que falha**

<!-- file: app/test/features/free_ride_controller_test.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/bike/bike_controller.dart';
import 'package:pedal_local/bike/bike_reading.dart';
import 'package:pedal_local/bike/bike_source.dart';
import 'package:pedal_local/core/wake_lock.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/settings_store.dart';
import 'package:pedal_local/domain/ride_session.dart';
import 'package:pedal_local/features/pedal_livre/free_ride_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeBikeSource bike;
  late FakeWakeLock wake;
  late MemoryRidesStore rides;
  late ProviderContainer container;
  late DateTime agora;

  setUp(() async {
    bike = FakeBikeSource();
    wake = FakeWakeLock();
    rides = MemoryRidesStore();
    agora = DateTime(2026, 10, 7, 20);
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ridesStoreProvider.overrideWithValue(rides),
      wakeLockProvider.overrideWithValue(wake),
      clockProvider.overrideWithValue(() => agora),
      rideIdProvider.overrideWithValue(() => 'r1'),
      rideTickProvider.overrideWithValue(const Duration(hours: 1)),
      reconnectDelaysProvider.overrideWithValue(const [Duration(hours: 1)]),
    ]);
    addTearDown(container.dispose);
    container.listen(freeRideProvider, (anterior, proximo) {});
    await container.read(bikeControllerProvider.notifier).useSource(bike);
  });

  FreeRideController ctrl() => container.read(freeRideProvider.notifier);
  FreeRideView view() => container.read(freeRideProvider);

  Future<void> pedalar(int segundos, {int? power = 150, double cadence = 80}) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      bike.emitReading(BikeReading(cadence: cadence, power: power, timestamp: agora));
      await settle();
      ctrl().tick();
    }
  }

  Future<void> esperar(int segundos) async {
    for (var i = 0; i < segundos * 4; i++) {
      agora = agora.add(const Duration(milliseconds: 250));
      ctrl().tick();
    }
  }

  test('start liga a tela, salva o pedal e começa pedalando', () async {
    await ctrl().start();
    expect(wake.enabled, isTrue);
    expect(view().started, isTrue);
    expect(view().state, RideState.pedalando);
    final salvo = await rides.byId('r1');
    expect(salvo!.completed, isFalse);
    expect(salvo.mode, RideMode.livre);
  });

  test('pedalando com 150 W ganha velocidade e grava o histórico de potência', () async {
    await ctrl().start();
    await pedalar(10);
    expect(view().speedKmh, greaterThan(15));
    expect(view().distance, greaterThan(0));
    expect(view().power, 150);
    expect(view().powerHistory.length, 10);
  });

  test('sem leitura por mais de 3 s, a potência zera', () async {
    await ctrl().start();
    await pedalar(5);
    await esperar(4);
    expect(view().power, 0);
  });

  test('carga muda entre 1 e 10', () async {
    await ctrl().start();
    for (var i = 0; i < 20; i++) {
      ctrl().changeLevel(1);
    }
    expect(view().level, 10);
    for (var i = 0; i < 20; i++) {
      ctrl().changeLevel(-1);
    }
    expect(view().level, 1);
  });

  test('pausar e continuar', () async {
    await ctrl().start();
    await pedalar(3);
    ctrl().togglePause();
    expect(view().state, RideState.pausado);
    ctrl().togglePause();
    expect(view().state, RideState.pedalando);
  });

  test('queda da bike pausa; reconexão retoma', () async {
    await ctrl().start();
    await pedalar(3);
    bike.emitConnection(BikeConnection.caiu);
    await settle();
    expect(view().state, RideState.pausado);
    expect(view().pausedByBike, isTrue);
    bike.emitConnection(BikeConnection.conectada);
    await settle();
    expect(view().state, RideState.pedalando);
    expect(view().pausedByBike, isFalse);
  });

  test('finish salva concluído com amostras e desliga a tela', () async {
    await ctrl().start();
    await pedalar(12);
    final id = await ctrl().finish();
    expect(id, 'r1');
    final salvo = await rides.byId('r1');
    expect(salvo!.completed, isTrue);
    expect(salvo.samples.length, greaterThanOrEqualTo(12));
    expect(salvo.distanceM, greaterThan(0));
    expect(salvo.avgPowerW, greaterThan(100));
    expect(wake.enabled, isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/features`
Expected: FAIL — `free_ride_controller.dart` não existe.

- [ ] **Step 3: Implementar**

<!-- file: app/lib/features/pedal_livre/free_ride_controller.dart -->
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_reading.dart';
import '../../bike/bike_source.dart';
import '../../core/wake_lock.dart';
import '../../data/providers.dart';
import '../../data/rides_store.dart';
import '../../domain/power.dart';
import '../../domain/ride_session.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final rideIdProvider = Provider<String Function()>(
  (ref) => () => 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
);
final rideTickProvider = Provider<Duration>((ref) => const Duration(milliseconds: 250));

const _historyLength = 300; // 5 minutos de amostras
const _staleAfter = Duration(seconds: 3);
const _saveEverySeconds = 15.0;

class FreeRideView {
  const FreeRideView({
    this.started = false,
    this.state = RideState.pronto,
    this.speedKmh = 0,
    this.power = 0,
    this.cadence = 0,
    this.heartRate,
    this.distance = 0,
    this.movingTime = 0,
    this.kcal = 0,
    this.level = 4,
    this.estimating = false,
    this.pausedByBike = false,
    this.powerHistory = const [],
  });

  final bool started;
  final RideState state;
  final double speedKmh;
  final double power;
  final double cadence;
  final double? heartRate;
  final double distance;
  final double movingTime;
  final double kcal;
  final int level;
  final bool estimating;
  final bool pausedByBike;
  final List<double> powerHistory;
}

class FreeRideController extends Notifier<FreeRideView> {
  RideSession? _session;
  PowerResolver? _resolver;
  WakeLock? _wakeLock;
  Timer? _ticker;
  StreamSubscription<BikeReading>? _readingSub;
  StreamSubscription<BikeConnection>? _connectionSub;
  DateTime? _startedAt;
  DateTime? _lastTick;
  DateTime? _lastReading;
  String? _rideId;
  double _sinceSave = 0;
  int _level = 4;
  int _seenSamples = 0;
  bool _pausedByBike = false;
  final List<double> _history = [];

  @override
  FreeRideView build() {
    ref.onDispose(_stop);
    return const FreeRideView();
  }

  Future<void> start() async {
    if (_session != null) return;
    final settings = await ref.read(settingsStoreProvider).load();
    if (!ref.mounted || _session != null) return;
    final clock = ref.read(clockProvider);
    _session = RideSession(terrain: const FlatTerrain(), riderMassKg: settings.pesoKg)..start();
    _resolver = PowerResolver(
      mode: settings.modoPotencia,
      calibration: PowerCalibration(base: settings.base, factor: settings.fator),
    );
    _level = settings.cargaPadrao;
    _startedAt = clock();
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
    session.advance(dt);
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

  /// Encerra, salva como concluído e devolve o id do pedal.
  Future<String> finish() async {
    final session = _session!;
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
          mode: RideMode.livre,
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
    state = FreeRideView(
      started: true,
      state: snap.state,
      speedKmh: snap.speedKmh,
      power: snap.power,
      cadence: snap.cadence,
      heartRate: snap.heartRate,
      distance: snap.distance,
      movingTime: snap.movingTime,
      kcal: snap.kcal,
      level: _level,
      estimating: _resolver?.effectiveMode == PowerMode.estimada,
      pausedByBike: _pausedByBike,
      powerHistory: List.unmodifiable(_history),
    );
  }
}

final freeRideProvider = NotifierProvider.autoDispose<FreeRideController, FreeRideView>(FreeRideController.new);
```

- [ ] **Step 4: Rodar e ver passar (inclui os testes da Task 8)**

Run: `cd /c/dev/pedal-local/app && flutter test test/features`
Expected: `All tests passed!` (7 testes)

- [ ] **Step 5: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib/features/pedal_livre/free_ride_controller.dart app/test/features && git commit -m "feat(app): controlador do pedal livre"
```

---

### Task 10: Telas e navegação

**Files:**
- Create: `app/lib/main.dart` (substituir), `app/lib/app.dart`, `app/lib/core/router/app_router.dart`, `app/lib/core/widgets/shell_scaffold.dart`, `app/lib/features/bike/bike_chip.dart`, `app/lib/features/bike/conectar_bike_screen.dart`, `app/lib/features/escolher_pedal/escolher_pedal_sheet.dart`, `app/lib/features/inicio/inicio_screen.dart`, `app/lib/features/explorar/explorar_screen.dart`, `app/lib/features/treinos/treinos_screen.dart`, `app/lib/features/voce/voce_screen.dart`, `app/lib/features/voce/ajustes_screen.dart`, `app/lib/features/voce/ride_tile.dart`, `app/lib/features/pedal_livre/pedal_livre_card.dart`, `app/lib/features/pedal_livre/pedal_livre_screen.dart`, `app/lib/features/resumo/resumo_screen.dart`
- Test: `app/test/widget/app_test.dart`

**Interfaces:**
- Consumes: tudo das Tasks 2–9.
- Produces: `PedalLocalApp`; `appRouterProvider`; rotas `/inicio`, `/explorar`, `/treinos`, `/voce`, `/ajustes`, `/bike`, `/pedal-livre`, `/resumo/:id`; `showEscolherPedal(BuildContext)`; chave `Key('botao-pedalar')` no botão central.

- [ ] **Step 1: Teste de widget que falha**

<!-- file: app/test/widget/app_test.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedal_local/app.dart';
import 'package:pedal_local/data/providers.dart';
import 'package:pedal_local/data/rides_store.dart';
import 'package:pedal_local/data/settings_store.dart';

Widget app(MemoryRidesStore rides) => ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        ridesStoreProvider.overrideWithValue(rides),
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

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /c/dev/pedal-local/app && flutter test test/widget`
Expected: FAIL — `app.dart` não existe.

- [ ] **Step 3: Implementar o esqueleto (main, app, rotas, barra de abas)**

<!-- file: app/lib/main.dart -->
```dart
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
```

<!-- file: app/lib/app.dart -->
```dart
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
```

<!-- file: app/lib/core/router/app_router.dart -->
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bike/conectar_bike_screen.dart';
import '../../features/explorar/explorar_screen.dart';
import '../../features/inicio/inicio_screen.dart';
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
      GoRoute(path: '/pedal-livre', builder: (c, s) => const PedalLivreScreen()),
      GoRoute(path: '/resumo/:id', builder: (c, s) => ResumoScreen(rideId: s.pathParameters['id']!)),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
```

<!-- file: app/lib/core/widgets/shell_scaffold.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/escolher_pedal/escolher_pedal_sheet.dart';
import '../theme/app_theme.dart';

/// Barra de 5 abas: Início · Explorar · (Pedalar) · Treinos · Você.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int branch) => shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.superficie,
          border: Border(top: BorderSide(color: AppColors.borda)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TabItem(icon: Icons.home_outlined, label: 'Início', selected: shell.currentIndex == 0, onTap: () => _go(0)),
                _TabItem(icon: Icons.explore_outlined, label: 'Explorar', selected: shell.currentIndex == 1, onTap: () => _go(1)),
                _PedalarButton(onTap: () => showEscolherPedal(context)),
                _TabItem(icon: Icons.bar_chart_rounded, label: 'Treinos', selected: shell.currentIndex == 2, onTap: () => _go(2)),
                _TabItem(icon: Icons.person_outline, label: 'Você', selected: shell.currentIndex == 3, onTap: () => _go(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.destaque : AppColors.textoSuave;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PedalarButton extends StatelessWidget {
  const _PedalarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Material(
        color: AppColors.destaque,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.destaque.withValues(alpha: 0.4),
        child: InkWell(
          key: const Key('botao-pedalar'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 62,
            height: 62,
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34, semanticLabel: 'Pedalar'),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implementar bike (chip e tela de conexão) e escolha do pedal**

<!-- file: app/lib/features/bike/bike_chip.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_source.dart';
import '../../core/theme/app_theme.dart';

/// Status da bike; tocar abre a tela de conexão.
class BikeChip extends StatelessWidget {
  const BikeChip({super.key, required this.state});

  final BikeState state;

  @override
  Widget build(BuildContext context) {
    final ok = state.connected;
    final texto = ok
        ? state.source!.name
        : state.connection == BikeConnection.caiu
            ? 'Reconectando…'
            : 'Sem bike';
    final cor = ok ? AppColors.destaqueTexto : AppColors.textoSuave;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.push('/bike'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ok ? AppColors.destaqueSuave : AppColors.neutro,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth, size: 16, color: cor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

<!-- file: app/lib/features/bike/conectar_bike_screen.dart -->
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../bike/bike_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class ConectarBikeScreen extends ConsumerStatefulWidget {
  const ConectarBikeScreen({super.key});

  @override
  ConsumerState<ConectarBikeScreen> createState() => _ConectarBikeScreenState();
}

class _ConectarBikeScreenState extends ConsumerState<ConectarBikeScreen> {
  StreamSubscription<List<FoundDevice>>? _sub;
  List<FoundDevice> _devices = const [];
  bool _scanning = false;
  bool _showAll = false;
  String? _problem;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    await _sub?.cancel();
    setState(() {
      _problem = null;
      _devices = const [];
      _scanning = true;
    });
    final scanner = ref.read(bikeScannerProvider);
    final problem = await scanner.check();
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _problem = bleProblemText(problem);
        _scanning = false;
      });
      return;
    }
    _sub = scanner.scan().listen(
      (lista) => setState(() => _devices = lista),
      onError: (Object e) => setState(() => _problem = 'Não consegui procurar: $e'),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _connect(FoundDevice d) async {
    await _sub?.cancel();
    setState(() {
      _scanning = false;
      _connectingId = d.id;
    });
    await ref.read(bikeControllerProvider.notifier).useDevice(d.id, d.name);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ref.read(bikeControllerProvider).connected) context.pop();
  }

  Future<void> _useSimulated() async {
    await _sub?.cancel();
    await ref.read(bikeControllerProvider.notifier).useSimulated();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(bikeControllerProvider);
    final visible = _showAll ? _devices : _devices.where((d) => d.likelyBike).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar bike')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (bike.connected) ...[
            AppCard(
              color: AppColors.destaqueSuave,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.destaque),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${bike.source!.name} conectada', style: AppText.corpoForte)),
                  TextButton(
                    onPressed: () => ref.read(bikeControllerProvider.notifier).disconnect(),
                    child: const Text('Desconectar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_problem != null) ...[
            _Aviso(texto: _problem!),
            const SizedBox(height: 12),
          ],
          if (bike.message != null) ...[
            _Aviso(texto: bike.message!),
            const SizedBox(height: 12),
          ],
          if (bike.diagnostic != null) ...[
            AppCard(
              child: SelectableText(bike.diagnostic!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: Text(_showAll ? 'Aparelhos por perto' : 'Bikes encontradas', style: AppText.secao)),
              if (_scanning)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                TextButton(onPressed: _scan, child: const Text('Procurar de novo')),
            ],
          ),
          const SizedBox(height: 8),
          for (final d in visible) ...[
            AppCard(
              onTap: _connectingId == null ? () => _connect(d) : null,
              child: Row(
                children: [
                  Icon(d.likelyBike ? Icons.directions_bike : Icons.bluetooth, color: AppColors.destaque),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: AppText.corpoForte),
                        Text(d.likelyBike ? 'Parece uma bike' : 'Outro aparelho', style: AppText.suave),
                      ],
                    ),
                  ),
                  if (_connectingId == d.id)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  else
                    const Icon(Icons.chevron_right, color: AppColors.textoSuave),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (visible.isEmpty && !_scanning && _problem == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma bike apareceu. Ligue a bike, pedale um pouco para o painel acordar e feche o app FitShow. '
                'Se não resolver, tire e recoloque as pilhas do painel.',
                style: AppText.suave,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar todos os aparelhos'),
            value: _showAll,
            onChanged: (v) => setState(() => _showAll = v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _useSimulated,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Usar bike simulada'),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(16)),
      child: Text(texto, style: const TextStyle(color: AppColors.avisoTexto, fontWeight: FontWeight.w600)),
    );
  }
}
```

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
            const _Opcao(icon: Icons.bar_chart_rounded, titulo: 'Pedal livre', texto: 'Só os dados da bike, sem mapa', selecionada: true),
            const _Opcao(icon: Icons.map_outlined, titulo: 'Seguir uma rota', texto: 'Chega na próxima etapa', emBreve: true),
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
              label: Text(bike.connected ? 'Começar' : 'Conectar a bike'),
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(bike.connected ? '/pedal-livre' : '/bike');
              },
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
  });

  final IconData icon;
  final String titulo;
  final String texto;
  final bool selecionada;
  final bool emBreve;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: emBreve ? 0.6 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selecionada ? const Color(0xFFF3FAF6) : AppColors.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selecionada ? AppColors.destaque : AppColors.borda,
              width: selecionada ? 2.5 : 1.5,
            ),
          ),
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
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implementar as abas (Início, Explorar, Treinos, Você, Ajustes)**

<!-- file: app/lib/features/pedal_livre/pedal_livre_card.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/theme/app_theme.dart';

/// Cartão escuro de destaque: abre o pedal livre (ou a conexão, se não houver bike).
class PedalLivreCard extends ConsumerWidget {
  const PedalLivreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(bikeControllerProvider.select((s) => s.connected));
    return Material(
      color: AppColors.escuro,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(connected ? '/pedal-livre' : '/bike'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFF2A3832), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF7FD9A8)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pedal livre', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Só os dados da bike, no seu ritmo', style: TextStyle(color: Color(0xFFB9C6BF), fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
```

<!-- file: app/lib/features/voce/ride_tile.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/rides_store.dart';

class RideTile extends StatelessWidget {
  const RideTile({super.key, required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context) {
    final titulo = ride.completed ? rideModeLabel(ride.mode) : '${rideModeLabel(ride.mode)} · incompleto';
    return AppCard(
      onTap: () => context.push('/resumo/${ride.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.destaqueSuave, borderRadius: BorderRadius.circular(14)),
            child: Icon(
              ride.mode == RideMode.livre ? Icons.bar_chart_rounded : Icons.map_outlined,
              color: AppColors.destaqueTexto,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.corpoForte),
                const SizedBox(height: 2),
                Text(
                  '${formatDateTime(ride.startedAt)} · ${formatKm(ride.distanceM)} · ${formatTime(ride.movingTimeS)}',
                  style: AppText.suave,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textoSuave),
        ],
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
              icon: Icons.map_outlined,
              titulo: 'Rotas do seu bairro',
              texto: 'Criar, gerar e pedalar rotas chega na próxima etapa.',
            ),
            const SizedBox(height: 14),
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
```

<!-- file: app/lib/features/explorar/explorar_screen.dart -->
```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class ExplorarScreen extends StatelessWidget {
  const ExplorarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Explorar', style: AppText.titulo),
              SizedBox(height: 16),
              AppCard(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: AppColors.destaque),
                    SizedBox(height: 12),
                    Text(
                      'Rotas do seu bairro',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Na próxima etapa você vai criar rotas no mapa, gerar voltas de 5, 10 ou 20 km '
                      'saindo de casa e ver todas as suas rotas aqui.',
                      textAlign: TextAlign.center,
                      style: AppText.suave,
                    ),
                    SizedBox(height: 12),
                    EmBreveTag(),
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

<!-- file: app/lib/features/treinos/treinos_screen.dart -->
```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../pedal_livre/pedal_livre_card.dart';

class TreinosScreen extends StatelessWidget {
  const TreinosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: const [
            Text('Treinos', style: AppText.titulo),
            SizedBox(height: 16),
            PedalLivreCard(),
            SizedBox(height: 20),
            SectionTitle('Sessões rápidas'),
            EmBreveCard(icon: Icons.timer_outlined, titulo: 'Intervalos 5 × 1 min', texto: '20 min · moderado'),
            SizedBox(height: 10),
            EmBreveCard(icon: Icons.speed, titulo: 'Cadência alta', texto: '15 min · leve, acima de 95 rpm'),
            SizedBox(height: 10),
            EmBreveCard(icon: Icons.terrain_outlined, titulo: 'Subida longa simulada', texto: '30 min · difícil, 4% a 8%'),
            SizedBox(height: 20),
            SectionTitle('Ajustar o app à sua bike'),
            EmBreveCard(
              icon: Icons.tune,
              titulo: 'Teste de calibração',
              texto: 'Por enquanto, ajuste a calibração em Você › Ajustes.',
            ),
            SizedBox(height: 20),
            SectionTitle('Planos'),
            EmBreveCard(icon: Icons.event_note_outlined, titulo: 'Iniciante · 4 semanas', texto: '3 pedais por semana, de 20 a 40 min'),
          ],
        ),
      ),
    );
  }
}
```

<!-- file: app/lib/features/voce/voce_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bike/bike_controller.dart';
import '../../core/format/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import 'ride_tile.dart';

class VoceScreen extends ConsumerWidget {
  const VoceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bike = ref.watch(bikeControllerProvider);
    final rides = ref.watch(recentRidesProvider);
    final detalhe = settings.when(
      data: (s) => '${formatNumber(s.pesoKg)} kg · ${bike.connected ? bike.source!.name : 'sem bike conectada'}',
      loading: () => '',
      error: (e, st) => '',
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(color: AppColors.destaqueSuave, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, size: 30, color: AppColors.destaqueTexto),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Você', style: AppText.titulo),
                      Text(detalhe, style: AppText.subtitulo),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/ajustes'),
              icon: const Icon(Icons.tune),
              label: const Text('Ajustes'),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Histórico'),
            ...rides.when(
              data: (lista) => lista.isEmpty
                  ? const [Text('Nenhum pedal ainda. Que tal um pedal livre?', style: AppText.suave)]
                  : [
                      for (final r in lista) ...[RideTile(ride: r), const SizedBox(height: 10)],
                    ],
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (e, st) => [Text('Não consegui ler o histórico: $e', style: AppText.suave)],
            ),
          ],
        ),
      ),
    );
  }
}
```

<!-- file: app/lib/features/voce/ajustes_screen.dart -->
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/power.dart';

class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _peso = TextEditingController();
  final _meta = TextEditingController();
  final _base = TextEditingController();
  final _fator = TextEditingController();
  AppSettings? _settings;
  PowerMode _modo = PowerMode.auto;
  double _carga = 4;

  @override
  void initState() {
    super.initState();
    ref.read(settingsStoreProvider).load().then((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _peso.text = s.pesoKg.round().toString();
        _meta.text = s.metaSemanalKm.round().toString();
        _base.text = s.base.toString();
        _fator.text = s.fator.toString();
        _modo = s.modoPotencia;
        _carga = s.cargaPadrao.toDouble();
      });
    });
  }

  @override
  void dispose() {
    _peso.dispose();
    _meta.dispose();
    _base.dispose();
    _fator.dispose();
    super.dispose();
  }

  double? _numero(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _salvar() async {
    final s = _settings!;
    final novo = s.copyWith(
      pesoKg: _numero(_peso)?.clamp(30, 200).toDouble(),
      metaSemanalKm: _numero(_meta)?.clamp(1, 1000).toDouble(),
      base: _numero(_base)?.clamp(0, 5).toDouble(),
      fator: _numero(_fator)?.clamp(0, 5).toDouble(),
      modoPotencia: _modo,
      cargaPadrao: _carga.round(),
    );
    await ref.read(settingsStoreProvider).save(novo);
    ref.invalidate(settingsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes salvos')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    const numeroTeclado = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                TextField(
                  controller: _peso,
                  keyboardType: numeroTeclado,
                  decoration: const InputDecoration(labelText: 'Seu peso (kg)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _meta,
                  keyboardType: numeroTeclado,
                  decoration: const InputDecoration(labelText: 'Meta semanal (km)'),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Potência'),
                SegmentedButton<PowerMode>(
                  segments: const [
                    ButtonSegment(value: PowerMode.auto, label: Text('Automática')),
                    ButtonSegment(value: PowerMode.bike, label: Text('Da bike')),
                    ButtonSegment(value: PowerMode.estimada, label: Text('Estimada')),
                  ],
                  selected: {_modo},
                  onSelectionChanged: (v) => setState(() => _modo = v.first),
                ),
                const SizedBox(height: 20),
                Text('Carga inicial no botão da bike: ${_carga.round()}', style: AppText.corpoForte),
                Slider(
                  value: _carga,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_carga.round()}',
                  onChanged: (v) => setState(() => _carga = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Calibração da estimativa: potência = RPM × (base + fator × carga)',
                  style: AppText.suave,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _base,
                        keyboardType: numeroTeclado,
                        decoration: const InputDecoration(labelText: 'Base'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fator,
                        keyboardType: numeroTeclado,
                        decoration: const InputDecoration(labelText: 'Fator'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                FilledButton(onPressed: _salvar, child: const Text('Salvar')),
                const SizedBox(height: 12),
                const Text(
                  'Integrações (Strava, Health Connect) e tema escuro chegam nas próximas versões.',
                  style: AppText.suave,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Center(child: EmBreveTag()),
                const SizedBox(height: 8),
                const Text('Os ajustes valem a partir do próximo pedal.', style: AppText.suave),
              ],
            ),
    );
  }
}
```

- [ ] **Step 6: Implementar o pedal livre e o resumo**

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
import 'free_ride_controller.dart';

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
    Future.microtask(() => ref.read(freeRideProvider.notifier).start());
  }

  Future<void> _encerrar() async {
    if (_encerrando) return;
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
    if (ok != true || !mounted) return;
    setState(() => _encerrando = true);
    final id = await ref.read(freeRideProvider.notifier).finish();
    if (!mounted) return;
    context.go('/resumo/$id');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(freeRideProvider);
    final bike = ref.watch(bikeControllerProvider);
    final source = bike.source;
    final ctrl = ref.read(freeRideProvider.notifier);
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
                  _Faixa(
                    texto: bike.message ?? 'A bike desconectou. Tentando reconectar…',
                    acao: 'Reconectar',
                    onAcao: () => ref.read(bikeControllerProvider.notifier).reconnectNow(),
                  )
                else if (v.estimating)
                  const _Faixa(texto: 'A bike não manda potência: estimando pela carga.'),
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
                if (source is SimSource) ...[
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: source.easier, child: const Text('Simular: mais fraco'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: source.harder, child: const Text('Simular: mais forte'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
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
                              onPressed: () => ctrl.changeLevel(-1),
                              icon: const Icon(Icons.remove),
                            ),
                            Text('Carga ${v.level}', style: AppText.corpoForte),
                            IconButton.filledTonal(
                              tooltip: 'Aumentar carga',
                              onPressed: () => ctrl.changeLevel(1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.escuro, minimumSize: const Size(120, 60)),
                      onPressed: v.started ? ctrl.togglePause : null,
                      child: Text(v.state == RideState.pausado ? 'Continuar' : 'Pausar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.texto, this.acao, this.onAcao});

  final String texto;
  final String? acao;
  final VoidCallback? onAcao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: AppColors.avisoFundo, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
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

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context) {
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
                  Text(ride.completed ? 'Pedal concluído!' : 'Pedal salvo', style: AppText.titulo.copyWith(fontSize: 24)),
                  Text('${rideModeLabel(ride.mode)} · ${formatDateTime(ride.startedAt)}', style: AppText.subtitulo),
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
              child: OutlinedButton(onPressed: null, child: Text('Enviar ao Strava · em breve')),
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

- [ ] **Step 7: Rodar todos os testes e a análise**

Run: `cd /c/dev/pedal-local/app && dart fix --apply && flutter analyze && flutter test`
Expected: `dart fix` só acrescenta `const` onde o lint pede; `No issues found!` e `All tests passed!` (todos os testes das Tasks 2–10)

- [ ] **Step 8: Commit**

```bash
cd /c/dev/pedal-local && git add app/lib app/test/widget && git commit -m "feat(app): telas com 5 abas, conexão da bike, pedal livre e resumo"
```

---

### Task 11: Instalar no celular e testar com a bike

**Files:** nenhum novo.

- [ ] **Step 1: Compilar e instalar no SM-G780G**

```bash
cd /c/dev/pedal-local/app && flutter build apk --debug && /c/dev/android-sdk/platform-tools/adb.exe -s RQ8R905CDWJ install -r build/app/outputs/flutter-apk/app-debug.apk && /c/dev/android-sdk/platform-tools/adb.exe -s RQ8R905CDWJ shell monkey -p com.pedallocal.app -c android.intent.category.LAUNCHER 1
```
Expected: `Success` e o app abre na aba Início.

- [ ] **Step 2: Roteiro com a bike simulada (feito pelo agente via adb + capturas de tela)**

1. Início mostra “Bora pedalar?”, chip “Sem bike” e o cartão “Conecte sua bike”.
2. Botão central → folha “Como vai ser hoje?” → “Conectar a bike” → tela de conexão pede permissão de Bluetooth.
3. “Usar bike simulada” → volta ao Início com chip “Bike simulada”.
4. Botão central → Começar → Pedal livre: números mudam a cada segundo, gráfico desenha, “Simular: mais forte” aumenta watts e velocidade, Pausar/Continuar funciona.
5. Encerrar → confirmar → Resumo com km, tempo e gráfico → Concluir → Início mostra “Último pedal”.
6. Você → Histórico lista o pedal; Ajustes salva peso 82 e reabre com 82.

- [ ] **Step 3: Roteiro com a Winnek SYNC (feito pelo usuário)**

1. Painel com pilhas boas, bike acordada, app FitShow fechado.
2. Conectar bike → a Winnek aparece como “Parece uma bike” → tocar → volta ao Início com o nome dela.
3. Pedal livre por alguns minutos: RPM igual ao do painel; aparece a faixa “estimando pela carga” depois de ~10 s; ajustar Carga para o número do botão da bike.
4. Fechar e reabrir o app: o chip mostra a bike reconectada sozinha.

- [ ] **Step 4: Enviar ao GitHub**

```bash
cd /c/dev/pedal-local && git push origin main
```
Expected: push sem erro.

---

## Notas da execução (2026-10-07)

- `google_fonts` fixado em **8.0.0**: a 9.x usa o pacote separado `material_ui`, cujo `TextTheme` é de outro tipo e não entra no `ThemeData` do Flutter.
- `dart fix` trocou `power!` por `power` (o Dart 3.13 já promove) e usou elementos nulos-condicionais (`?valor`) no `toMap` dos ajustes.
- Novo teste `app/test/widget/fluxo_test.dart` (celular de 360 × 690 dp): percorre as abas e faz um pedal livre completo com bike falsa. Ele achou três defeitos de layout, corrigidos:
  - Barra de abas: itens com altura fixa estouravam com fonte maior → altura mínima 56 px, cada item em `Expanded` (1/5 da largura), rótulo com `FittedBox`.
  - Botão central dentro de `Center` esticava a barra até a altura da tela → `Center(heightFactor: 1)`.
  - Controle de carga no pedal livre estourava 41 px → texto em `Expanded` + `FittedBox`, botão Pausar com 104 px mínimos; `MetricTile` encolhe o número em vez de quebrar linha.
- Resultado: `flutter analyze` sem avisos, **70 testes passando**, APK de debug compilando.

### Tarefa 11 — no celular (2026-10-08)

- Instalado no SM-G780G; roteiro com a bike simulada completo (início, folha de escolha, conexão, pedal livre, mais forte, pausar/continuar, encerrar, resumo, histórico, ajustes).
- Correções vindas do teste no aparelho: conferência real da permissão de Bluetooth (`hasPermissions`) e nova busca ao voltar ao app; faixa “Pedal pausado”; textos que quebravam linha (simulação, Strava, “Automática”); calibração exibida com vírgula; SnackBar flutuante.
- Dados de teste apagados (`pm clear`), o que também zerou as permissões: o usuário concede a permissão de “dispositivos por perto” ao conectar a Winnek.
- Pendente: roteiro com a Winnek SYNC (Step 3), feito pelo usuário.
