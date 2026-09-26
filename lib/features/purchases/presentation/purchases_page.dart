import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/notes.dart';
import '../../members/presentation/household_cubit.dart';
import '../../reports/logic/report_month.dart';
import '../../reports/presentation/reports_cubit.dart';
import '../../reports/presentation/reports_state.dart';
import '../logic/purchase_labels.dart';
import 'purchase_row.dart';

/// Every purchase of the month, grouped by day, newest first.
///
/// Reads the Spending tab's month, so moving between months here moves the
/// tab too, and coming back lands on the month last looked at.
class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Purchases'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                final cubit = context.read<ReportsCubit>();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    AppSpace.s8,
                    AppSpace.page,
                    AppSpace.s24,
                  ),
                  children: [
                    MonthSwitcher(
                      label: monthLabel(state.month),
                      onPrevious: cubit.showPreviousMonth,
                      onNext: state.canViewNext ? cubit.showNextMonth : null,
                    ),
                    const SizedBox(height: AppSpace.s16),
                    ...switch (state) {
                      ReportsLoading() => const [
                        Padding(
                          padding: EdgeInsets.all(AppSpace.s32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                      ReportsFailure(:final failure) => [
                        LoadFailure(
                          message: failure.message,
                          onRetry: cubit.retry,
                        ),
                      ],
                      ReportsLoaded(:final report) when report.isEmpty => [
                        RowGroup(
                          children: [
                            NoteRow(
                              icon: Symbols.receipt_long_rounded,
                              text:
                                  'Nothing was recorded in '
                                  '${monthLabel(report.month)}.',
                            ),
                          ],
                        ),
                      ],
                      ReportsLoaded(:final report) => [
                        for (final group in purchasesByDay(report.purchases))
                          _Day(group: group),
                      ],
                    },
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.group});

  final DayGroup group;

  @override
  Widget build(BuildContext context) {
    final household = context.select(
      (HouseholdCubit cubit) => cubit.state.household,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              dayHeading(group.day, now: DateTime.now()),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          RowGroup(
            children: [
              for (final purchase in group.purchases)
                PurchaseRow(
                  purchase: purchase,
                  payerName: household.nameOf(purchase.paidByUserId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
