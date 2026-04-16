// Unit tests for BridgeCredentialsStore.
//
// Uses the `baseDirOverride` test hook so nothing touches
// `getApplicationSupportDirectory()` — each test gets a fresh temp dir that
// is deleted in tearDown.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/core/secrets/bridge_credentials_store.dart';

void main() {
  late Directory tempDir;
  late BridgeCredentialsStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('huetap_creds_test_');
    store = BridgeCredentialsStore(baseDirOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loadAllCredentials returns empty map when file is missing', () async {
    final result = await store.loadAllCredentials();
    expect(result, isEmpty);
  });

  test('loadCredentials returns null for unknown bridge', () async {
    final result = await store.loadCredentials('nope');
    expect(result, isNull);
  });

  test('store then load roundtrip', () async {
    const creds = BridgeCredentials(
      applicationKey: 'abc-key',
      certFingerprintSha256: 'deadbeef',
    );
    await store.storeCredentials('bridge-1', creds);

    final loaded = await store.loadCredentials('bridge-1');
    expect(loaded, equals(creds));
  });

  test('storeCredentials overwrites existing entry', () async {
    await store.storeCredentials(
      'bridge-1',
      const BridgeCredentials(
        applicationKey: 'old',
        certFingerprintSha256: 'old-fp',
      ),
    );
    await store.storeCredentials(
      'bridge-1',
      const BridgeCredentials(
        applicationKey: 'new',
        certFingerprintSha256: 'new-fp',
      ),
    );

    final loaded = await store.loadCredentials('bridge-1');
    expect(loaded?.applicationKey, 'new');
    expect(loaded?.certFingerprintSha256, 'new-fp');
  });

  test('removeCredentials drops a single entry but keeps others', () async {
    await store.storeCredentials(
      'bridge-1',
      const BridgeCredentials(
        applicationKey: 'k1',
        certFingerprintSha256: 'fp1',
      ),
    );
    await store.storeCredentials(
      'bridge-2',
      const BridgeCredentials(
        applicationKey: 'k2',
        certFingerprintSha256: 'fp2',
      ),
    );

    await store.removeCredentials('bridge-1');

    final all = await store.loadAllCredentials();
    expect(all.keys, ['bridge-2']);
    expect(all['bridge-2']?.applicationKey, 'k2');
  });

  test('on-disk JSON matches SPEC §6.4 shape', () async {
    await store.storeCredentials(
      'bridge-xyz',
      const BridgeCredentials(
        applicationKey: 'AK',
        certFingerprintSha256: 'FP',
      ),
    );

    final file = File('${tempDir.path}/bridge_credentials.json');
    expect(await file.exists(), isTrue);
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;
    expect(decoded['version'], 1);
    final bridges = decoded['bridges'] as Map<String, Object?>;
    expect(bridges.keys, ['bridge-xyz']);
    final entry = bridges['bridge-xyz'] as Map<String, Object?>;
    expect(entry['applicationKey'], 'AK');
    expect(entry['certFingerprintSha256'], 'FP');
  });

  test('concurrent writes serialize cleanly (no lost updates)', () async {
    // Fire off 20 stores in parallel; every write must land.
    final futures = <Future<void>>[
      for (var i = 0; i < 20; i++)
        store.storeCredentials(
          'bridge-$i',
          BridgeCredentials(
            applicationKey: 'k-$i',
            certFingerprintSha256: 'fp-$i',
          ),
        ),
    ];
    await Future.wait(futures);

    final all = await store.loadAllCredentials();
    expect(all.length, 20);
    for (var i = 0; i < 20; i++) {
      expect(all['bridge-$i']?.applicationKey, 'k-$i');
    }
  });

  test('no .tmp sibling left behind after a successful write', () async {
    await store.storeCredentials(
      'bridge-1',
      const BridgeCredentials(applicationKey: 'k', certFingerprintSha256: 'fp'),
    );
    final tmp = File('${tempDir.path}/bridge_credentials.json.tmp');
    expect(await tmp.exists(), isFalse);
  });
}
