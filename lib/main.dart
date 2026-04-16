// Entry point for HueTap. Three launch paths diverge here:
//
//   1. Launched by the user tapping the icon → render HomeScreen as usual.
//   2. Launched by an NFC tap while the app was dead (cold start) → the
//      platform delivers `huetap://c/<uuid>` via the NDEF_DISCOVERED intent
//      filter. `app_links.getInitialLink()` surfaces it here; we render
//      FireScreen in place of HomeScreen so the scene fires and the app
//      closes without the user ever seeing the home view.
//   3. Launched by an NFC tap while the app was already running in the
//      background → Android delivers the URI via `onNewIntent`. The
//      `AppLinks().uriLinkStream` listener below pushes FireScreen on top
//      of whatever route is current and FireScreen's `SystemNavigator.pop()`
//      returns control to the previous app afterwards.
//
// Foreground taps (app already focused, card tapped on phone) still flow
// through `TapHandler` → `TapFireService`; we don't intercept them here.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/nfc/nfc_service.dart';
import 'core/theme/twilight_hearth_theme.dart';
import 'features/home/home_screen.dart';
import 'features/tap/fire_screen.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the initial launch URI *before* runApp so we can branch the home
  // route. `getInitialLink()` returns null for non-URI launches (icon, etc.)
  // and also for stream-delivered URIs received while the app was running.
  String? launchUuid;
  try {
    final initial = await AppLinks().getInitialLink();
    if (initial != null) {
      launchUuid = parseHuetapUuid(initial.toString());
    }
  } catch (_) {
    // If the plugin isn't wired up for some reason, fall back to a normal
    // launch — icon taps still work.
  }

  runApp(ProviderScope(child: HueTapApp(launchUuid: launchUuid)));
}

class HueTapApp extends StatefulWidget {
  const HueTapApp({this.launchUuid, super.key});

  /// UUID parsed from the launch NDEF intent, if any. Triggers the
  /// FireScreen cold-start path.
  final String? launchUuid;

  @override
  State<HueTapApp> createState() => _HueTapAppState();
}

class _HueTapAppState extends State<HueTapApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _uriSub;

  @override
  void initState() {
    super.initState();
    // Subscribe to onNewIntent URIs. This covers the warm-start path: the
    // app process is alive (in background), Android delivers the NDEF URI
    // without recreating MainActivity.
    try {
      _uriSub = AppLinks().uriLinkStream.listen(_onIncomingUri);
    } catch (_) {
      // Plugin unavailable in this environment (tests, etc.) — silently
      // skip. The cold-start path still works via `launchUuid`.
    }
  }

  @override
  void dispose() {
    _uriSub?.cancel();
    super.dispose();
  }

  void _onIncomingUri(Uri uri) {
    final uuid = parseHuetapUuid(uri.toString());
    if (uuid == null) return;
    final nav = _navKey.currentState;
    if (nav == null) return;
    // Push FireScreen on top of whatever's current. FireScreen auto-closes
    // the whole app via `SystemNavigator.pop()` when done, which in the
    // warm-start case returns the user to the previously focused app.
    nav.push<void>(MaterialPageRoute<void>(
      builder: (_) => FireScreen(uuid: uuid),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: TwilightHearthTheme.build(),
      themeMode: ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: widget.launchUuid != null
          ? FireScreen(uuid: widget.launchUuid!)
          : const HomeScreen(),
    );
  }
}
