// Foreground NFC tap handler. Wraps the home screen so that whenever the app
// is in the foreground and a HueTap card is tapped, we resolve the binding
// and fire its scene. Snackbars surface success / errors.
//
// For the prototype we use a continuous foreground read session while the
// home screen is visible. When the screen is not visible (user is pairing,
// binding, etc.) the session is stopped so we don't interfere.
//
// External NDEF dispatch (Android launching the app via intent filter) is
// handled separately at main.dart bootstrap and flows through the same
// [TapResolver].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../core/nfc/nfc_service.dart';
import '../../core/tap/tap_fire_service.dart';
import '../../core/theme/twilight_hearth_theme.dart';
import '../../l10n/gen/app_localizations.dart';

class TapHandler extends ConsumerStatefulWidget {
  const TapHandler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TapHandler> createState() => _TapHandlerState();
}

class _TapHandlerState extends ConsumerState<TapHandler>
    with WidgetsBindingObserver {
  final _nfc = NfcService();
  NfcReadHandle? _handle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRead());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRead();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startRead();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopRead();
    }
  }

  Future<void> _startRead() async {
    if (_handle != null) return;
    try {
      _handle = await _nfc.startRead(
        onResult: (outcome) async {
          switch (outcome) {
            case NfcReadSuccess(uuid: final uuid):
              await _handleTap(uuid);
            case NfcReadFailure():
              // Silent — user likely tapped a random tag. Don't spam.
              break;
          }
          // Restart for the next tap.
          _handle = null;
          if (mounted) _startRead();
        },
      );
    } catch (_) {
      // NFC unavailable or platform exception — app stays usable without
      // foreground NFC dispatch (pair / bind flows still work via their own
      // scoped sessions).
      _handle = null;
    }
  }

  Future<void> _stopRead() async {
    final h = _handle;
    _handle = null;
    await h?.stop();
  }

  Future<void> _handleTap(String uuid) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(tapFireServiceProvider).fire(uuid);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      switch (outcome) {
        case TapFireSuccess(sceneName: final name):
          _toast(l10n.tapFiredSnackbar(name));
        case TapFireFailure(message: final msg):
          _toast(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    final ctx = context;
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Symbols.error : Symbols.check, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError
            ? TwilightHearthColors.danger
            : TwilightHearthColors.charcoal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_busy)
          const Positioned(top: 80, right: 16, child: _FiringIndicator()),
      ],
    );
  }
}

class _FiringIndicator extends StatelessWidget {
  const _FiringIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TwilightHearthColors.charcoal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TwilightHearthColors.cream,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.tapFiringStatus,
            style: const TextStyle(
              color: TwilightHearthColors.cream,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
