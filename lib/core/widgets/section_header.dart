import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A section title with an optional count pill and an optional action link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = this.count;
    final actionLabel = this.actionLabel;

    return Row(
      children: [
        // The title and its count share what the action leaves, so the
        // action always sits at the far edge.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpace.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s8,
                    vertical: AppSpace.s2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.subtle,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.full),
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              textStyle: text.bodyMediumStrong,
            ),
            child: Text(actionLabel),
          ),
      ],
    );
  }
}
