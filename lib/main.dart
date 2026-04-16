// Entry point for HueTap. This file is intentionally minimal — feature work
// lives under lib/features/ per SPEC §4.2. The home widget here is a
// placeholder that will be replaced by the onboarding router in Phase 1 of the
// build plan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/twilight_hearth_theme.dart';
import 'l10n/gen/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: HueTapApp()));
}

class HueTapApp extends StatelessWidget {
  const HueTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: TwilightHearthTheme.build(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _ScaffoldingPlaceholder(),
    );
  }
}

class _ScaffoldingPlaceholder extends StatelessWidget {
  const _ScaffoldingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.scaffoldingPlaceholderTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.scaffoldingPlaceholderBody,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
