import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// What a colour means: in your favour, against you, soon, or nothing.
enum Tone {
  neutral(AppColors.subtle, AppColors.textSecondary),
  brand(AppColors.brandSubtle, AppColors.brand),
  positive(AppColors.positiveSubtle, AppColors.positive),
  negative(AppColors.negativeSubtle, AppColors.negative),
  warning(AppColors.warningSubtle, AppColors.warning);

  const Tone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  /// The colour a bar or gauge in this tone is filled with.
  Color get data => switch (this) {
    Tone.neutral => AppColors.dataSecondary,
    Tone.brand => AppColors.dataPrimary,
    Tone.positive => AppColors.dataPositive,
    Tone.negative => AppColors.dataNegative,
    Tone.warning => AppColors.dataWarning,
  };
}

/// The Figma Tag: a small pill with an optional icon.
class StatusTag extends StatelessWidget {
  const StatusTag({
    required this.label,
    this.tone = Tone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.full)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone.foreground),
            const SizedBox(width: AppSpace.s4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
