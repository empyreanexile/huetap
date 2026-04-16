// Bridge discovery: kick off an mDNS scan on entry, show discovered bridges
// as tappable tiles, and offer a manual-IP fallback (SPEC §6.2: "Falls back
// to manual IP entry if no service is found").
//
// Tapping a candidate navigates to [PairPollScreen], which runs the
// link-button polling flow.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../core/net/bridge_discovery_service.dart';
import '../../core/providers.dart';
import '../../core/theme/twilight_hearth_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'pair_poll_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final List<DiscoveredBridge> _found = [];
  StreamSubscription<DiscoveredBridge>? _sub;
  bool _scanning = false;
  final _ipCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ipCtrl.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _found.clear();
      _scanning = true;
    });
    final svc = ref.read(bridgeDiscoveryServiceProvider);
    _sub?.cancel();
    _sub = svc
        .discover(timeout: const Duration(seconds: 6))
        .listen(
          (b) {
            if (!mounted) return;
            setState(() {
              if (!_found.any((x) => x.ip == b.ip)) _found.add(b);
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _scanning = false);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _scanning = false);
          },
        );
  }

  void _pair(String ip) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PairPollScreen(ip: ip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TwilightHearthGradients.scaffoldBody,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.discoveryScreenTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Symbols.refresh),
              tooltip: l10n.discoveryRescanTooltip,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ScanStatus(scanning: _scanning, count: _found.length),
            const SizedBox(height: 16),
            if (_found.isEmpty && !_scanning)
              _EmptyScanState(onRescan: _startScan),
            for (final b in _found)
              _DiscoveredTile(bridge: b, onTap: () => _pair(b.ip)),
            const SizedBox(height: 24),
            _ManualIpCard(controller: _ipCtrl, onSubmit: _pair),
          ],
        ),
      ),
    );
  }
}

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({required this.scanning, required this.count});
  final bool scanning;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final String statusText;
    if (scanning) {
      statusText = l10n.discoveryStatusScanning;
    } else if (count == 0) {
      statusText = l10n.discoveryStatusNoBridges;
    } else if (count == 1) {
      statusText = l10n.discoveryStatusFoundOne;
    } else {
      statusText = l10n.discoveryStatusFoundMany(count);
    }
    return Row(
      children: [
        if (scanning)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(
            Symbols.radar,
            size: 18,
            color: TwilightHearthColors.text2,
          ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: TwilightHearthColors.text2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DiscoveredTile extends StatelessWidget {
  const _DiscoveredTile({required this.bridge, required this.onTap});
  final DiscoveredBridge bridge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: TwilightHearthColors.creamAlt,
        borderRadius: BorderRadius.circular(TwilightHearthRadii.card),
        boxShadow: TwilightHearthShadows.card,
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: TwilightHearthGradients.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Symbols.hub, color: TwilightHearthColors.cream),
        ),
        title: Text(
          bridge.host,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${bridge.ip}:${bridge.port}'),
        trailing: const Icon(Symbols.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyScanState extends StatelessWidget {
  const _EmptyScanState({required this.onRescan});
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TwilightHearthColors.creamAlt,
        borderRadius: BorderRadius.circular(TwilightHearthRadii.card),
        border: Border.all(color: TwilightHearthColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.discoveryEmptyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.discoveryEmptyDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: TwilightHearthColors.text2,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRescan,
            icon: const Icon(Symbols.refresh),
            label: Text(l10n.commonRescan),
          ),
        ],
      ),
    );
  }
}

class _ManualIpCard extends StatelessWidget {
  const _ManualIpCard({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final void Function(String ip) onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TwilightHearthColors.creamAlt,
        borderRadius: BorderRadius.circular(TwilightHearthRadii.card),
        border: Border.all(color: TwilightHearthColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.discoveryManualIpTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: l10n.discoveryManualIpHint,
              prefixIcon: const Icon(Symbols.lan),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final ip = controller.text.trim();
                if (ip.isNotEmpty) onSubmit(ip);
              },
              icon: const Icon(Symbols.check),
              label: Text(l10n.discoveryManualIpSubmit),
            ),
          ),
        ],
      ),
    );
  }
}
