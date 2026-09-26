import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/refusal_snack.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/logic/app_user.dart';
import '../../home/presentation/low_stock_row.dart';
import '../../home/presentation/running_low_cubit.dart';
import '../../home/presentation/running_low_state.dart';
import '../../items/presentation/item_detail_page.dart';
import '../../members/logic/household.dart';
import '../../members/presentation/household_cubit.dart';
import '../logic/entry_meta.dart';
import '../logic/shopping_entry.dart';
import '../logic/shopping_match.dart';
import 'add_entry_field.dart';
import 'shopping_entry_row.dart';
import 'shopping_list_cubit.dart';
import 'shopping_list_state.dart';

/// The shared list, live across every phone in the household. Nothing adds
/// to it on its own: running low items are offered, never added.
class ShoppingListTab extends StatelessWidget {
  const ShoppingListTab({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdCubit>().state.household;
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const LargeTitleBar(title: 'Shopping list'),
          Expanded(
            child: BlocBuilder<ShoppingListCubit, ShoppingListState>(
              builder: (context, state) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      AppSpace.s4,
                      AppSpace.page,
                      AppSpace.s24,
                    ),
                    children: [
                      _SharedWith(household: household),
                      const SizedBox(height: AppSpace.s16),
                      const AddEntryField(),
                      const SizedBox(height: AppSpace.s16),
                      switch (state) {
                        ShoppingListLoading() => const AppCard(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        ShoppingListEmpty() => const AppCard(
                          padding: EdgeInsets.zero,
                          child: NoteRow(
                            icon: Symbols.group_rounded,
                            text:
                                'The list is empty. Anyone in the household '
                                'can add to it.',
                          ),
                        ),
                        ShoppingListFailure(:final failure) => LoadFailure(
                          message: failure.message,
                          onRetry: () =>
                              context.read<ShoppingListCubit>().retry(),
                        ),
                        ShoppingListLoaded(:final entries) => RowGroup(
                          children: [
                            for (final entry in entries)
                              ShoppingEntryRow(
                                key: ValueKey(entry.id),
                                entry: entry,
                                meta: entryMeta(
                                  entry,
                                  household: household,
                                  now: now,
                                ),
                              ),
                          ],
                        ),
                      },
                      const SizedBox(height: AppSpace.s16),
                      const _HowItClears(),
                      _Suggestions(
                        user: user,
                        entries: state is ShoppingListLoaded
                            ? state.entries
                            : const <ShoppingEntry>[],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everyone the list is shared with, as overlapping avatars.
class _SharedWith extends StatelessWidget {
  const _SharedWith({required this.household});

  final Household household;

  static const _shown = 5;
  static const _size = 32.0;
  static const _step = _size - 6;

  @override
  Widget build(BuildContext context) {
    final members = household.members.take(_shown).toList();
    return Row(
      children: [
        SizedBox(
          width: _size + _step * (members.length - 1),
          height: _size,
          child: Stack(
            children: [
              // Later children paint on top, so the first member is added
              // last to sit in front, as the design stacks them.
              for (final (index, member) in members.indexed.toList().reversed)
                Positioned(
                  left: _step * index,
                  child: MemberAvatar(
                    initials: household.initialsOf(member.id),
                    tone: household.toneOf(member.id),
                    size: AvatarSize.medium,
                    outlined: true,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s10),
        Expanded(
          child: Text(
            'Shared live with the household',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _HowItClears extends StatelessWidget {
  const _HowItClears();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.auto_awesome_rounded,
            size: 18,
            color: AppColors.brand,
          ),
          const SizedBox(width: AppSpace.s10),
          Expanded(
            child: Text(
              'Entries clear by themselves when a saved receipt includes '
              'them. Only the checkbox removes one by hand.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is running low and not on the list yet, each one tap from being
/// added. Offered, never added: the list only holds what someone chose.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.user, required this.entries});

  final AppUser user;
  final List<ShoppingEntry> entries;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunningLowCubit, RunningLowState>(
      builder: (context, state) {
        if (state is! RunningLowLoaded) {
          return const SizedBox.shrink();
        }
        final missing = lowNotOnList(state.items, entries);
        if (missing.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Running low, not on the list'),
              const SizedBox(height: AppSpace.s12),
              RowGroup(
                children: [
                  for (final low in missing)
                    LowStockRow(
                      key: ValueKey(low.item.id),
                      low: low,
                      now: state.now,
                      onList: false,
                      onAddToList: () => reportRefusal(
                        ScaffoldMessenger.of(context),
                        context.read<ShoppingListCubit>().addItem(low.item),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ItemDetailPage(itemId: low.item.id, user: user),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
