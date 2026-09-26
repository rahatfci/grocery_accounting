import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum TopBarLeading { back, close }

/// The Figma Top bar: back or close, a centred title, one optional action.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    this.leading = TopBarLeading.back,
    this.onLeading,
    this.actions = const [],
    super.key,
  });

  final String title;
  final TopBarLeading leading;

  /// Defaults to popping the route.
  final VoidCallback? onLeading;

  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip) = switch (leading) {
      TopBarLeading.back => (Symbols.arrow_back_rounded, 'Back'),
      TopBarLeading.close => (Symbols.close_rounded, 'Close'),
    };
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onLeading ?? () => Navigator.of(context).maybePop(),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        ...actions,
        const SizedBox(width: AppSpace.s8),
      ],
    );
  }
}

/// The Figma Top bar / Large: a tab's left-aligned title and a tonal action.
class LargeTitleBar extends StatelessWidget {
  const LargeTitleBar({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s8,
        AppSpace.page,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

enum RoundButtonStyle { plain, tonal, outlined }

/// The Figma Icon button: 40 px and round.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.style = RoundButtonStyle.tonal,
    this.color = AppColors.iconPrimary,
    this.background,
    super.key,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables it, which the outlined style shows at 40%.
  final VoidCallback? onPressed;

  final RoundButtonStyle style;
  final Color color;

  /// Overrides the style's own background.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        foregroundColor: color,
        disabledForegroundColor: color,
        backgroundColor:
            background ??
            switch (style) {
              RoundButtonStyle.plain => Colors.transparent,
              RoundButtonStyle.tonal => AppColors.subtle,
              RoundButtonStyle.outlined => AppColors.surface,
            },
        disabledBackgroundColor: style == RoundButtonStyle.outlined
            ? AppColors.surface
            : null,
        side: style == RoundButtonStyle.outlined
            ? const BorderSide(color: AppColors.borderDefault)
            : null,
      ),
    );
    return enabled ? button : Opacity(opacity: 0.4, child: button);
  }
}

/// The Figma Action bar: replaces the bottom navigation on forms and review.
class ActionBar extends StatelessWidget {
  const ActionBar({
    required this.child,
    this.summaryLabel,
    this.summaryValue,
    super.key,
  });

  /// The primary action, stretched to fill what the summary leaves.
  final Widget child;

  final String? summaryLabel;
  final String? summaryValue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summaryLabel = this.summaryLabel;
    final summaryValue = this.summaryValue;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: AppShadows.bar,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpace.s12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s12,
            AppSpace.page,
            AppSpace.s4,
          ),
          child: Row(
            children: [
              if (summaryLabel != null && summaryValue != null) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summaryLabel,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(summaryValue, style: text.titleMedium),
                  ],
                ),
                const SizedBox(width: AppSpace.s16),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Figma Month switcher: previous, the month, next.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final String label;
  final VoidCallback? onPrevious;

  /// Null at the current month: a later one can only ever be empty.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(
          icon: Symbols.chevron_left_rounded,
          tooltip: 'Previous month',
          style: RoundButtonStyle.outlined,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        RoundIconButton(
          icon: Symbols.chevron_right_rounded,
          tooltip: 'Next month',
          style: RoundButtonStyle.outlined,
          onPressed: onNext,
        ),
      ],
    );
  }
}
