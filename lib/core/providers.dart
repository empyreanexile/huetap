// Global Riverpod providers for HueTap's core singletons.
//
// SPEC §4.1 mandates Riverpod for state management. These providers are the
// composition root: features read them to access the database, the creds
// store, the bridge client registry, and the discovery / pairing services.
//
// On first app launch after boot, [bridgeClientsBootstrapProvider] rehydrates
// the registry from Drift + the credentials JSON so every paired bridge has
// a ready-armed BridgeClient.

import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'net/bridge_client.dart';
import 'net/bridge_discovery_service.dart';
import 'net/bridge_pairing_service.dart';
import 'net/bridge_pinning_adapter.dart';
import 'secrets/bridge_credentials_store.dart';

/// Drift database (lazy-opened).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Per-device bridge credentials JSON store (SPEC §6.4).
final bridgeCredentialsStoreProvider = Provider<BridgeCredentialsStore>((ref) {
  return BridgeCredentialsStore();
});

/// Single registry for all BridgeClients.
final bridgeClientRegistryProvider = Provider<BridgeClientRegistry>((ref) {
  return BridgeClientRegistry();
});

/// Streams `Bridges` rows; the UI watches this for the paired-bridges list.
final pairedBridgesProvider = StreamProvider<List<Bridge>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.bridges).watch();
});

/// Streams `CardBindings` rows.
final cardBindingsProvider = StreamProvider<List<CardBinding>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.cardBindings,
  )..where((t) => t.revoked.equals(false))).watch();
});

/// Streams `Scenes` rows for one bridge row.
final scenesForBridgeProvider = StreamProvider.family<List<Scene>, int>((
  ref,
  bridgeRowId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.scenes)
        ..where(
          (t) => t.bridgeRowId.equals(bridgeRowId) & t.orphaned.equals(false),
        )
        ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
      .watch();
});

/// mDNS discovery — instantiated fresh for each flow (no shared state).
final bridgeDiscoveryServiceProvider = Provider<BridgeDiscoveryService>((ref) {
  return BridgeDiscoveryService();
});

/// Boots the registry: for every paired bridge with valid credentials,
/// builds a BridgeClient and registers it. Runs once on first `ref.watch`.
final bridgeClientsBootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  final creds = ref.watch(bridgeCredentialsStoreProvider);
  final registry = ref.watch(bridgeClientRegistryProvider);

  final rows = await db.select(db.bridges).get();
  final credMap = await creds.loadAllCredentials();

  for (final row in rows) {
    if (registry.byRowId(row.id) != null) continue; // already armed
    final c = credMap[row.bridgeId];
    if (c == null) continue; // needs re-pair (SPEC §5.9); UI handles this
    registry.register(
      BridgeClient(
        bridgeRowId: row.id,
        bridgeId: row.bridgeId,
        ip: row.ip,
        applicationKey: c.applicationKey,
        certFingerprintSha256: c.certFingerprintSha256,
      ),
    );
  }
});

/// Orchestrates the pairing flow from "user picked an IP" to
/// "BridgeClient is armed, Drift + creds are persisted, scenes are synced."
class PairingCoordinator {
  PairingCoordinator({
    required AppDatabase database,
    required BridgeCredentialsStore credentialsStore,
    required BridgeClientRegistry registry,
  }) : _db = database,
       _creds = credentialsStore,
       _registry = registry;

  final AppDatabase _db;
  final BridgeCredentialsStore _creds;
  final BridgeClientRegistry _registry;

  /// Run the full pair flow against `ip`. Returns the newly registered client.
  Future<BridgeClient> pair(String ip) async {
    final adapter = BridgePinningAdapter();
    final svc = BridgePairingService(adapter: adapter);
    final result = await svc.pair(ip);

    // Persist creds first; if the Drift insert blows up we still have the key
    // saved and can recover, but if we inserted the Bridge row first we'd
    // risk orphaned DB state.
    await _creds.storeCredentials(
      result.bridgeId,
      BridgeCredentials(
        applicationKey: result.applicationKey,
        certFingerprintSha256: result.certFingerprintSha256,
      ),
    );

    final now = DateTime.now();
    // Upsert by bridgeId (re-pair of same physical bridge updates row).
    final existing = await (_db.select(
      _db.bridges,
    )..where((t) => t.bridgeId.equals(result.bridgeId))).getSingleOrNull();
    late final int rowId;
    if (existing == null) {
      rowId = await _db
          .into(_db.bridges)
          .insert(
            BridgesCompanion.insert(
              ip: result.ip,
              bridgeId: result.bridgeId,
              name: drift.Value(result.name),
              pairedAt: now,
              lastReachable: drift.Value(now),
            ),
          );
    } else {
      rowId = existing.id;
      await (_db.update(_db.bridges)..where((t) => t.id.equals(rowId))).write(
        BridgesCompanion(
          ip: drift.Value(result.ip),
          name: drift.Value(result.name),
          lastReachable: drift.Value(now),
        ),
      );
    }

    // Build + register the armed client.
    _registry.unregister(rowId);
    final client = BridgeClient(
      bridgeRowId: rowId,
      bridgeId: result.bridgeId,
      ip: result.ip,
      applicationKey: result.applicationKey,
      certFingerprintSha256: result.certFingerprintSha256,
    );
    _registry.register(client);

    // Pull scenes in the background — don't block pairing success on it.
    unawaited(_syncScenes(client));
    return client;
  }

  Future<void> _syncScenes(BridgeClient client) async {
    try {
      final scenes = await client.api.listScenes();
      final now = DateTime.now();
      await _db.transaction(() async {
        // Mark existing scenes orphaned; reset on reappear.
        await (_db.update(_db.scenes)
              ..where((t) => t.bridgeRowId.equals(client.bridgeRowId)))
            .write(const ScenesCompanion(orphaned: drift.Value(true)));
        for (final s in scenes) {
          await _db
              .into(_db.scenes)
              .insertOnConflictUpdate(
                ScenesCompanion.insert(
                  id: s.id,
                  bridgeRowId: client.bridgeRowId,
                  name: s.name,
                  roomId: drift.Value(s.roomId),
                  roomName: drift.Value(s.roomName),
                  zoneId: drift.Value(s.zoneId),
                  zoneName: drift.Value(s.zoneName),
                  orphaned: const drift.Value(false),
                  lastSynced: now,
                ),
              );
        }
      });
    } catch (_) {
      // Scene sync failures aren't fatal for pairing — user can pull-to-refresh.
    }
  }
}

final pairingCoordinatorProvider = Provider<PairingCoordinator>((ref) {
  return PairingCoordinator(
    database: ref.watch(databaseProvider),
    credentialsStore: ref.watch(bridgeCredentialsStoreProvider),
    registry: ref.watch(bridgeClientRegistryProvider),
  );
});
