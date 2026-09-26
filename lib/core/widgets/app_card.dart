import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A white card on the app background. Cards are flat: the contrast with the
/// background is the edge.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s20),
    this.radius = AppRadius.xl,
    this.color = AppColors.surface,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Rows stacked in one card with a divider between each, the way every list
/// in the design is drawn.
class RowGroup extends StatelessWidget {
  const RowGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const Divider(),
            child,
          ],
        ],
      ),
    );
  }
}

/// One row of a [RowGroup]: leading, a flexible body, trailing.
class AppRow extends StatelessWidget {
  const AppRow({
    required this.body,
    this.leading,
    this.trailing,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.s16,
      vertical: AppSpace.s12,
    ),
    super.key,
  });

  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Null keeps the card's white.
  final Color? color;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final trailing = this.trailing;
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: AppSpace.s12),
          ],
          Expanded(child: body),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s12),
            trailing,
          ],
        ],
      ),
    );
    return Material(
      color: color ?? Colors.transparent,
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}

/// A row's title and optional subtitle, truncated rather than wrapped.
class RowText extends StatelessWidget {
  const RowText({
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.gap = AppSpace.s2,
    super.key,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              titleStyle ??
              text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          SizedBox(height: gap),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                subtitleStyle ??
                text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}
