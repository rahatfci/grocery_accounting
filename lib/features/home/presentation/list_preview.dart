import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/section_header.dart';
import '../../members/presentation/household_cubit.dart';
import '../../shell/presentation/shell_cubit.dart';
import '../../shopping_list/logic/entry_meta.dart';
import '../../shopping_list/presentation/add_entry_field.dart';
import '../../shopping_list/presentation/shopping_entry_row.dart';
import '../../shopping_list/presentation/shopping_list_cubit.dart';
import '../../shopping_list/presentation/shopping_list_state.dart';

/// How many entries Home shows before pointing at the List tab.
const _previewLimit = 3;

/// The first few entries of the shared list, and a way to add to it.
class ListPreview extends StatelessWidget {
  const ListPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdCubit>().state.household;
    final now = DateTime.now();

    return BlocBuilder<ShoppingListCubit, ShoppingListState>(
      builder: (context, state) {
        final count = switch (state) {
          ShoppingListLoaded(:final entries) => entries.length,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Shopping list',
              count: count,
              actionLabel: count == null ? null : 'Open',
              onAction: () => context.read<ShellCubit>().show(AppTab.list),
            ),
            const SizedBox(height: AppSpace.s12),
            RowGroup(
              children: [
                ...switch (state) {
                  ShoppingListLoaded(:final entries) => [
                    for (final entry in entries.take(_previewLimit))
                      ShoppingEntryRow(
                        key: ValueKey(entry.id),
                        entry: entry,
                        meta: entryMeta(entry, household: household, now: now),
                      ),
                  ],
                  ShoppingListFailure(:final failure) => [
                    AppRow(
                      body: Text(
                        failure.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () =>
                            context.read<ShoppingListCubit>().retry(),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                  ShoppingListLoading() || ShoppingListEmpty() => const [],
                },
                const AddEntryField(inline: true),
                if (state is ShoppingListEmpty)
                  const NoteRow(
                    icon: Symbols.group_rounded,
                    text:
                        'The list is empty. Anyone in the household can add '
                        'to it.',
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
