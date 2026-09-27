import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/refusal_snack.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/logic/app_user.dart';
import '../../items/presentation/item_detail_page.dart';
import '../../shell/presentation/shell_cubit.dart';
import '../../shopping_list/logic/shopping_entry.dart';
import '../../shopping_list/logic/shopping_match.dart';
import '../../shopping_list/presentation/shopping_list_cubit.dart';
import '../../shopping_list/presentation/shopping_list_state.dart';
import 'low_stock_row.dart';
import 'running_low_cubit.dart';
import 'running_low_state.dart';

/// How many low items Home lists before pointing at the pantry.
const _homeLimit = 5;

/// Home's running low section. Calculated, never stored: a restock lifts the
/// item and it drops out on its own.
class RunningLowPanel extends StatelessWidget {
  const RunningLowPanel({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunningLowCubit, RunningLowState>(
      builder: (context, state) {
        final count = switch (state) {
          RunningLowLoaded(:final items) => items.length,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Running low',
              count: count,
              actionLabel: count == null ? null : 'Pantry',
              onAction: () => context.read<ShellCubit>().show(AppTab.pantry),
            ),
            const SizedBox(height: AppSpace.s12),
            switch (state) {
              RunningLowLoading() => const _Loading(),
              RunningLowNone() => const AppCard(
                padding: EdgeInsets.zero,
                child: NoteRow(
                  icon: Symbols.check_circle_rounded,
                  iconColor: AppColors.positive,
                  text: 'Nothing is running low',
                ),
              ),
              RunningLowFailure(:final failure) => _Failure(
                message: failure.message,
              ),
              RunningLowLoaded() => _LowList(state: state, user: user),
            },
          ],
        );
      },
    );
  }
}

class _LowList extends StatelessWidget {
  const _LowList({required this.state, required this.user});

  final RunningLowLoaded state;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final listState = context.watch<ShoppingListCubit>().state;
    final entries = listState is ShoppingListLoaded
        ? listState.entries
        : const <ShoppingEntry>[];
    final shown = state.items.take(_homeLimit);

    return RowGroup(
      children: [
        for (final low in shown)
          LowStockRow(
            key: ValueKey(low.item.id),
            low: low,
            now: state.now,
            onList: entryFor(low.item, entries) != null,
            onAddToList: () => reportRefusal(
              ScaffoldMessenger.of(context),
              context.read<ShoppingListCubit>().addItem(low.item),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItemDetailPage(itemId: low.item.id, user: user),
              ),
            ),
          ),
        if (state.items.length > _homeLimit)
          AppRow(
            onTap: () => context.read<ShellCubit>().show(AppTab.pantry),
            body: Text(
              '${state.items.length - _homeLimit} more in the pantry',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.brand),
            ),
            trailing: const Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              color: AppColors.iconSecondary,
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          SkeletonBox(width: 40, height: 40, radius: AppRadius.md),
          SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120),
                SizedBox(height: AppSpace.s8),
                SkeletonBox(width: 180, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => context.read<RunningLowCubit>().retry(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
