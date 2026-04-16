// All scenes for one paired bridge. Tapping a scene opens an action sheet:
// "Fire now" (test) or "Bind to NFC card". Pull-to-refresh triggers resync.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/tap/tap_fire_service.dart';
import '../../core/theme/twilight_hearth_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../bind/bind_card_sheet.dart';
import '../common/widgets.dart';

class BridgeScenesScreen extends ConsumerStatefulWidget {
  const BridgeScenesScreen({required this.bridge, super.key});

  final Bridge bridge;

  @override
  ConsumerState<BridgeScenesScreen> createState() => _BridgeScenesScreenState();
}

class _BridgeScenesScreenState extends ConsumerState<BridgeScenesScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    final registry = ref.read(bridgeClientRegistryProvider);
    final client = registry.byRowId(widget.bridge.id);
    if (client == null) return;
    setState(() => _refreshing = true);
    try {
      final db = ref.read(databaseProvider);
      final scenes = await client.api.listScenes();
      final now = DateTime.now();
      await db.transaction(() async {
        await (db.update(db.scenes)
              ..where((t) => t.bridgeRowId.equals(widget.bridge.id)))
            .write(const ScenesCompanion(orphaned: Value(true)));
        for (final s in scenes) {
          await db
              .into(db.scenes)
              .insertOnConflictUpdate(
                ScenesCompanion.insert(
                  id: s.id,
                  bridgeRowId: widget.bridge.id,
                  name: s.name,
                  roomId: Value(s.roomId),
                  roomName: Value(s.roomName),
                  zoneId: Value(s.zoneId),
                  zoneName: Value(s.zoneName),
                  orphaned: const Value(false),
                  lastSynced: now,
                ),
              );
        }
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scenesAsync = ref.watch(scenesForBridgeProvider(widget.bridge.id));

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TwilightHearthGradients.scaffoldBody,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.bridge.name ?? l10n.homeBridgeFallbackName),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: scenesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              children: [
                Center(child: Text(l10n.commonErrorMessage(e.toString()))),
              ],
            ),
            data: (scenes) {
              if (scenes.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    const Icon(
                      Symbols.sunny,
                      size: 48,
                      color: TwilightHearthColors.plum,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.scenesEmptyTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.scenesEmptyDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: TwilightHearthColors.text2,
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: scenes.length,
                itemBuilder: (ctx, i) =>
                    _SceneTile(scene: scenes[i], bridge: widget.bridge),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SceneTile extends ConsumerWidget {
  const _SceneTile({required this.scene, required this.bridge});

  final Scene scene;
  final Bridge bridge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = scene.roomName ?? scene.zoneName;
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
            color: TwilightHearthColors.amber.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Symbols.sunny,
            color: TwilightHearthColors.plumDeep,
          ),
        ),
        title: Text(
          scene.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Symbols.more_horiz),
        onTap: () => _showSceneActions(context, ref, scene),
      ),
    );
  }

  void _showSceneActions(BuildContext context, WidgetRef ref, Scene scene) {
    final l10n = AppLocalizations.of(context)!;
    showHueTapSheet<void>(
      context,
      header: Row(
        children: [
          const Icon(Symbols.sunny, color: TwilightHearthColors.plumDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              scene.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Symbols.play_arrow),
            title: Text(l10n.sceneActionFireNowTitle),
            subtitle: Text(l10n.sceneActionFireNowSubtitle),
            onTap: () async {
              Navigator.pop(ctx);
              final outcome = await ref
                  .read(tapFireServiceProvider)
                  .fireDirect(bridgeRowId: bridge.id, sceneId: scene.id);
              if (!context.mounted) return;
              final message = switch (outcome) {
                TapFireSuccess(:final sceneName) => l10n.sceneFiredSnackbar(
                  sceneName,
                ),
                TapFireFailure(:final message) => message,
              };
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            },
          ),
          ListTile(
            leading: const Icon(Symbols.nfc),
            title: Text(l10n.sceneActionBindTitle),
            subtitle: Text(l10n.sceneActionBindSubtitle),
            onTap: () {
              Navigator.pop(ctx);
              showHueTapSheet<void>(
                context,
                isScrollControlled: true,
                builder: (_) => BindCardSheet(bridge: bridge, scene: scene),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
