// Unit tests for BridgeDiscoveryService.
//
// Subclasses [MDnsDiscoveryClient] with canned streams so the test never
// touches multicast.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/core/net/bridge_discovery_service.dart';
import 'package:multicast_dns/multicast_dns.dart';

void main() {
  test('walks PTR → SRV → A and yields unique bridges', () async {
    final client = _FakeClient(
      ptrs: [
        const PtrResourceRecord('_hue._tcp.local', 0,
            domainName: 'bridge1._hue._tcp.local'),
        const PtrResourceRecord('_hue._tcp.local', 0,
            domainName: 'bridge2._hue._tcp.local'),
      ],
      srvs: {
        'bridge1._hue._tcp.local': [
          const SrvResourceRecord(
            'bridge1._hue._tcp.local',
            0,
            target: 'Philips-hue-1.local',
            port: 443,
            priority: 0,
            weight: 0,
          ),
        ],
        'bridge2._hue._tcp.local': [
          const SrvResourceRecord(
            'bridge2._hue._tcp.local',
            0,
            target: 'Philips-hue-2.local',
            port: 443,
            priority: 0,
            weight: 0,
          ),
        ],
      },
      addrs: {
        'Philips-hue-1.local': [
          IPAddressResourceRecord(
            'Philips-hue-1.local',
            0,
            address: InternetAddress('192.168.1.10'),
          ),
        ],
        'Philips-hue-2.local': [
          IPAddressResourceRecord(
            'Philips-hue-2.local',
            0,
            address: InternetAddress('192.168.1.11'),
          ),
        ],
      },
    );

    final svc = BridgeDiscoveryService(clientFactory: () => client);

    final bridges = await svc.discover().toList();
    expect(bridges.length, 2);
    expect(bridges.map((b) => b.ip), ['192.168.1.10', '192.168.1.11']);
    expect(bridges.every((b) => b.port == 443), isTrue);
    expect(client.started, isTrue);
    expect(client.stopped, isTrue);
  });

  test('returns empty when no PTR records are seen', () async {
    final client = _FakeClient(ptrs: [], srvs: {}, addrs: {});
    final svc = BridgeDiscoveryService(clientFactory: () => client);
    final bridges = await svc.discover().toList();
    expect(bridges, isEmpty);
    expect(client.stopped, isTrue);
  });

  test('deduplicates repeat address records', () async {
    final client = _FakeClient(
      ptrs: [
        const PtrResourceRecord('_hue._tcp.local', 0,
            domainName: 'b._hue._tcp.local'),
      ],
      srvs: {
        'b._hue._tcp.local': [
          const SrvResourceRecord(
            'b._hue._tcp.local',
            0,
            target: 'Philips-hue.local',
            port: 443,
            priority: 0,
            weight: 0,
          ),
        ],
      },
      addrs: {
        'Philips-hue.local': [
          IPAddressResourceRecord(
            'Philips-hue.local',
            0,
            address: InternetAddress('10.0.0.2'),
          ),
          IPAddressResourceRecord(
            'Philips-hue.local',
            0,
            address: InternetAddress('10.0.0.2'),
          ),
        ],
      },
    );
    final svc = BridgeDiscoveryService(clientFactory: () => client);
    final bridges = await svc.discover().toList();
    expect(bridges.length, 1);
    expect(bridges.first.ip, '10.0.0.2');
  });
}

/// In-memory discovery client for tests.
class _FakeClient extends MDnsDiscoveryClient {
  _FakeClient({
    required this.ptrs,
    required this.srvs,
    required this.addrs,
  }) : super.forOverrides();

  final List<PtrResourceRecord> ptrs;
  final Map<String, List<SrvResourceRecord>> srvs;
  final Map<String, List<IPAddressResourceRecord>> addrs;

  bool started = false;
  bool stopped = false;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Stream<PtrResourceRecord> ptrLookup(String serviceName) =>
      Stream.fromIterable(ptrs);

  @override
  Stream<SrvResourceRecord> srvLookup(String domainName) =>
      Stream.fromIterable(srvs[domainName] ?? const []);

  @override
  Stream<IPAddressResourceRecord> addressLookup(String target) =>
      Stream.fromIterable(addrs[target] ?? const []);
}
