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
