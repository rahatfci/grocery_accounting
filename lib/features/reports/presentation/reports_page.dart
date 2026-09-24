import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/failure_message.dart';
import '../../items/data/item_repository.dart';
import '../../members/data/member_repository.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../purchases/logic/money.dart';
import '../data/csv_sharer.dart';
import '../logic/report_month.dart';
import '../logic/spending_report.dart';
import 'reports_cubit.dart';
import 'reports_state.dart';

/// Spending, owning the cubit for as long as the screen is on the stack.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportsCubit(
        purchases: context.read<PurchaseRepository>(),
        items: context.read<ItemRepository>(),
        members: context.read<MemberRepository>(),
        sharer: context.read<CsvSharer>(),
      ),
      child: const ReportsView(),
    );
  }
}

/// The screen without its cubit, so a test can supply one.
@visibleForTesting
class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending'),
        actions: const [_ExportButton()],
      ),
      body: SafeArea(
        child: BlocBuilder<ReportsCubit, ReportsState>(
          builder: (context, state) => Column(
            children: [
              // Outside the switch: a month that fails to load must still be
              // one the member can navigate away from.
              _MonthBar(month: state.month, canViewNext: state.canViewNext),
              Expanded(
                child: switch (state) {
                  ReportsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  ReportsFailure(:final failure) => _ReportsFailureBody(
                    message: failure.message,
                  ),
                  ReportsLoaded(:final report) => _ReportBody(report: report),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shares the month on screen as CSV. Only offered once the month has loaded
/// with something in it, since a file of headers helps nobody.
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
    if (_exporting) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) => IconButton(
        icon: const Icon(Icons.ios_share),
        tooltip: 'Export CSV',
        onPressed: switch (state) {
          ReportsLoaded(:final report) when !report.isEmpty => _export,
          _ => null,
        },
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.canViewNext});

  final DateTime month;
  final bool canViewNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ReportsCubit>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: cubit.showPreviousMonth,
          ),
          Expanded(
            child: Text(
              monthLabel(month),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            // Disabled rather than hidden, so the label stays centred instead
            // of jumping as the months change.
            onPressed: canViewNext ? cubit.showNextMonth : null,
          ),
        ],
      ),
    );
  }
}

/// Above this the report reads in two columns. Web and tablet are where
/// spending is reviewed sitting down, so the width is used when there is any.
const double _twoColumnWidth = 720;

@visibleForTesting
const Key oneColumnKey = Key('reports-one-column');

@visibleForTesting
const Key twoColumnKey = Key('reports-two-columns');

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            // A wide window centres the report rather than stretching every
            // row the full width of a desktop screen.
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthTotal(total: report.monthTotal),
                if (report.isEmpty)
                  const _NothingThisMonth()
                else if (constraints.maxWidth >= _twoColumnWidth)
                  _TwoColumns(report: report)
                else
                  _OneColumn(report: report),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OneColumn extends StatelessWidget {
  const _OneColumn({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: oneColumnKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PersonSection(report: report),
        _RowsSection(
          title: 'By category',
          rows: report.byCategory,
          nothing: 'No lines were recorded this month.',
        ),
        _RowsSection(
          title: 'By shop',
          rows: report.byShop,
          nothing: 'No shops were recorded this month.',
        ),
        _ComparisonSection(report: report),
      ],
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: twoColumnKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PersonSection(report: report),
              _ComparisonSection(report: report),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RowsSection(
                title: 'By category',
                rows: report.byCategory,
                nothing: 'No lines were recorded this month.',
              ),
              _RowsSection(
                title: 'By shop',
                rows: report.byShop,
                nothing: 'No shops were recorded this month.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The card every section is drawn in.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PersonSection extends StatelessWidget {
  const _PersonSection({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = report.byPerson
        .where((spend) => spend.hasShare)
        .map((spend) => spend.share)
        .firstOrNull;

    return _Section(
      title: 'By person',
      children: [
        if (share != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              // The divisor is named, because a `users` document appears only
              // once a member has signed in: an unexplained share invites the
              // wrong conclusion about who owes what.
              'Equal share across ${report.memberCount} '
              '${report.memberCount == 1 ? 'member' : 'members'}: '
              '${formatEuro(share)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final spend in report.byPerson) _MemberRow(spend: spend),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.spend});

  final MemberSpend spend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spend.displayName,
                  // Member-supplied text, so a long one truncates rather than
                  // pushing the amount off the row.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _againstShare(spend),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatEuro(spend.paid), style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// What this member paid against what they owed, in words.
String _againstShare(MemberSpend spend) {
  if (!spend.hasShare) {
    return 'Not in the household list';
  }
  if (spend.matchesShare) {
    return 'Exactly their share';
  }
  return spend.difference > 0
      ? '${formatEuro(spend.difference)} over their share'
      : '${formatEuro(-spend.difference)} under their share';
}

class _RowsSection extends StatelessWidget {
  const _RowsSection({
    required this.title,
    required this.rows,
    required this.nothing,
  });

  final String title;
  final List<ReportRow> rows;

  /// What to say when the section has nothing to list.
  final String nothing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Section(
      title: title,
      children: rows.isEmpty
          ? [Text(nothing, style: theme.textTheme.bodySmall)]
          : [for (final row in rows) _AmountRow(row: row)],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.row});

  final ReportRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              // A shop name and a member's own category are free text.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(formatEuro(row.amount), style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = report.monthOverMonthFraction;

    return _Section(
      title: 'Compared with ${monthLabel(previousMonth(report.month))}',
      children: [
        _AmountRow(
          row: ReportRow(
            label: monthLabel(previousMonth(report.month)),
            amount: report.previousMonthTotal,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Expanded(child: Text('Change')),
              const SizedBox(width: 12),
              Text(
                _signedEuro(report.monthOverMonthChange),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        Text(
          fraction == null
              ? 'Nothing was spent that month, so there is no percentage.'
              : '${_signedPercent(fraction)} on the month before',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// [formatEuro] already writes the minus. Only a rise needs its sign adding.
String _signedEuro(double amount) =>
    amount > 0 ? '+${formatEuro(amount)}' : formatEuro(amount);

/// Whole percent. A decimal place would imply a precision a grocery bill does
/// not have.
String _signedPercent(double fraction) {
  final percent = (fraction * 100).round();
  return percent > 0 ? '+$percent%' : '$percent%';
}

class _MonthTotal extends StatelessWidget {
  const _MonthTotal({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Total spent', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(formatEuro(total), style: theme.textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

class _NothingThisMonth extends StatelessWidget {
  const _NothingThisMonth();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            'Nothing recorded this month',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Record a purchase and it will show up here.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReportsFailureBody extends StatelessWidget {
  const _ReportsFailureBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FailureMessage(message: message),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.read<ReportsCubit>().retry(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
