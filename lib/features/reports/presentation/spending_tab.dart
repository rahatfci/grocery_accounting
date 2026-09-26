import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/level_bar.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_tag.dart';
import '../../items/presentation/category_icons.dart';
import '../../members/logic/household.dart';
import '../../members/presentation/household_cubit.dart';
import '../../purchases/logic/money.dart';
import '../../purchases/presentation/purchase_row.dart';
import '../../purchases/presentation/purchases_page.dart';
import '../logic/report_month.dart';
import '../logic/spending_report.dart';
import '../logic/spending_view.dart';
import 'reports_cubit.dart';
import 'reports_state.dart';

/// How many purchases the tab lists before `See all`.
const _recentPurchases = 3;

/// The Spending tab: one month's total against the last, who paid against
/// the equal share, where the money went, and the latest purchases.
class SpendingTab extends StatelessWidget {
  const SpendingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const LargeTitleBar(title: 'Spending', action: _ExportButton()),
          Expanded(
            child: BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                final cubit = context.read<ReportsCubit>();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= wideLayoutWidth;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 1100 : 560,
                        ),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.page,
                            AppSpace.s4,
                            AppSpace.page,
                            AppSpace.s32,
                          ),
                          children: [
                            MonthSwitcher(
                              label: monthLabel(state.month),
                              onPrevious: cubit.showPreviousMonth,
                              onNext: state.canViewNext
                                  ? cubit.showNextMonth
                                  : null,
                            ),
                            const SizedBox(height: AppSpace.s20),
                            switch (state) {
                              ReportsLoading() => const _TotalSkeleton(),
                              ReportsFailure(:final failure) => AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      failure.message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    TextButton(
                                      onPressed: cubit.retry,
                                      child: const Text('Try again'),
                                    ),
                                  ],
                                ),
                              ),
                              ReportsLoaded(:final report) => _Report(
                                report: report,
                                wide: wide,
                              ),
                            },
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  const _ExportButton();

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    final cubit = context.read<ReportsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    final message = await cubit.exportMonth();
    if (!mounted) {
      return;
    }
    setState(() => _exporting = false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.select(
      (ReportsCubit cubit) => switch (cubit.state) {
        ReportsLoaded(:final report) => !report.isEmpty,
        _ => false,
      },
    );
    return RoundIconButton(
      icon: Symbols.ios_share_rounded,
      tooltip: 'Export this month',
      onPressed: ready && !_exporting ? _export : null,
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report, required this.wide});

  final SpendingReport report;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final household = context.select(
      (HouseholdCubit cubit) => cubit.state.household,
    );
    final total = _TotalCard(report: report);
    if (report.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          total,
          const SizedBox(height: AppSpace.s20),
          RowGroup(
            children: [
              NoteRow(
                icon: Symbols.receipt_long_rounded,
                text:
                    'Nothing recorded in ${monthName(report.month)}. Saved '
                    'purchases show up here.',
              ),
            ],
          ),
        ],
      );
    }

    final people = _WhoPaid(report: report, household: household);
    final breakdowns = [
      _Breakdown(
        title: 'By category',
        rows: report.byCategory,
        monthTotal: report.monthTotal,
        iconFor: _categoryRowIcon,
      ),
      const SizedBox(height: AppSpace.s20),
      _Breakdown(
        title: 'By shop',
        rows: report.byShop,
        monthTotal: report.monthTotal,
        iconFor: (_) => Symbols.storefront_rounded,
      ),
      const SizedBox(height: AppSpace.s20),
      _RecentPurchases(report: report, household: household),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                total,
                const SizedBox(height: AppSpace.s20),
                people,
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: breakdowns,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        total,
        const SizedBox(height: AppSpace.s20),
        people,
        const SizedBox(height: AppSpace.s20),
        ...breakdowns,
      ],
    );
  }
}

