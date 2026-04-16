// Bridge credentials JSON store (SPEC §6.4).
//
// Stores application keys + SHA-256 cert fingerprints in
// `<appSupportDir>/no_backup/bridge_credentials.json`, keyed by Hue bridge ID.
// Android Backup rules (SPEC §6.10) exclude the `no_backup/` directory from
// both auto-backup and device-to-device transfer, so bridge credentials are
// never persisted off-device.
//
// File writes are atomic — write a sibling `.tmp` file, flush, rename over
// the destination. Concurrent access within this process is serialized via
// an in-process futures chain.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Secret material for one paired Hue bridge.
class BridgeCredentials {
  const BridgeCredentials({
    required this.applicationKey,
    required this.certFingerprintSha256,
  });

  /// Hue CLIP v2 application key (sent as `hue-application-key` header).
  final String applicationKey;

  /// Lowercase hex SHA-256 of the bridge's leaf cert, captured at pair or
  /// re-pair time. Used by the TOFU pinning interceptor.
  final String certFingerprintSha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'applicationKey': applicationKey,
    'certFingerprintSha256': certFingerprintSha256,
  };

  factory BridgeCredentials.fromJson(Map<String, Object?> json) {
    return BridgeCredentials(
      applicationKey: json['applicationKey']! as String,
      certFingerprintSha256: json['certFingerprintSha256']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BridgeCredentials &&
      other.applicationKey == applicationKey &&
      other.certFingerprintSha256 == certFingerprintSha256;

  @override
  int get hashCode => Object.hash(applicationKey, certFingerprintSha256);
}

class BridgeCredentialsStore {
  BridgeCredentialsStore({Directory? baseDirOverride})
    : _baseDirOverride = baseDirOverride;

  static const String _filename = 'bridge_credentials.json';
  static const int _schemaVersion = 1;

  /// If set, tests use this instead of `getApplicationSupportDirectory()/no_backup`.
  final Directory? _baseDirOverride;

  /// Single-slot serialization — all reads/writes chain off this future.
  Future<void> _tail = Future<void>.value();

  Future<Directory> _baseDir() async {
    if (_baseDirOverride != null) {
      if (!await _baseDirOverride.exists()) {
        await _baseDirOverride.create(recursive: true);
      }
      return _baseDirOverride;
    }
    final support = await getApplicationSupportDirectory();
    // Hardcoded `/` separator is safe — HueTap is Android-only (SPEC §1).
    final dir = Directory('${support.path}/no_backup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Chain every op on `_tail` so reads and writes are strictly serialized.
  Future<T> _locked<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<Map<String, BridgeCredentials>> loadAllCredentials() =>
      _locked(_readLocked);

  Future<BridgeCredentials?> loadCredentials(String bridgeId) async {
    final all = await loadAllCredentials();
    return all[bridgeId];
  }

  Future<void> storeCredentials(
    String bridgeId,
    BridgeCredentials credentials,
  ) {
    return _locked(() async {
      final current = await _readLocked();
      current[bridgeId] = credentials;
      await _writeAtomicLocked(current);
    });
  }

  Future<void> removeCredentials(String bridgeId) {
    return _locked(() async {
      final current = await _readLocked();
      current.remove(bridgeId);
      await _writeAtomicLocked(current);
    });
  }

  // --- Non-locking helpers used from inside _locked() blocks. -----------

  Future<Map<String, BridgeCredentials>> _readLocked() async {
    final file = File('${(await _baseDir()).path}/$_filename');
    if (!await file.exists()) return <String, BridgeCredentials>{};
    final raw = await file.readAsString();
    if (raw.isEmpty) return <String, BridgeCredentials>{};
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final bridges =
        (decoded['bridges'] as Map<String, Object?>?) ?? <String, Object?>{};
    return bridges.map(
      (id, v) => MapEntry(
        id,
        BridgeCredentials.fromJson(v! as Map<String, Object?>),
      ),
    );
  }

  Future<void> _writeAtomicLocked(
    Map<String, BridgeCredentials> bridges,
  ) async {
    final dir = await _baseDir();
    final destPath = '${dir.path}/$_filename';
    final tmpPath = '$destPath.tmp';
    final payload = jsonEncode(<String, Object?>{
      'version': _schemaVersion,
      'bridges': bridges.map((k, v) => MapEntry(k, v.toJson())),
    });
    final tmp = File(tmpPath);
    final sink = tmp.openWrite();
    sink.write(payload);
    await sink.flush();
    await sink.close();
    await tmp.rename(destPath);
  }
}
