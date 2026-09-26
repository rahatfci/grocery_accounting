import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A tinted box with an icon and a line of guidance: tips, the learning note,
/// what happens next.
class InfoNote extends StatelessWidget {
  const InfoNote({
    required this.text,
    this.icon = Symbols.info_rounded,
    this.brand = false,
    super.key,
  });

  final String text;
  final IconData icon;

  /// The brand tint, used where the note describes something the app does
  /// for the household, such as learning a receipt line.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final foreground = brand ? AppColors.brand : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: brand ? AppColors.brandSubtle : AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: brand ? AppColors.brand : AppColors.iconSecondary,
          ),
          const SizedBox(width: AppSpace.s10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-line state inside a card: nothing running low, an empty list.
class NoteRow extends StatelessWidget {
  const NoteRow({
    required this.icon,
    required this.text,
    this.iconColor = AppColors.iconSecondary,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grey block standing in for content that is still loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 12,
    this.radius = AppRadius.xs,
    super.key,
  });

  /// Null fills the width.
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
