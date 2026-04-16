// Minimal "Firing…" splash shown when Android launches HueTap from an NFC
// tap's NDEF_DISCOVERED intent. We fire the bound scene via TapFireService,
// then close the app so the user returns to whatever they were doing.
//
// Auto-close fires on both success and failure — the user wanted "tap the
// card, scene changes, no app in my face." Failures are still recorded in
// tap_logs for later inspection on the History screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tap/tap_fire_service.dart';
import '../../core/theme/twilight_hearth_theme.dart';

class FireScreen extends ConsumerStatefulWidget {
  const FireScreen({required this.uuid, super.key});

  final String uuid;

  @override
  ConsumerState<FireScreen> createState() => _FireScreenState();
}

class _FireScreenState extends ConsumerState<FireScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fireAndClose());
  }

  Future<void> _fireAndClose() async {
    try {
      await ref.read(tapFireServiceProvider).fire(widget.uuid);
    } catch (_) {
      // TapFireService never throws, but defensive: even if something
      // leaks out we still want to close cleanly.
    }
    if (!mounted) return;
    // `SystemNavigator.pop()` asks Android to finish the top activity. With
    // `launchMode="singleTop"` and `taskAffinity=""` on MainActivity, that
    // returns the user to whatever app was previously focused.
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TwilightHearthGradients.scaffoldBody,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: TwilightHearthColors.plum,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Firing…',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: TwilightHearthColors.text2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
