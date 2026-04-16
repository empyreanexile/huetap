// Per-bridge runtime: pinning adapter + dio + HueApiClient + in-flight gate.
//
// SPEC §6.2: "one instance per bridge, registered in BridgeClientRegistry."
// SPEC §5.6: per-bridge in-flight gate serializes writes to the same bridge
// so two rapid NFC taps don't collide.

import 'dart:async';

import 'package:dio/dio.dart';

import 'bridge_pinning_adapter.dart';
import 'hue_api_client.dart';

class BridgeClient {
  BridgeClient({
    required this.bridgeRowId,
    required this.bridgeId,
    required String ip,
    required String applicationKey,
    required String certFingerprintSha256,
  }) : _adapter = BridgePinningAdapter(
         mode: PinningMode.armed,
         pinnedFingerprint: certFingerprintSha256,
       ),
       _ip = ip {
    final dio = Dio()..httpClientAdapter = _adapter;
    api = HueApiClient(ip: ip, applicationKey: applicationKey, dio: dio);
  }

  /// Drift `Bridges.id`.
  final int bridgeRowId;

  /// Stable bridge identifier from `/api/0/config`.
  final String bridgeId;

  final BridgePinningAdapter _adapter;
  final String _ip;

  /// Public HTTP surface.
  late final HueApiClient api;

  /// Per-bridge mutex (SPEC §5.6). Callers wrap scene-fires / sync in this.
  Future<void> _inFlight = Future<void>.value();

  String get ip => _ip;

  /// Serialize `op` against other operations on this bridge.
  Future<T> runExclusive<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    final prev = _inFlight;
    _inFlight = prev.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

/// Central lookup table keyed by `Bridges.id` (the Drift row id, since that's
/// what CardBindings/Scenes reference).
class BridgeClientRegistry {
  final Map<int, BridgeClient> _byRowId = <int, BridgeClient>{};

  BridgeClient? byRowId(int rowId) => _byRowId[rowId];

  BridgeClient? byBridgeId(String bridgeId) {
    for (final c in _byRowId.values) {
      if (c.bridgeId == bridgeId) return c;
    }
    return null;
  }

  Iterable<BridgeClient> get all => _byRowId.values;

  void register(BridgeClient client) {
    _byRowId[client.bridgeRowId] = client;
  }

  void unregister(int bridgeRowId) {
    _byRowId.remove(bridgeRowId);
  }

  void clear() => _byRowId.clear();
}