IconData _categoryRowIcon(ReportRow row) => switch (row.category) {
  final category? => categoryIcon(category),
  null when row.label == notItemisedLabel => Symbols.receipt_long_rounded,
  null => Symbols.help_rounded,
};

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final change = monthChange(report);
    final largest = report.monthTotal > report.previousMonthTotal
        ? report.monthTotal
        : report.previousMonthTotal;

    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total spent',
            style: text.labelMedium?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpace.s12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              formatEuro(report.monthTotal),
              style: text.displaySmall,
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (change != null)
                StatusTag(
                  label: change.label,
                  // Spending more than last month is against the household.
                  tone: switch (change.trend) {
                    Trend.up => Tone.negative,
                    Trend.down => Tone.positive,
                    Trend.flat => Tone.neutral,
                  },
                  icon: switch (change.trend) {
                    Trend.up => Symbols.trending_up_rounded,
                    Trend.down => Symbols.trending_down_rounded,
                    Trend.flat => Symbols.trending_flat_rounded,
                  },
                ),
              Text(
                purchaseCountLabel(report.purchaseCount),
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          _MonthBar(
            label: monthName(report.month),
            amount: report.monthTotal,
            level: barLevel(report.monthTotal, largest),
            color: AppColors.dataPrimary,
          ),
          const SizedBox(height: AppSpace.s8),
          _MonthBar(
            label: monthName(previousMonth(report.month)),
            amount: report.previousMonthTotal,
            level: barLevel(report.previousMonthTotal, largest),
            color: AppColors.dataSecondary,
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.amount,
    required this.level,
    required this.color,
  });

  final String label;
  final double amount;
  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: LevelBar(value: level, color: color, height: 8),
          ),
          const SizedBox(width: AppSpace.s12),
          Text(
            formatEuro(amount),
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WhoPaid extends StatelessWidget {
  const _WhoPaid({required this.report, required this.household});

  final SpendingReport report;
  final Household household;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = equalShareNote(report);
    final largest = largestPaid(report);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Who paid'),
        if (note != null) ...[
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              const Icon(
                Symbols.group_rounded,
                size: 18,
                color: AppColors.iconSecondary,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  note,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s12),
        RowGroup(
          children: [
            for (final spend in report.byPerson)
              _MemberRow(
                spend: spend,
                household: household,
                level: barLevel(spend.paid, largest),
              ),
          ],
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.spend,
    required this.household,
    required this.level,
  });

  final MemberSpend spend;
  final Household household;
  final double level;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = !spend.hasShare || spend.matchesShare
        ? Tone.neutral
        : spend.difference > 0
        ? Tone.positive
        : Tone.negative;
    final balanceColor = tone == Tone.neutral
        ? AppColors.textPrimary
        : tone.foreground;
    final caption = text.bodySmall?.copyWith(color: AppColors.textTertiary);

    return AppRow(
      leading: MemberAvatar(
        initials: household.initialsOf(spend.memberId),
        tone: household.toneOf(spend.memberId),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spend.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLargeStrong,
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Paid ${formatEuro(spend.paid)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: caption,
          ),
          const SizedBox(height: AppSpace.s4),
          LevelBar(
            value: level,
            color: tone == Tone.neutral ? AppColors.dataSecondary : tone.data,
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spend.hasShare)
            Text(
              // Home's glance says the same of a member exactly at the share.
              spend.matchesShare ? 'Even' : formatSignedEuro(spend.difference),
              style: text.bodyLargeStrong.copyWith(color: balanceColor),
            ),
          const SizedBox(height: AppSpace.s2),
          Text(balanceCaption(spend), style: caption),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.rows,
    required this.monthTotal,
    required this.iconFor,
  });

  final String title;
  final List<ReportRow> rows;
  final double monthTotal;
  final IconData Function(ReportRow row) iconFor;

  @override
  Widget build(BuildContext context) {
    final largest = rows.fold<double>(
      0,
      (largest, row) => row.amount > largest ? row.amount : largest,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpace.s12),
        RowGroup(
          children: [
            for (final row in rows)
              _BreakdownRow(
                icon: iconFor(row),
                label: row.label,
                amount: row.amount,
                level: barLevel(row.amount, largest),
                percent: percentOf(row.amount, monthTotal),
              ),
          ],
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.level,
    required this.percent,
  });

  final IconData icon;
  final String label;
  final double amount;
  final double level;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppRow(
      leading: IconTile(icon: icon, color: AppColors.iconSecondary),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMediumStrong,
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(formatEuro(amount), style: text.bodyMediumStrong),
            ],
          ),
          const SizedBox(height: AppSpace.s6),
          Row(
            children: [
              Expanded(
                child: LevelBar(value: level, color: AppColors.dataPrimary),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                '$percent%',
                style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPurchases extends StatelessWidget {
  const _RecentPurchases({required this.report, required this.household});

  final SpendingReport report;
  final Household household;

  @override
  Widget build(BuildContext context) {
    final recent = report.purchases.take(_recentPurchases);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Purchases',
          count: report.purchaseCount,
          actionLabel: 'See all',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PurchasesPage()),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        RowGroup(
          children: [
            for (final purchase in recent)
              PurchaseRow(
                purchase: purchase,
                payerName: household.nameOf(purchase.paidByUserId),
                withDate: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _TotalSkeleton extends StatelessWidget {
  const _TotalSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: AppCard(
        radius: AppRadius.xxl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 80),
            SizedBox(height: AppSpace.s12),
            SkeletonBox(width: 180, height: 40),
            SizedBox(height: AppSpace.s16),
            SkeletonBox(width: 220),
            SizedBox(height: AppSpace.s16),
            SkeletonBox(height: 8),
            SizedBox(height: AppSpace.s8),
            SkeletonBox(height: 8),
          ],
        ),
      ),
    );
  }
}
