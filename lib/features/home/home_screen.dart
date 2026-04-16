// App home — paired bridges + bound cards list, or the empty-state CTA
// that kicks off the pair flow.
//
// This screen is also where tap-to-fire outcomes are surfaced (via a
// SnackBar). The [TapHandler] widget wraps the screen to listen for NFC
// discoveries while the app is in the foreground.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/twilight_hearth_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/widgets.dart';
import '../pair/discovery_screen.dart';
import '../scenes/bridge_scenes_screen.dart';
import '../tap/tap_handler.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bootstrap the registry once — fire and forget.
    ref.watch(bridgeClientsBootstrapProvider);

    final l10n = AppLocalizations.of(context)!;
    final bridgesAsync = ref.watch(pairedBridgesProvider);
    final bindingsAsync = ref.watch(cardBindingsProvider);

    return TapHandler(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: TwilightHearthGradients.scaffoldBody,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l10n.homeAppBarTitle),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: bridgesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(l10n.commonErrorMessage(e.toString()))),
            data: (bridges) {
              if (bridges.isEmpty) {
                return const _EmptyBridgesState();
              }
              return bindingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.commonErrorMessage(e.toString()))),
                data: (bindings) =>
                    _PairedState(bridges: bridges, bindings: bindings),
              );
            },
          ),
          floatingActionButton: bridgesAsync.maybeWhen(
            data: (bridges) => bridges.isEmpty
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _showAddMenu(context, bridges),
                    backgroundColor: TwilightHearthColors.charcoal,
                    foregroundColor: TwilightHearthColors.cream,
                    icon: const Icon(Symbols.add),
                    label: Text(l10n.homeNewActionLabel),
                  ),
            orElse: () => null,
          ),
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context, List<Bridge> bridges) {
    final l10n = AppLocalizations.of(context)!;
    showHueTapSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Symbols.nfc),
            title: Text(l10n.homeAddSheetBindCardTitle),
            subtitle: Text(l10n.homeAddSheetBindCardSubtitle),
            onTap: () {
              Navigator.pop(ctx);
              // If there's one bridge, jump straight to its scenes.
              // Otherwise show a picker.
              if (bridges.length == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BridgeScenesScreen(bridge: bridges.first),
                  ),
                );
              } else {
                _pickBridgeForScenes(context, bridges);
              }
            },
          ),
          ListTile(
            leading: const Icon(Symbols.hub),
            title: Text(l10n.homeAddSheetPairBridgeTitle),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DiscoveryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _pickBridgeForScenes(BuildContext context, List<Bridge> bridges) {
    final l10n = AppLocalizations.of(context)!;
    showHueTapSheet<void>(
      context,
      title: l10n.homePickBridgeSheetTitle,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in bridges)
            ListTile(
              leading: const Icon(Symbols.hub),
              title: Text(b.name ?? b.ip),
              subtitle: Text(b.ip),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BridgeScenesScreen(bridge: b),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmptyBridgesState extends StatelessWidget {
  const _EmptyBridgesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: TwilightHearthGradients.primary,
                shape: BoxShape.circle,
                boxShadow: TwilightHearthShadows.elev,
              ),
              child: const Icon(
                Symbols.hub,
                color: TwilightHearthColors.cream,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.homeEmptyBridgesTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homeEmptyBridgesDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TwilightHearthColors.text2,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DiscoveryScreen(),
                ),
              ),
              icon: const Icon(Symbols.radar),
              label: Text(l10n.homeEmptyBridgesCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairedState extends ConsumerWidget {
  const _PairedState({required this.bridges, required this.bindings});

  final List<Bridge> bridges;
  final List<CardBinding> bindings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Bridges strip -----------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.homeSectionBridges,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: TwilightHearthColors.text2,
            ),
          ),
        ),
        for (final b in bridges) _BridgeCard(bridge: b),

        const SizedBox(height: 20),

        // Cards -------------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.homeSectionBoundCards,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: TwilightHearthColors.text2,
            ),
          ),
        ),
        if (bindings.isEmpty)
          _EmptyCardsState(bridges: bridges)
        else
          for (final b in bindings) _CardTile(binding: b),
      ],
    );
  }
}

class _BridgeCard extends StatelessWidget {
  const _BridgeCard({required this.bridge});
  final Bridge bridge;

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          bridge.name ?? AppLocalizations.of(context)!.homeBridgeFallbackName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${bridge.ip} · ${bridge.bridgeId}'),
        trailing: IconButton(
          icon: const Icon(Symbols.chevron_right),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => BridgeScenesScreen(bridge: bridge),
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => BridgeScenesScreen(bridge: bridge),
          ),
        ),
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  const _EmptyCardsState({required this.bridges});
  final List<Bridge> bridges;

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
          const Icon(Symbols.nfc, size: 32, color: TwilightHearthColors.plum),
          const SizedBox(height: 12),
          Text(
            l10n.homeEmptyCardsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homeEmptyCardsDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: TwilightHearthColors.text2,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              if (bridges.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BridgeScenesScreen(bridge: bridges.first),
                ),
              );
            },
            icon: const Icon(Symbols.add),
            label: Text(l10n.homeEmptyCardsCta),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.binding});
  final CardBinding binding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            color: TwilightHearthColors.lilac.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Symbols.nfc, color: TwilightHearthColors.plumDeep),
        ),
        title: Text(
          binding.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          binding.lastTapped != null
              ? AppLocalizations.of(context)!.homeCardTapsWithLastSubtitle(
                  binding.tapCount,
                  binding.lastTapped.toString(),
                )
              : AppLocalizations.of(
                  context,
                )!.homeCardTapsSubtitle(binding.tapCount),
        ),
        trailing: IconButton(
          icon: const Icon(
            Symbols.delete_outline,
            color: TwilightHearthColors.danger,
          ),
          onPressed: () async {
            final db = ref.read(databaseProvider);
            await (db.update(db.cardBindings)
                  ..where((t) => t.uuid.equals(binding.uuid)))
                .write(const CardBindingsCompanion(revoked: Value(true)));
          },
        ),
      ),
    );
  }
}
