// Tests for BridgePairingService.
//
// Spins up a tiny HTTPS server that impersonates the Hue v1 API. First
// N poll attempts respond with "link button not pressed"; the (N+1)-th
// returns a success envelope. `/api/0/config` returns a bridgeid + name.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/core/net/bridge_pairing_service.dart';
import 'package:huetap/core/net/bridge_pinning_adapter.dart';

void main() {
  late Directory tempDir;
  late _TestCert cert;
  late _FakeBridge bridge;

  setUpAll(() async {
    final which = await Process.run('where', ['openssl'], runInShell: true);
    if (which.exitCode != 0) {
      markTestSkipped('openssl not on PATH');
      return;
    }
    tempDir = await Directory.systemTemp.createTemp('huetap_pair_test_');
    cert = await _generateCert(tempDir);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  tearDown(() async {
    await bridge.stop();
  });

  test(
    'returns key + fingerprint + config when link button is pressed',
    () async {
      bridge = await _FakeBridge.start(
        cert,
        linkButtonPressedAfter: 1, // first poll fails, second succeeds
        bridgeId: 'ECB5FAFFFE123456',
        bridgeName: 'Living Room Bridge',
      );
      final adapter = BridgePinningAdapter();
      final svc = BridgePairingService(
        adapter: adapter,
        pollInterval: const Duration(milliseconds: 50),
        totalTimeout: const Duration(seconds: 5),
      );

      final res = await svc.pair('127.0.0.1:${bridge.port}');

      expect(res.applicationKey, 'test-app-key-xyz');
      expect(res.bridgeId, 'ecb5fafffe123456');
      expect(res.name, 'Living Room Bridge');
      expect(res.certFingerprintSha256, cert.sha256);
      expect(bridge.postCount, 2); // 1 reject + 1 success
    },
  );

  test(
    'throws LinkButtonTimeoutException when button is never pressed',
    () async {
      bridge = await _FakeBridge.start(
        cert,
        linkButtonPressedAfter: 9999, // never
        bridgeId: 'ECB5FAFFFE000000',
        bridgeName: 'B',
      );
      final adapter = BridgePinningAdapter();
      final svc = BridgePairingService(
        adapter: adapter,
        pollInterval: const Duration(milliseconds: 50),
        totalTimeout: const Duration(milliseconds: 300),
      );

      expect(
        () => svc.pair('127.0.0.1:${bridge.port}'),
        throwsA(isA<LinkButtonTimeoutException>()),
      );
    },
  );

  test('throws BridgeUnreachableException when /api/0/config fails', () async {
    bridge = await _FakeBridge.start(
      cert,
      linkButtonPressedAfter: 0,
      configReturns500: true,
      bridgeId: 'X',
      bridgeName: 'Y',
    );
    final adapter = BridgePinningAdapter();
    final svc = BridgePairingService(
      adapter: adapter,
      pollInterval: const Duration(milliseconds: 50),
      totalTimeout: const Duration(seconds: 5),
    );

    expect(
      () => svc.pair('127.0.0.1:${bridge.port}'),
      throwsA(isA<BridgeUnreachableException>()),
    );
  });

  test('captured fingerprint matches cert SHA-256', () async {
    bridge = await _FakeBridge.start(
      cert,
      linkButtonPressedAfter: 0,
      bridgeId: 'ABCDEF',
      bridgeName: 'bridge',
    );
    final adapter = BridgePinningAdapter();
    final svc = BridgePairingService(
      adapter: adapter,
      pollInterval: const Duration(milliseconds: 50),
      totalTimeout: const Duration(seconds: 5),
    );
    final res = await svc.pair('127.0.0.1:${bridge.port}');
    expect(res.certFingerprintSha256, adapter.lastCapturedFingerprint);
    expect(res.certFingerprintSha256, cert.sha256);
  });
}

class _TestCert {
  _TestCert({
    required this.certPath,
    required this.keyPath,
    required this.sha256,
  });
  final String certPath;
  final String keyPath;
  final String sha256;
}

Future<_TestCert> _generateCert(Directory dir) async {
  final keyPath = '${dir.path}/bridge.key';
  final certPath = '${dir.path}/bridge.crt';
  final result = await Process.run('openssl', [
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-keyout',
    keyPath,
    '-out',
    certPath,
    '-days',
    '3650',
    '-nodes',
    '-subj',
    '/CN=127.0.0.1',
    '-addext',
    'subjectAltName=IP:127.0.0.1',
  ], runInShell: true);
  if (result.exitCode != 0)
    throw StateError('openssl failed: ${result.stderr}');
  final pem = await File(certPath).readAsString();
  final der = base64.decode(
    pem
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join(),
  );
  return _TestCert(
    certPath: certPath,
    keyPath: keyPath,
    sha256: sha256.convert(der).toString().toLowerCase(),
  );
}

class _FakeBridge {
  _FakeBridge._(
    this._server,
    this.bridgeId,
    this.bridgeName,
    this._threshold,
    this._configReturns500,
  );

  final HttpServer _server;
  final String bridgeId;
  final String bridgeName;
  final int _threshold;
  final bool _configReturns500;
  int postCount = 0;

  int get port => _server.port;

  static Future<_FakeBridge> start(
    _TestCert cert, {
    required int linkButtonPressedAfter,
    required String bridgeId,
    required String bridgeName,
    bool configReturns500 = false,
  }) async {
    final ctx = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(cert.certPath)
      ..usePrivateKey(cert.keyPath);
    final server = await HttpServer.bindSecure('127.0.0.1', 0, ctx);
    final fake = _FakeBridge._(
      server,
      bridgeId,
      bridgeName,
      linkButtonPressedAfter,
      configReturns500,
    );
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest req) async {
    if (req.uri.path == '/api' && req.method == 'POST') {
      postCount++;
      await req.drain<void>();
      req.response.headers.contentType = ContentType.json;
      req.response.statusCode = 200;
      if (postCount > _threshold) {
        req.response.write(
          jsonEncode([
            {
              'success': {
                'username': 'test-app-key-xyz',
                'clientkey': 'deadbeef',
              },
            },
          ]),
        );
      } else {
        req.response.write(
          jsonEncode([
            {
              'error': {
                'type': 101,
                'address': '',
                'description': 'link button not pressed',
              },
            },
          ]),
        );
      }
      await req.response.close();
      return;
    }
    if (req.uri.path == '/api/0/config' && req.method == 'GET') {
      await req.drain<void>();
      if (_configReturns500) {
        req.response.statusCode = 500;
        await req.response.close();
        return;
      }
      req.response.headers.contentType = ContentType.json;
      req.response.statusCode = 200;
      req.response.write(
        jsonEncode(<String, Object?>{'bridgeid': bridgeId, 'name': bridgeName}),
      );
      await req.response.close();
      return;
    }
    req.response.statusCode = 404;
    await req.response.close();
  }

  Future<void> stop() => _server.close(force: true);
}
