// Link-button pairing for a Hue bridge (SPEC §5.2 step 5-6, §6.2).
//
// Uses a dio instance backed by a [BridgePinningAdapter] in TOFU mode to:
//   1. Poll `POST https://<ip>/api` every 2s for up to 60s until the user
//      presses the bridge's physical link button and the v1 API returns
//      `{"success": {"username": "..."}}`.
//   2. Fetch `GET /api/0/config` for the bridge's immutable ID and name.
//   3. Surface the captured cert fingerprint so the caller can arm the
//      pinning adapter and persist the pin.
//
// This service *does not* write to Drift or the credentials JSON — it just
// produces a [BridgePairingResult] that the pairing flow coordinator uses.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'bridge_pinning_adapter.dart';

/// Everything the caller needs to finalize a successful pair (SPEC §5.2 step 8).
class BridgePairingResult {
  const BridgePairingResult({
    required this.ip,
    required this.bridgeId,
    required this.name,
    required this.applicationKey,
    required this.certFingerprintSha256,
  });

  final String ip;
  final String bridgeId;
  final String name;
  final String applicationKey;
  final String certFingerprintSha256;
}

/// Pairing-flow errors. Each maps to a distinct user-facing message.
sealed class BridgePairingException implements Exception {
  const BridgePairingException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// 60s elapsed without the link button being pressed.
class LinkButtonTimeoutException extends BridgePairingException {
  const LinkButtonTimeoutException()
    : super('Link button was not pressed within 60 seconds.');
}

/// The bridge is unreachable (network down, wrong IP, bridge offline).
class BridgeUnreachableException extends BridgePairingException {
  const BridgeUnreachableException(super.message);
}

/// The bridge responded, but in a shape the v1 API spec doesn't describe.
class UnexpectedBridgeResponseException extends BridgePairingException {
  const UnexpectedBridgeResponseException(super.message);
}

/// Coordinates the TOFU pairing flow against a single bridge IP.
class BridgePairingService {
  BridgePairingService({
    required BridgePinningAdapter adapter,
    Dio? dio,
    Duration pollInterval = const Duration(seconds: 2),
    Duration totalTimeout = const Duration(seconds: 60),
    String deviceType = 'huetap#android',
  }) : _adapter = adapter,
       _dio = (dio ?? Dio())..httpClientAdapter = adapter,
       _pollInterval = pollInterval,
       _totalTimeout = totalTimeout,
       _deviceType = deviceType;

  final BridgePinningAdapter _adapter;
  final Dio _dio;
  final Duration _pollInterval;
  final Duration _totalTimeout;
  final String _deviceType;

  /// Poll for a link-button press, then fetch config. Throws one of the
  /// [BridgePairingException] subclasses on failure.
  Future<BridgePairingResult> pair(String ip) async {
    if (_adapter.mode != PinningMode.tofu) {
      _adapter.switchToTofu();
    }

    final applicationKey = await _pollForAppKey(ip);
    final fingerprint = _adapter.lastCapturedFingerprint;
    if (fingerprint == null) {
      throw const UnexpectedBridgeResponseException(
        'TLS handshake completed without capturing a cert fingerprint.',
      );
    }

    final config = await _fetchConfig(ip, applicationKey);
    return BridgePairingResult(
      ip: ip,
      bridgeId: config.bridgeId,
      name: config.name,
      applicationKey: applicationKey,
      certFingerprintSha256: fingerprint,
    );
  }

  Future<String> _pollForAppKey(String ip) async {
    final deadline = DateTime.now().add(_totalTimeout);
    final url = 'https://$ip/api';
    final payload = <String, Object?>{
      'devicetype': _deviceType,
      'generateclientkey': true,
    };

    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await _dio.post<dynamic>(
          url,
          data: payload,
          options: Options(
            responseType: ResponseType.json,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            validateStatus: (_) => true,
          ),
        );
        final parsed = _parseV1Response(res.data);
        if (parsed.applicationKey != null) {
          return parsed.applicationKey!;
        }
        // Non-success (typically error type 101: link button not pressed).
      } on DioException catch (e) {
        // Network-level errors during polling are only fatal if they persist
        // through the whole window. Swallow transient ones and retry.
        if (e.type == DioExceptionType.connectionError ||
            e.error is SocketException) {
          // Keep polling — user may still be connecting to the LAN.
        } else {
          // Includes CertificateMismatchException (shouldn't happen in TOFU,
          // but surface anything unexpected rather than loop forever).
          rethrow;
        }
      }

      await Future<void>.delayed(_pollInterval);
    }

    throw const LinkButtonTimeoutException();
  }

  Future<_BridgeConfig> _fetchConfig(String ip, String appKey) async {
    try {
      final res = await _dio.get<dynamic>(
        'https://$ip/api/0/config',
        options: Options(
          // `/api/0/config` is unauthenticated on the v1 endpoint, but set
          // the header anyway for consistency with v2 calls.
          headers: <String, Object?>{'hue-application-key': appKey},
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (code) => code != null && code >= 200 && code < 300,
        ),
      );
      final body = res.data;
      if (body is! Map<String, Object?>) {
        throw const UnexpectedBridgeResponseException(
          '/api/0/config did not return a JSON object.',
        );
      }
      final bridgeId = body['bridgeid'];
      final name = body['name'];
      if (bridgeId is! String || name is! String) {
        throw const UnexpectedBridgeResponseException(
          '/api/0/config missing bridgeid or name.',
        );
      }
      return _BridgeConfig(bridgeId: bridgeId.toLowerCase(), name: name);
    } on DioException catch (e) {
      throw BridgeUnreachableException(
        'Failed to fetch /api/0/config: ${e.message ?? e.type.name}',
      );
    }
  }

  /// Parses the Hue v1 envelope. Response is a list with one element;
  /// success case has `{"success": {"username": "...", "clientkey": "..."}}`,
  /// pending case has `{"error": {"type": 101, ...}}`.
  _V1PollResult _parseV1Response(Object? data) {
    if (data is! List || data.isEmpty) {
      return const _V1PollResult(applicationKey: null);
    }
    final first = data.first;
    if (first is! Map) {
      return const _V1PollResult(applicationKey: null);
    }
    final success = first['success'];
    if (success is Map && success['username'] is String) {
      return _V1PollResult(applicationKey: success['username'] as String);
    }
    // error — still polling. Any other error type (e.g. rate limit) also
    // falls through to a retry; the outer timeout is the only deadline.
    return const _V1PollResult(applicationKey: null);
  }
}

class _BridgeConfig {
  const _BridgeConfig({required this.bridgeId, required this.name});
  final String bridgeId;
  final String name;
}

class _V1PollResult {
  const _V1PollResult({required this.applicationKey});
  final String? applicationKey;
}
