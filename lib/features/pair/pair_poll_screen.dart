// "Press the link button" countdown — drives PairingCoordinator.pair(ip)
// and surfaces success / timeout / unreachable outcomes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../core/net/bridge_client.dart';
import '../../core/net/bridge_pairing_service.dart';
import '../../core/providers.dart';
import '../../core/theme/twilight_hearth_theme.dart';
import '../common/widgets.dart';

class PairPollScreen extends ConsumerStatefulWidget {
  const PairPollScreen({required this.ip, super.key});

  final String ip;

  @override
  ConsumerState<PairPollScreen> createState() => _PairPollScreenState();
}

class _PairPollScreenState extends ConsumerState<PairPollScreen> {
  Timer? _tick;
  int _secondsLeft = 60;
  AsyncValue<BridgeClient> _result = const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    _startPair();
  }

  void _startPair() {
    _tick?.cancel();
    setState(() {
      _secondsLeft = 60;
      _result = const AsyncValue.loading();
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft -= 1;
      });
    });

    ref
        .read(pairingCoordinatorProvider)
        .pair(widget.ip)
        .then<void>((client) {
          if (!mounted) return;
          setState(() => _result = AsyncValue.data(client));
          _tick?.cancel();
        })
        .catchError((Object e, StackTrace st) {
          if (!mounted) return;
          setState(() => _result = AsyncValue.error(e, st));
          _tick?.cancel();
        });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TwilightHearthGradients.scaffoldBody,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Pair bridge'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: _result.when(
            loading: () =>
                _WaitingView(ip: widget.ip, secondsLeft: _secondsLeft),
            data: (client) => HueTapStatusCard(
              icon: Symbols.check,
              iconColor: TwilightHearthColors.meadow,
              title: 'Paired!',
              description: client.ip,
              actions: [
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Symbols.home),
                  label: const Text('Done'),
                ),
              ],
            ),
            error: (e, _) => HueTapStatusCard(
              icon: Symbols.close,
              iconColor: TwilightHearthColors.danger,
              title: 'Pair failed',
              description: e is BridgePairingException
                  ? e.message
                  : e.toString(),
              actions: [
                FilledButton.icon(
                  onPressed: _startPair,
                  icon: const Icon(Symbols.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.ip, required this.secondsLeft});
  final String ip;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return HueTapStatusCard(
      icon: Symbols.touch_app,
      iconGradient: TwilightHearthGradients.primary,
      title: 'Press the link button',
      description:
          'Push the large round button on top of your Hue bridge at $ip.',
      actions: [
        CircularProgressIndicator(value: secondsLeft / 60, strokeWidth: 6),
        const SizedBox(height: 12),
        Text(
          '${secondsLeft}s remaining',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
