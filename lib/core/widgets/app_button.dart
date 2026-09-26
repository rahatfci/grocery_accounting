import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, tonal, ghost, danger }

/// The design's three button heights: 52, 44 and 36.
enum AppButtonSize {
  large(52, AppRadius.lg, 20),
  medium(44, AppRadius.md, 20),
  small(36, AppRadius.md, 18);

  const AppButtonSize(this.height, this.radius, this.iconSize);

  final double height;
  final double radius;
  final double iconSize;
}

/// The Figma Button component: one of five variants at one of three sizes.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.expand = false,
    this.busy = false,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Fills the width it is given rather than hugging its label.
  final bool expand;

  /// Shows a spinner in place of the label and refuses taps, while the
  /// action it started is still running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.brand, AppColors.onBrand, null),
      AppButtonVariant.secondary => (
        AppColors.surface,
        AppColors.textPrimary,
        const BorderSide(color: AppColors.borderDefault),
      ),
      AppButtonVariant.tonal => (AppColors.brandSubtle, AppColors.brand, null),
      AppButtonVariant.ghost => (Colors.transparent, AppColors.brand, null),
      AppButtonVariant.danger => (
        AppColors.negativeSubtle,
        AppColors.negative,
        null,
      ),
    };
    final isPrimary = variant == AppButtonVariant.primary;
    final labelStyle = size == AppButtonSize.large
        ? text.labelLarge
        : text.bodyMediumStrong;

    final style = FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: isPrimary
          ? AppColors.brand.withValues(alpha: 0.4)
          : background,
      disabledForegroundColor: isPrimary
          ? AppColors.onBrand.withValues(alpha: 0.9)
          : foreground.withValues(alpha: 0.4),
      minimumSize: Size(size.height, size.height),
      fixedSize: expand ? Size.fromHeight(size.height) : null,
      padding: EdgeInsets.symmetric(
        horizontal: size == AppButtonSize.large ? AppSpace.s20 : AppSpace.s12,
      ),
      textStyle: labelStyle,
      iconSize: size.iconSize,
      side: border,
      elevation: 0,
      // A large or medium button already meets the 44 px touch minimum; a
      // small one keeps the padded 48 px target around its 36 px shape.
      tapTargetSize: size == AppButtonSize.small
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.radius),
      ),
    );

    final Widget child = busy
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    final button = icon != null && !busy
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: child,
          )
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: style,
            child: child,
          );

    return busy
        ? Semantics(label: label, liveRegion: true, child: button)
        : button;
  }
}
