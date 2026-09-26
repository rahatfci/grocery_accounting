import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/bars.dart';
import '../../items/data/item_repository.dart';
import '../../members/data/member_repository.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../purchases/logic/money.dart';
import '../../reports/data/csv_sharer.dart';
import '../../reports/logic/report_month.dart';
import '../../reports/presentation/reports_cubit.dart';
import '../../reports/presentation/reports_state.dart';

/// Picks a month and shares it as CSV, on a report of its own so the month
/// chosen here leaves Spending where it was.
Future<void> showExportMonthSheet(BuildContext context) => showAppSheet<void>(
  context,
  builder: (_) => BlocProvider(
    create: (context) => ReportsCubit(
      purchases: context.read<PurchaseRepository>(),
      items: context.read<ItemRepository>(),
      members: context.read<MemberRepository>(),
      sharer: context.read<CsvSharer>(),
    ),
    child: const ExportMonthSheet(),
  ),
);

class ExportMonthSheet extends StatefulWidget {
  const ExportMonthSheet({super.key});

  @override
  State<ExportMonthSheet> createState() => _ExportMonthSheetState();
}

class _ExportMonthSheetState extends State<ExportMonthSheet> {
  bool _exporting = false;

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ReportsCubit>();
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
    final text = Theme.of(context).textTheme;
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        final cubit = context.read<ReportsCubit>();
        final summary = switch (state) {
          ReportsLoading() => 'Loading the month',
          ReportsFailure(:final failure) => failure.message,
          ReportsLoaded(:final report) when report.isEmpty =>
            'Nothing was recorded this month',
          ReportsLoaded(:final report) =>
            '${report.purchaseCount} '
                '${report.purchaseCount == 1 ? 'purchase' : 'purchases'} · '
                '${formatEuro(report.monthTotal)}',
        };
        final canExport = state is ReportsLoaded && !state.report.isEmpty;

        return SheetFrame(
          children: [
            SheetTitle(
              title: 'Export a month',
              subtitle: Text(
                'Every purchase line as a CSV that Excel opens as it is.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            MonthSwitcher(
              label: monthLabel(state.month),
              onPrevious: cubit.showPreviousMonth,
              onNext: state.canViewNext ? cubit.showNextMonth : null,
            ),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            AppButton(
              label: 'Export CSV',
              icon: Symbols.ios_share_rounded,
              expand: true,
              busy: _exporting,
              onPressed: canExport ? _export : null,
            ),
          ],
        );
      },
    );
  }
}
