import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_tile.dart';
import '../logic/purchase_summary.dart';

/// What saving the purchase did, once it is written.
class PurchaseSavedView extends StatelessWidget {
  const PurchaseSavedView({
    required this.summary,
    this.onViewPurchase,
    super.key,
  });

  final PurchaseSummary summary;

  /// Opens the saved purchase. Null hides the link.
  final VoidCallback? onViewPurchase;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onViewPurchase = this.onViewPurchase;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      AppSpace.s32,
                      AppSpace.page,
                      AppSpace.s24,
                    ),
                    children: [
                      const Center(
                        child: IconTile(
                          icon: Symbols.check_circle_rounded,
                          size: 72,
                          iconSize: 40,
                          circle: true,
                          background: AppColors.positiveSubtle,
                          color: AppColors.positive,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s16),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          'Purchase saved',
                          textAlign: TextAlign.center,
                          style: text.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        savedHeadline(summary),
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s24),
                      RowGroup(
                        children: [
                          for (final outcome in outcomesOf(summary))
                            _OutcomeRow(outcome: outcome),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.s8,
                  AppSpace.page,
                  AppSpace.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: 'Done',
                      expand: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    if (onViewPurchase != null) ...[
                      const SizedBox(height: AppSpace.s8),
                      Center(
                        child: AppButton(
                          label: 'View purchase',
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.medium,
                          onPressed: onViewPurchase,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({required this.outcome});

  final Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final icon = switch (outcome.kind) {
      OutcomeKind.spend => Symbols.receipt_long_rounded,
      OutcomeKind.restocked => Symbols.inventory_2_rounded,
      OutcomeKind.created => Symbols.add_rounded,
      OutcomeKind.cleared => Symbols.shopping_cart_rounded,
      OutcomeKind.learned => Symbols.auto_awesome_rounded,
      OutcomeKind.spendOnly => Symbols.link_off_rounded,
      OutcomeKind.photo => switch (outcome.tone) {
        OutcomeTone.warning => Symbols.cloud_off_rounded,
        OutcomeTone.negative => Symbols.hide_image_rounded,
        OutcomeTone.positive => Symbols.cloud_done_rounded,
        OutcomeTone.neutral => Symbols.cloud_upload_rounded,
      },
    };
    final color = switch (outcome.tone) {
      OutcomeTone.neutral => AppColors.textTertiary,
      OutcomeTone.positive => AppColors.positive,
      OutcomeTone.warning => AppColors.warning,
      OutcomeTone.negative => AppColors.negative,
    };
    final detail = outcome.detail;

    return AppRow(
      leading: IconTile(
        icon: icon,
        size: 36,
        iconSize: 20,
        radius: AppRadius.sm,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            outcome.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge,
          ),
          // Why the photo was not kept is worth reading in full.
          if (detail != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              detail,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Text(
          outcome.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: text.bodyMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
