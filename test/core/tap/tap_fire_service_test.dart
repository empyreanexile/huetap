// Unit tests for TapFireService's failure paths — the ones that don't
// require a real bridge on the network.
//
// Happy path (successful fireScene) needs a stubbed HueApiClient talking to
// a fake TLS server; that coverage lives in the on-device integration test
// and in bridge_pairing_service_test.dart's infrastructure.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/core/db/database.dart';
import 'package:huetap/core/net/bridge_client.dart';
import 'package:huetap/core/providers.dart';
import 'package:huetap/core/tap/tap_fire_service.dart';

void main() {
  late AppDatabase db;
  late BridgeClientRegistry registry;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    registry = BridgeClientRegistry();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      bridgeClientRegistryProvider.overrideWithValue(registry),
      // Short-circuit the bootstrap provider so fire() doesn't try to load
      // credentials from disk during the test.
      bridgeClientsBootstrapProvider.overrideWith((ref) async {}),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('unknown UUID → failure outcome and tapLog failure row', () async {
    final service = container.read(tapFireServiceProvider);

    final outcome = await service.fire('not-a-real-uuid');

    expect(outcome, isA<TapFireFailure>());
    expect((outcome as TapFireFailure).message, equals('Unknown card'));

    final logs = await db.select(db.tapLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.success, isFalse);
    expect(logs.single.errorType, 'UnknownCard');
    expect(logs.single.cardUuid, 'not-a-real-uuid');
  });

  test('bridge missing from registry → failure + tapLog', () async {
    // Seed a bridge row + a binding, but DON'T register a BridgeClient.
    final now = DateTime.now();
    final bridgeRowId = await db.into(db.bridges).insert(BridgesCompanion.insert(
          ip: '192.0.2.10',
          bridgeId: 'abcd-1234',
          pairedAt: now,
        ));
    await db.into(db.scenes).insert(ScenesCompanion.insert(
          id: 'scene-1',
          bridgeRowId: bridgeRowId,
          name: 'Cozy Reading',
          lastSynced: now,
        ));
    await db.into(db.cardBindings).insert(CardBindingsCompanion.insert(
          uuid: 'uuid-1',
          label: 'Test card',
          bridgeRowId: bridgeRowId,
          sceneId: 'scene-1',
          createdAt: now,
        ));

    final outcome = await container.read(tapFireServiceProvider).fire('uuid-1');

    expect(outcome, isA<TapFireFailure>());
    expect((outcome as TapFireFailure).message, contains('Bridge not armed'));

    final logs = await db.select(db.tapLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.errorType, 'BridgeNotArmed');
    expect(logs.single.cardUuid, 'uuid-1');
    expect(logs.single.bridgeRowId, bridgeRowId);
  });

  test('orphaned scene → failure + tapLog', () async {
    final now = DateTime.now();
    final bridgeRowId = await db.into(db.bridges).insert(BridgesCompanion.insert(
          ip: '192.0.2.10',
          bridgeId: 'abcd-1234',
          pairedAt: now,
        ));
    await db.into(db.scenes).insert(ScenesCompanion.insert(
          id: 'scene-1',
          bridgeRowId: bridgeRowId,
          name: 'Deleted Scene',
          orphaned: const drift.Value(true),
          lastSynced: now,
        ));
    await db.into(db.cardBindings).insert(CardBindingsCompanion.insert(
          uuid: 'uuid-1',
          label: 'Test card',
          bridgeRowId: bridgeRowId,
          sceneId: 'scene-1',
          createdAt: now,
        ));
    // Register a dummy client so the registry lookup passes and we fall
    // through to the scene check.
    registry.register(BridgeClient(
      bridgeRowId: bridgeRowId,
      bridgeId: 'abcd-1234',
      ip: '192.0.2.10',
      applicationKey: 'k',
      certFingerprintSha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
    ));

    final outcome = await container.read(tapFireServiceProvider).fire('uuid-1');

    expect(outcome, isA<TapFireFailure>());
    expect((outcome as TapFireFailure).message, contains('deleted'));

    final logs = await db.select(db.tapLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.errorType, 'SceneOrphaned');
  });

  test('revoked binding → treated as unknown', () async {
    final now = DateTime.now();
    final bridgeRowId = await db.into(db.bridges).insert(BridgesCompanion.insert(
          ip: '192.0.2.10',
          bridgeId: 'abcd-1234',
          pairedAt: now,
        ));
    await db.into(db.scenes).insert(ScenesCompanion.insert(
          id: 'scene-1',
          bridgeRowId: bridgeRowId,
          name: 'Scene',
          lastSynced: now,
        ));
    await db.into(db.cardBindings).insert(CardBindingsCompanion.insert(
          uuid: 'revoked-uuid',
          label: 'Old card',
          bridgeRowId: bridgeRowId,
          sceneId: 'scene-1',
          revoked: const drift.Value(true),
          createdAt: now,
        ));

    final outcome =
        await container.read(tapFireServiceProvider).fire('revoked-uuid');

    expect(outcome, isA<TapFireFailure>());
    expect((outcome as TapFireFailure).message, 'Unknown card');
  });
}
