import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/notes.dart';
import '../logic/money.dart';
import '../logic/purchase_draft.dart';
import '../logic/review_lines.dart';

/// A line read off the receipt that nobody has matched. Tinted, with a red
/// edge, because saving it as it is restocks nothing.
class UnmatchedLineRow extends StatelessWidget {
  const UnmatchedLineRow({
    required this.line,
    required this.onMatch,
    super.key,
  });

  final PurchaseDraftLine line;
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.negativeSubtle,
        border: Border(left: BorderSide(color: AppColors.negative, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s12,
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.link_off_rounded,
            size: 22,
            color: AppColors.negative,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLargeStrong,
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  lineDetail(line),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.negative,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Text(formatEuro(line.lineTotal), style: text.bodyLargeStrong),
          const SizedBox(width: AppSpace.s8),
          AppButton(
            label: 'Match',
            size: AppButtonSize.small,
            onPressed: onMatch,
          ),
        ],
      ),
    );
  }
}

/// A line that restocks the pantry: matched by a member, by what an earlier
/// purchase taught, or to an item this purchase creates.
class MatchedLineRow extends StatelessWidget {
  const MatchedLineRow({required this.line, required this.onTap, super.key});

  final PurchaseDraftLine line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = lineStateOf(line);
    final (icon, color, label) = switch (state) {
      LineState.learned => (
        Symbols.auto_awesome_rounded,
        AppColors.brand,
        'Learned',
      ),
      LineState.newItem => (Symbols.add_rounded, AppColors.brand, 'New item'),
      LineState.matched || LineState.unmatched => (
        Symbols.check_circle_rounded,
        AppColors.positive,
        'Matched',
      ),
    };
    return AppRow(
      onTap: onTap,
      leading: Icon(icon, size: 22, color: color, semanticLabel: label),
      body: RowText(
        title: line.label,
        subtitle: lineDetail(line),
        subtitleStyle: text.bodySmall?.copyWith(
          color: state == LineState.matched
              ? AppColors.textTertiary
              : AppColors.brand,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatEuro(line.lineTotal), style: text.bodyLargeStrong),
          const SizedBox(width: AppSpace.s8),
          const Icon(
            Symbols.chevron_right_rounded,
            size: 20,
            color: AppColors.iconSecondary,
          ),
        ],
      ),
    );
  }
}

/// A line that can be swiped away. A screen reader gets the same through a
/// custom action.
class RemovableLine extends StatelessWidget {
  const RemovableLine({
    required this.line,
    required this.onRemove,
    required this.child,
    super.key,
  });

  /// Keys the swipe, so removing one line never hands its dismissed state
  /// to the line that takes its place.
  final PurchaseDraftLine line;

  /// Null while the purchase is being saved.
  final VoidCallback? onRemove;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onRemove = this.onRemove;
    if (onRemove == null) {
      return child;
    }
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Remove line'): onRemove,
      },
      child: Dismissible(
        key: ObjectKey(line),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          color: AppColors.negative,
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: AppSpace.s20),
          child: const Icon(Symbols.delete_rounded, color: AppColors.onBrand),
        ),
        child: child,
      ),
    );
  }
}

/// Stands in for the lines while the receipt is still being read.
class LinesSkeleton extends StatelessWidget {
  const LinesSkeleton({super.key});

  static const _widths = [(150.0, 90.0), (110.0, 120.0), (170.0, 80.0)];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RowGroup(
        children: [
          for (final (title, detail) in _widths)
            Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Row(
                children: [
                  const SkeletonBox(width: 22, height: 22, radius: 11),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: title),
                        const SizedBox(height: AppSpace.s8),
                        SkeletonBox(width: detail, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  const SkeletonBox(width: 48),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The lines against the receipt total. They are allowed to differ:
/// discounts, deposits and unpriced lines are all normal, so this informs
/// and never refuses.
class LinesTotalCard extends StatelessWidget {
  const LinesTotalCard({
    required this.linesTotal,
    required this.total,
    super.key,
  });

  final double linesTotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.only(top: AppSpace.s4, bottom: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Fact(label: 'Lines add up to', value: formatEuro(linesTotal)),
          _Fact(label: 'Receipt total', value: formatEuro(total)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            child: Text(
              linesGapNote(linesTotal: linesTotal, total: total),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Text(value, style: text.bodyMediumStrong),
        ],
      ),
    );
  }
}
