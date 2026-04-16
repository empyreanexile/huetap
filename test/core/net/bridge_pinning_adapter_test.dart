// Integration tests for BridgePinningAdapter.
//
// Each test generates a fresh self-signed cert with openssl, spins up a
// tiny HTTPS echo server on 127.0.0.1, and exercises the adapter against
// it in both TOFU and armed modes.
//
// Requires openssl on PATH. On dev boxes with Git-for-Windows installed
// (the expected project setup) openssl ships at
// C:\Program Files\Git\usr\bin\openssl.exe and is on the default PATH.
// If openssl is unavailable the suite skips with a clear message.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/core/net/bridge_pinning_adapter.dart';

void main() {
  late Directory tempDir;
  late _TestCert primaryCert;
  late _TestCert alternateCert;
  late _HttpsEchoServer server;

  setUpAll(() async {
    // Fail fast if openssl isn't on PATH — the tests can't run without it.
    // Probe openssl directly so this works on both Windows and Unix runners.
    final probe = await Process.run('openssl', [
      'version',
    ], runInShell: true);
    if (probe.exitCode != 0) {
      markTestSkipped(
        'openssl not on PATH — skipping pinning integration tests',
      );
      return;
    }
    tempDir = await Directory.systemTemp.createTemp('huetap_pin_test_');
    primaryCert = await _generateCert(tempDir, 'primary');
    alternateCert = await _generateCert(tempDir, 'alternate');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    server = await _HttpsEchoServer.start(primaryCert);
  });

  tearDown(() async {
    await server.stop();
  });

  test('TOFU mode accepts any cert and captures its SHA-256', () async {
    final adapter = BridgePinningAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    final res = await dio.getUri<String>(server.uri('/ping'));

    expect(res.statusCode, 200);
    expect(res.data, 'pong');
    expect(adapter.lastCapturedFingerprint, equals(primaryCert.sha256));
    expect(adapter.mode, PinningMode.tofu);
  });

  test('armed mode with matching fingerprint passes through', () async {
    final adapter = BridgePinningAdapter(
      mode: PinningMode.armed,
      pinnedFingerprint: primaryCert.sha256,
    );
    final dio = Dio()..httpClientAdapter = adapter;

    final res = await dio.getUri<String>(server.uri('/ping'));
    expect(res.statusCode, 200);
    expect(res.data, 'pong');
  });

  test(
    'armed mode with mismatched fingerprint raises CertificateMismatchException',
    () async {
      final adapter = BridgePinningAdapter(
        mode: PinningMode.armed,
        pinnedFingerprint: alternateCert.sha256, // wrong pin
      );
      final dio = Dio()..httpClientAdapter = adapter;

      try {
        await dio.getUri<String>(server.uri('/ping'));
        fail('expected CertificateMismatchException');
      } on DioException catch (e) {
        // dio wraps our thrown exception in DioException.error.
        expect(e.error, isA<CertificateMismatchException>());
        final mismatch = e.error! as CertificateMismatchException;
        expect(mismatch.actual, primaryCert.sha256);
        expect(mismatch.expected, alternateCert.sha256);
      }
    },
  );

  test('switchToTofu then armWithFingerprint updates mode + pin', () async {
    // Start armed against the wrong cert — first call must fail.
    final adapter = BridgePinningAdapter(
      mode: PinningMode.armed,
      pinnedFingerprint: alternateCert.sha256,
    );
    final dio = Dio()..httpClientAdapter = adapter;

    var threw = false;
    try {
      await dio.getUri<void>(server.uri('/ping'));
    } on DioException catch (e) {
      threw = e.error is CertificateMismatchException;
    }
    expect(threw, isTrue, reason: 'should have rejected wrong pin');

    // Re-pair flow: switch to TOFU, make a call, capture, then re-arm.
    adapter.switchToTofu();
    final tofuRes = await dio.getUri<String>(server.uri('/ping'));
    expect(tofuRes.statusCode, 200);
    expect(adapter.lastCapturedFingerprint, primaryCert.sha256);

    adapter.armWithFingerprint(adapter.lastCapturedFingerprint!);
    final armedRes = await dio.getUri<String>(server.uri('/ping'));
    expect(armedRes.statusCode, 200);
    expect(adapter.mode, PinningMode.armed);
    expect(adapter.pinnedFingerprint, primaryCert.sha256);
  });
}

/// Holds a freshly-generated self-signed cert + its canonical SHA-256.
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

Future<_TestCert> _generateCert(Directory dir, String label) async {
  final keyPath = '${dir.path}/$label.key';
  final certPath = '${dir.path}/$label.crt';

  // One-shot self-signed cert, RSA 2048, 10-year expiry, CN=127.0.0.1.
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
  if (result.exitCode != 0) {
    throw StateError('openssl failed: ${result.stderr}');
  }

  // Compute the SHA-256 of the DER form so tests match what the adapter sees.
  final pem = await File(certPath).readAsString();
  final der = _pemToDer(pem);
  final fp = sha256.convert(der).toString().toLowerCase();
  return _TestCert(certPath: certPath, keyPath: keyPath, sha256: fp);
}

List<int> _pemToDer(String pem) {
  final body = pem
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64.decode(body);
}

/// Minimal HTTPS echo server for tests. Responds "pong" to any GET /ping.
class _HttpsEchoServer {
  _HttpsEchoServer._(this._server);

  final HttpServer _server;

  static Future<_HttpsEchoServer> start(_TestCert cert) async {
    final ctx = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(cert.certPath)
      ..usePrivateKey(cert.keyPath);
    final server = await HttpServer.bindSecure('127.0.0.1', 0, ctx);
    server.listen((req) async {
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.text;
      req.response.write('pong');
      await req.response.close();
    });
    return _HttpsEchoServer._(server);
  }

  Uri uri(String path) => Uri.parse('https://127.0.0.1:${_server.port}$path');

  Future<void> stop() => _server.close(force: true);
}
