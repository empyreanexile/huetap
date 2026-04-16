// Per-bridge TOFU cert-pinning adapter for dio (SPEC §6.2).
//
// Each paired Hue bridge gets one instance of this adapter, wrapping a
// dedicated `HttpClient` whose `badCertificateCallback` enforces a SHA-256
// fingerprint pin.
//
// Two modes:
//   * TOFU  — accept any cert, expose its SHA-256 on `lastCapturedFingerprint`.
//             Used during initial pair and re-pair.
//   * armed — accept only if the presented cert's SHA-256 matches the
//             stored pin. Mismatches surface as [CertificateMismatchException].
//
// Callers flip between modes via [switchToTofu] / [armWithFingerprint]. The
// mode is mutable because re-pair (SPEC §5.9) switches back to TOFU for the
// duration of the new pairing flow, then re-arms with the newly captured
// fingerprint.
//
// Thread-safety: concurrent requests against the *same* bridge are serialized
// by the per-bridge in-flight gate (SPEC §5.6), so this adapter does not need
// its own lock. Fingerprint capture / mismatch state is scoped to each
// [fetch] call via the `_lastPinFailure` / `_lastCaptured` slots.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Mode of a [BridgePinningAdapter].
enum PinningMode {
  /// Accept any cert presented by the bridge; capture its fingerprint so the
  /// caller can persist it after pairing succeeds.
  tofu,

  /// Validate the presented cert's SHA-256 against [BridgePinningAdapter.pinnedFingerprint].
  /// Mismatch raises [CertificateMismatchException].
  armed,
}

/// Thrown when an armed adapter sees a bridge cert whose SHA-256 doesn't
/// match the stored pin. Surfaced to the UI as "bridge identity changed"
/// (SPEC §5.5) and triggers re-pair (SPEC §5.9).
class CertificateMismatchException implements Exception {
  CertificateMismatchException({
    required this.expected,
    required this.actual,
    this.host,
  });

  /// Lowercase-hex SHA-256 of the cert we were pinning against.
  final String expected;

  /// Lowercase-hex SHA-256 of the cert the bridge actually presented.
  final String actual;

  /// Host the handshake was attempted against (for diagnostics).
  final String? host;

  @override
  String toString() =>
      'CertificateMismatchException('
      'host: $host, expected: $expected, actual: $actual)';
}

/// dio adapter wrapping one `HttpClient` per bridge, enforcing a SHA-256 pin.
class BridgePinningAdapter implements HttpClientAdapter {
  BridgePinningAdapter({
    PinningMode mode = PinningMode.tofu,
    String? pinnedFingerprint,
  }) : _mode = mode,
       _pinnedFingerprint = pinnedFingerprint?.toLowerCase() {
    _inner = IOHttpClientAdapter(createHttpClient: _buildHttpClient);
  }

  PinningMode _mode;
  String? _pinnedFingerprint;
  String? _lastCaptured;
  _PinFailure? _lastPinFailure;

  late final IOHttpClientAdapter _inner;

  /// Current mode. Mutate via [switchToTofu] or [armWithFingerprint].
  PinningMode get mode => _mode;

  /// Lowercase-hex SHA-256 the adapter is pinning against (armed mode only).
  String? get pinnedFingerprint => _pinnedFingerprint;

  /// Lowercase-hex SHA-256 captured on the most recent successful handshake
  /// in TOFU mode. Consumed by the pairing flow.
  String? get lastCapturedFingerprint => _lastCaptured;

  /// Switch to TOFU mode (re-pair uses this). Pinned fingerprint is retained
  /// so that a failed re-pair can fall back without losing state, but mode
  /// gating is what matters.
  void switchToTofu() {
    _mode = PinningMode.tofu;
  }

  /// Arm the adapter with a new pin and enter armed mode.
  void armWithFingerprint(String fingerprint) {
    _pinnedFingerprint = fingerprint.toLowerCase();
    _mode = PinningMode.armed;
  }

  HttpClient _buildHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = _check;
    return client;
  }

  bool _check(X509Certificate cert, String host, int port) {
    final fp = sha256.convert(cert.der).toString().toLowerCase();
    if (_mode == PinningMode.tofu) {
      _lastCaptured = fp;
      return true;
    }
    final pinned = _pinnedFingerprint;
    if (pinned != null && pinned == fp) {
      return true;
    }
    _lastPinFailure = _PinFailure(
      expected: pinned ?? '',
      actual: fp,
      host: host,
    );
    return false;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _lastPinFailure = null;
    try {
      return await _inner.fetch(options, requestStream, cancelFuture);
    } catch (e) {
      final failure = _lastPinFailure;
      if (failure != null) {
        throw CertificateMismatchException(
          expected: failure.expected,
          actual: failure.actual,
          host: failure.host,
        );
      }
      rethrow;
    }
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

class _PinFailure {
  _PinFailure({
    required this.expected,
    required this.actual,
    required this.host,
  });

  final String expected;
  final String actual;
  final String host;
}
