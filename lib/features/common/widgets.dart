// Shared UI helpers — modal sheets and status blocks reused across screens.

import 'package:flutter/material.dart';

import '../../core/theme/twilight_hearth_theme.dart';

/// Opens a bottom sheet with HueTap's standard chrome: cream background,
/// rounded top, drag handle, and (optionally) a title row. `builder` returns
/// the sheet's body; `header` overrides the default title row when custom
/// content is needed (e.g. an icon + label).
Future<T?> showHueTapSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  Widget? header,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: TwilightHearthColors.creamAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: header,
            )
          else if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          Flexible(child: builder(ctx)),
        ],
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: TwilightHearthColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A large round icon + title + optional description, used for
/// success/error/waiting status cards across pair, bind and fire flows.
class HueTapStatusCard extends StatelessWidget {
  const HueTapStatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.iconColor,
    this.iconGradient,
    this.iconSize = 120,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? description;

  /// Either [iconColor] or [iconGradient] — the circle's background.
  final Color? iconColor;
  final Gradient? iconGradient;
  final double iconSize;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    assert(
      iconColor != null || iconGradient != null,
      'Provide iconColor or iconGradient',
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: iconColor,
              gradient: iconGradient,
              shape: BoxShape.circle,
              boxShadow: TwilightHearthShadows.elev,
            ),
            child: Icon(icon, color: Colors.white, size: iconSize * 0.53),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TwilightHearthColors.text2,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[const SizedBox(height: 32), ...actions],
        ],
      ),
    );
  }
}
