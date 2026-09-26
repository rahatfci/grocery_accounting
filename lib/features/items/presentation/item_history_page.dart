import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../members/presentation/household_cubit.dart';
import 'history_row.dart';
import 'item_history_cubit.dart';
import 'item_history_state.dart';

/// Every entry of an item's history, on the detail screen's own cubit.
class ItemHistoryPage extends StatelessWidget {
  const ItemHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdCubit>().state.household;
    return Scaffold(
      appBar: const AppTopBar(title: 'History'),
      body: BlocBuilder<ItemHistoryCubit, ItemHistoryState>(
        builder: (context, state) => switch (state) {
          ItemHistoryLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          ItemHistoryFailure(:final failure) => LoadFailure(
            message: failure.message,
            onRetry: () => context.read<ItemHistoryCubit>().retry(),
          ),
          ItemHistoryLoaded(:final entries) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s8,
              AppSpace.page,
              AppSpace.s24,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: RowGroup(
                    children: [
                      for (final entry in entries)
                        HistoryRow(entry: entry, household: household),
                    ],
                  ),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
