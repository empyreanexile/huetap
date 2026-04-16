// Fire path for a tapped NFC card.
//
// Centralizes the DB lookup → registry lookup → scene fire → DB writes
// sequence in one place so both the foreground `TapHandler` (user is inside
// the app) and the intent-dispatch path (Android opened the app from a tap)
// share identical behavior.
//
// On failure the service logs to `tap_logs` (so the user can see misses in
// the History screen later) and returns a `TapFireOutcome.failure` — it
// never throws. Callers pick their UX: a toast from the foreground path, a
// silent close from the intent path.

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers.dart';

/// Result of a single tap → fire attempt.
sealed class TapFireOutcome {
  const TapFireOutcome();
  const factory TapFireOutcome.success({required String sceneName}) =
      TapFireSuccess;
  const factory TapFireOutcome.failure(String message) = TapFireFailure;
}

class TapFireSuccess extends TapFireOutcome {
  const TapFireSuccess({required this.sceneName});
  final String sceneName;
}

class TapFireFailure extends TapFireOutcome {
  const TapFireFailure(this.message);
  final String message;
}

class TapFireService {
  TapFireService(this._ref);

  final Ref _ref;

  /// Resolve `uuid` to its binding, fire the bound scene, and record the
  /// attempt in `tap_logs`. Never throws.
  Future<TapFireOutcome> fire(String uuid) async {
    // Cold-start dispatch races the registry bootstrap — await it before we
    // try to look up a BridgeClient or we'll always miss on the first tap
    // after boot. The foreground path already has the registry hydrated, so
    // this completes synchronously there.
    try {
      await _ref.read(bridgeClientsBootstrapProvider.future);
    } catch (_) {
      // Bootstrap failures are non-fatal — registry may still have clients
      // from a previous run; fall through and let the lookup fail cleanly.
    }

    final db = _ref.read(databaseProvider);
    final registry = _ref.read(bridgeClientRegistryProvider);

    // Phase 1: DB + registry lookup. No network here — failures are fast.
    final binding =
        await (db.select(db.cardBindings)
              ..where((t) => t.uuid.equals(uuid) & t.revoked.equals(false)))
            .getSingleOrNull();
    if (binding == null) {
      await _logFailure(
        db,
        cardUuid: uuid,
        errorType: 'UnknownCard',
        errorMessage: 'No active binding for UUID.',
      );
      return const TapFireOutcome.failure('Unknown card');
    }

    final client = registry.byRowId(binding.bridgeRowId);
    if (client == null) {
      await _logFailure(
        db,
        bridgeRowId: binding.bridgeRowId,
        cardUuid: binding.uuid,
        cardLabel: binding.label,
        sceneId: binding.sceneId,
        errorType: 'BridgeNotArmed',
        errorMessage:
            'No BridgeClient registered for row ${binding.bridgeRowId}.',
      );
      return const TapFireOutcome.failure('Bridge not armed. Re-pair?');
    }

    final scene =
        await (db.select(db.scenes)..where(
              (t) =>
                  t.id.equals(binding.sceneId) &
                  t.bridgeRowId.equals(binding.bridgeRowId),
            ))
            .getSingleOrNull();
    if (scene == null || scene.orphaned) {
      await _logFailure(
        db,
        bridgeRowId: binding.bridgeRowId,
        cardUuid: binding.uuid,
        cardLabel: binding.label,
        sceneId: binding.sceneId,
        errorType: 'SceneOrphaned',
        errorMessage: scene == null
            ? 'Scene row missing.'
            : 'Scene marked orphaned.',
      );
      return const TapFireOutcome.failure('Scene was deleted on the bridge');
    }

    // Phase 2: hit the bridge.
    try {
      await client.runExclusive(() => client.api.fireScene(binding.sceneId));

      await (db.update(
        db.cardBindings,
      )..where((t) => t.uuid.equals(binding.uuid))).write(
        CardBindingsCompanion(
          lastTapped: Value(DateTime.now()),
          tapCount: Value(binding.tapCount + 1),
        ),
      );
      await db
          .into(db.tapLogs)
          .insert(
            TapLogsCompanion.insert(
              bridgeRowId: Value(binding.bridgeRowId),
              cardUuid: Value(binding.uuid),
              cardLabel: Value(binding.label),
              sceneId: Value(binding.sceneId),
              sceneName: Value(scene.name),
              success: true,
              timestamp: DateTime.now(),
            ),
          );

      return TapFireOutcome.success(sceneName: scene.name);
    } catch (e) {
      await _logFailure(
        db,
        bridgeRowId: binding.bridgeRowId,
        cardUuid: binding.uuid,
        cardLabel: binding.label,
        sceneId: binding.sceneId,
        sceneName: scene.name,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
      );
      return TapFireOutcome.failure('Tap failed: $e');
    }
  }

  /// Manually fire a scene on a paired bridge (e.g. the "Fire now" test
  /// button in the scenes screen). Goes through the same registry + mutex +
  /// logging path as a tap so `tap_logs` stays complete (SPEC §5.8).
  Future<TapFireOutcome> fireDirect({
    required int bridgeRowId,
    required String sceneId,
  }) async {
    final db = _ref.read(databaseProvider);
    final registry = _ref.read(bridgeClientRegistryProvider);

    final client = registry.byRowId(bridgeRowId);
    if (client == null) {
      await _logFailure(
        db,
        bridgeRowId: bridgeRowId,
        sceneId: sceneId,
        errorType: 'BridgeNotArmed',
        errorMessage: 'No BridgeClient registered for row $bridgeRowId.',
      );
      return const TapFireOutcome.failure('Bridge not armed. Re-pair?');
    }

    final scene =
        await (db.select(db.scenes)..where(
              (t) => t.id.equals(sceneId) & t.bridgeRowId.equals(bridgeRowId),
            ))
            .getSingleOrNull();

    try {
      await client.runExclusive(() => client.api.fireScene(sceneId));
      await db
          .into(db.tapLogs)
          .insert(
            TapLogsCompanion.insert(
              bridgeRowId: Value(bridgeRowId),
              sceneId: Value(sceneId),
              sceneName: Value(scene?.name),
              success: true,
              timestamp: DateTime.now(),
            ),
          );
      return TapFireOutcome.success(sceneName: scene?.name ?? sceneId);
    } catch (e) {
      await _logFailure(
        db,
        bridgeRowId: bridgeRowId,
        sceneId: sceneId,
        sceneName: scene?.name,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
      );
      return TapFireOutcome.failure('Failed: $e');
    }
  }

  Future<void> _logFailure(
    AppDatabase db, {
    int? bridgeRowId,
    String? cardUuid,
    String? cardLabel,
    String? sceneId,
    String? sceneName,
    required String errorType,
    required String errorMessage,
  }) async {
    await db
        .into(db.tapLogs)
        .insert(
          TapLogsCompanion.insert(
            bridgeRowId: Value(bridgeRowId),
            cardUuid: Value(cardUuid),
            cardLabel: Value(cardLabel),
            sceneId: Value(sceneId),
            sceneName: Value(sceneName),
            success: false,
            errorType: Value(errorType),
            errorMessage: Value(errorMessage),
            timestamp: DateTime.now(),
          ),
        );
  }
}

final tapFireServiceProvider = Provider<TapFireService>((ref) {
  return TapFireService(ref);
});
