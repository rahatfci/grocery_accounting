import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/status_tag.dart';
import '../../purchases/logic/money.dart';
import '../../reports/logic/report_month.dart';
import '../../reports/logic/spend_glance.dart';
import '../../reports/presentation/reports_cubit.dart';
import '../../reports/presentation/reports_state.dart';
import '../../shell/presentation/shell_cubit.dart';

/// One line of money above the scan hero: the month's spend, the change on
/// last month, and the member against their share. Opens Spending.
///
/// Reads the [ReportsCubit] Home provides for the current month. A household
/// that has not spent anything this month or last sees nothing here.
class MonthGlanceCard extends StatelessWidget {
  const MonthGlanceCard({required this.memberId, super.key});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) => switch (state) {
        ReportsLoading() => const _GlanceSkeleton(),
        ReportsFailure(:final failure) => AppCard(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  failure.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.read<ReportsCubit>().retry(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        ReportsLoaded(:final report) => switch (spendGlanceFor(
          report,
          memberId,
        )) {
          final glance when glance.hasSpending => _Glance(glance: glance),
          _ => const SizedBox.shrink(),
        },
      },
    );
  }
}

class _Glance extends StatelessWidget {
  const _Glance({required this.glance});

  final SpendGlance glance;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final balance = glance.balance;

    return AppCard(
      onTap: () => context.read<ShellCubit>().show(AppTab.spending),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${monthName(glance.month)} spend',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              _ChangeTag(glance: glance),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(formatEuro(glance.total), style: text.headlineLarge),
          if (balance != null) ...[
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                StatusTag(
                  label: balance.matchesShare
                      ? 'Even'
                      : formatSignedEuro(balance.difference),
                  tone: balance.matchesShare
                      ? Tone.neutral
                      : balance.difference > 0
                      ? Tone.positive
                      : Tone.negative,
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    '${_shareWording(balance.difference, balance.matchesShare)}'
                    ' · you paid ${formatEuro(balance.paid)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _shareWording(double difference, bool even) {
  if (even) {
    return 'exactly your share';
  }
  return difference > 0 ? 'over your share' : 'under your share';
}

/// Spending more than last month is against the household, so it is red.
class _ChangeTag extends StatelessWidget {
  const _ChangeTag({required this.glance});

  final SpendGlance glance;

  @override
  Widget build(BuildContext context) {
    final fraction = glance.changeFraction;
    if (fraction == null) {
      return const SizedBox.shrink();
    }
    final previous = monthName(previousMonth(glance.month));
    final percent = (fraction * 100).round();
    if (percent == 0) {
      return StatusTag(label: 'Same as $previous');
    }
    return StatusTag(
      label: '${percent.abs()}% vs $previous',
      tone: percent > 0 ? Tone.negative : Tone.positive,
      icon: percent > 0
          ? Symbols.trending_up_rounded
          : Symbols.trending_down_rounded,
    );
  }
}

class _GlanceSkeleton extends StatelessWidget {
  const _GlanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 110),
          SizedBox(height: AppSpace.s12),
          SkeletonBox(width: 160, height: 32),
          SizedBox(height: AppSpace.s12),
          SkeletonBox(width: 220),
        ],
      ),
    );
  }
}
