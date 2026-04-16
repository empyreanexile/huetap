// mDNS bridge discovery (SPEC §6.2).
//
// Issues a one-shot multicast query for `_hue._tcp.local` PTR records, then
// follows each pointer through SRV → A records to resolve a bridge's IP.
// Emits [DiscoveredBridge] entries via a broadcast stream that completes
// after [timeout].
//
// Tests subclass [MDnsDiscoveryClient] (or pass a factory that returns a
// fake) to avoid touching multicast.

import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

/// One candidate bridge found on the LAN.
class DiscoveredBridge {
  const DiscoveredBridge({
    required this.ip,
    required this.port,
    required this.host,
  });

  /// IPv4 dotted-quad.
  final String ip;

  /// Advertised port. Hue bridges advertise 443 but SPEC §6.2 talks to
  /// HTTPS on the IP directly, so this is informational.
  final int port;

  /// mDNS hostname (e.g. `Philips-hue.local`) — useful for UI display.
  final String host;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredBridge &&
      other.ip == ip &&
      other.port == port &&
      other.host == host;

  @override
  int get hashCode => Object.hash(ip, port, host);

  @override
  String toString() => 'DiscoveredBridge(ip: $ip, port: $port, host: $host)';
}

/// Thin wrapper around `MDnsClient` — the only production implementation.
/// Tests subclass this and override the three lookups.
class MDnsDiscoveryClient {
  MDnsDiscoveryClient() : _client = MDnsClient();

  /// For subclasses that don't need a real `MDnsClient` (tests).
  MDnsDiscoveryClient.forOverrides() : _client = null;

  final MDnsClient? _client;

  Future<void> start() async {
    await _client?.start();
  }

  Future<void> stop() async {
    _client?.stop();
  }

  Stream<PtrResourceRecord> ptrLookup(String serviceName) =>
      _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceName),
      );

  Stream<SrvResourceRecord> srvLookup(String domainName) =>
      _client!.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(domainName),
      );

  Stream<IPAddressResourceRecord> addressLookup(String target) =>
      _client!.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(target),
      );
}

/// mDNS bridge discovery.
class BridgeDiscoveryService {
  BridgeDiscoveryService({MDnsDiscoveryClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? MDnsDiscoveryClient.new;

  static const String _serviceName = '_hue._tcp.local';

  final MDnsDiscoveryClient Function() _clientFactory;

  /// Discover Hue bridges on the LAN. The returned stream completes after
  /// [timeout] elapses, even if no bridges are found (SPEC §6.2: fallback
  /// to manual IP is the caller's job).
  Stream<DiscoveredBridge> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    final client = _clientFactory();
    await client.start();
    final seen = <String>{}; // dedupe by ip+port
    try {
      final ptrs = client.ptrLookup(_serviceName).timeout(
        timeout,
        onTimeout: (sink) => sink.close(),
      );
      await for (final ptr in ptrs) {
        // Remaining lookups share the same outer timeout budget; use a
        // short per-record cap so a stuck host doesn't block the rest.
        final srvs = client.srvLookup(ptr.domainName).timeout(
          const Duration(seconds: 2),
          onTimeout: (sink) => sink.close(),
        );
        await for (final srv in srvs) {
          final addrs = client.addressLookup(srv.target).timeout(
            const Duration(seconds: 2),
            onTimeout: (sink) => sink.close(),
          );
          await for (final addr in addrs) {
            if (addr.address.type != InternetAddressType.IPv4) continue;
            final key = '${addr.address.address}:${srv.port}';
            if (!seen.add(key)) continue;
            yield DiscoveredBridge(
              ip: addr.address.address,
              port: srv.port,
              host: srv.target,
            );
          }
        }
      }
    } finally {
      await client.stop();
    }
  }
}
