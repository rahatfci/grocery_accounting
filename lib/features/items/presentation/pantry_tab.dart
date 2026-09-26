import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/notes.dart';
import '../../auth/logic/app_user.dart';
import '../logic/item.dart';
import '../logic/pantry_view.dart';
import 'item_detail_page.dart';
import 'item_form_page.dart';
import 'items_cubit.dart';
import 'items_state.dart';
import 'pantry_item_row.dart';

/// The pantry: every item, grouped by category, with where its derived stock
/// leaves it. Filters narrow it; search finds one by name.
class PantryTab extends StatefulWidget {
  const PantryTab({required this.user, super.key});

  /// Stamped on every stock event recorded from an item opened here.
  final AppUser user;

  @override
  State<PantryTab> createState() => _PantryTabState();
}

class _PantryTabState extends State<PantryTab> {
  final _query = TextEditingController();
  PantryFilter _filter = const AllItemsFilter();
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LargeTitleBar(
              title: 'Pantry',
              action: RoundIconButton(
                icon: _searching
                    ? Symbols.close_rounded
                    : Symbols.search_rounded,
                tooltip: _searching ? 'Close search' : 'Search the pantry',
                onPressed: _toggleSearch,
              ),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.s4,
                  AppSpace.page,
                  AppSpace.s8,
                ),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search the pantry',
                    prefixIcon: Icon(Symbols.search_rounded, size: 20),
                  ),
                ),
              ),
            Expanded(
              child: BlocBuilder<ItemsCubit, ItemsState>(
                builder: (context, state) => switch (state) {
                  ItemsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  ItemsEmpty() => const _PantryEmpty(),
                  ItemsFailure(:final failure) => LoadFailure(
                    message: failure.message,
                    onRetry: () => context.read<ItemsCubit>().retry(),
                  ),
                  ItemsLoaded(:final items, :final now) => _PantryList(
                    items: items,
                    now: now,
                    user: widget.user,
                    filter: _filter,
                    query: _searching ? _query.text : '',
                    showFilters: !_searching,
                    onFilter: (filter) => setState(() => _filter = filter),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openItemForm(context),
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Add item'),
      ),
    );
  }
}

class _PantryList extends StatelessWidget {
  const _PantryList({
    required this.items,
    required this.now,
    required this.user,
    required this.filter,
    required this.query,
    required this.showFilters,
    required this.onFilter,
  });

  final List<Item> items;
  final DateTime now;
  final AppUser user;
  final PantryFilter filter;
  final String query;
  final bool showFilters;
  final ValueChanged<PantryFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final options = pantryFilters(items, now: now);
    // A category filter can outlive the last item in it.
    final active = options.any((option) => option.filter == filter)
        ? filter
        : const AllItemsFilter();
    final groups = pantryGroups(
      items,
      now: now,
      filter: showFilters ? active : const AllItemsFilter(),
      query: query,
    );

    return ListView(
      // Clears the add button at the end of a long pantry.
      padding: const EdgeInsets.only(top: AppSpace.s4, bottom: 96),
      children: [
        if (showFilters) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (context, index) {
                final option = options[index];
                return ChoicePill(
                  label: option.label,
                  selected: option.filter == active,
                  showCheck: false,
                  onTap: () => onFilter(option.filter),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.s20),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          child: groups.isEmpty
              ? AppCard(
                  padding: EdgeInsets.zero,
                  child: NoteRow(
                    icon: Symbols.inventory_2_rounded,
                    text: query.trim().isNotEmpty
                        ? 'Nothing in the pantry is called that'
                        : active is RunningLowFilter
                        ? 'Nothing is running low'
                        : 'Nothing here yet',
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => _Groups(
                    groups: groups,
                    now: now,
                    user: user,
                    columns: constraints.maxWidth >= wideLayoutWidth ? 2 : 1,
                    width: constraints.maxWidth,
                  ),
                ),
        ),
      ],
    );
  }
}

/// The category groups, one column on a phone and two on a wide window.
class _Groups extends StatelessWidget {
  const _Groups({
    required this.groups,
    required this.now,
    required this.user,
    required this.columns,
    required this.width,
  });

  final List<PantryGroup> groups;
  final DateTime now;
  final AppUser user;
  final int columns;
  final double width;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpace.s24;
    final columnWidth = columns == 1 ? width : (width - gap) / 2;
    return Wrap(
      spacing: gap,
      runSpacing: AppSpace.s20,
      children: [
        for (final group in groups)
          SizedBox(
            width: columnWidth,
            child: _Group(group: group, now: now, user: user),
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group, required this.now, required this.user});

  final PantryGroup group;
  final DateTime now;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            group.label.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        RowGroup(
          children: [
            for (final item in group.items)
              PantryItemRow(
                key: ValueKey(item.id),
                item: item,
                now: now,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ItemDetailPage(itemId: item.id, user: user),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PantryEmpty extends StatelessWidget {
  const _PantryEmpty();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(
                icon: Symbols.inventory_2_rounded,
                size: 56,
                iconSize: 28,
                radius: AppRadius.lg,
                background: AppColors.brandSubtle,
                color: AppColors.brand,
              ),
              const SizedBox(height: AppSpace.s16),
              Text(
                'Nothing in the pantry yet',
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Every receipt you review adds its items. Add the staples that '
                'matter when they run out, and the rest will follow.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              AppButton(
                label: 'Add item',
                icon: Symbols.add_rounded,
                variant: AppButtonVariant.tonal,
                size: AppButtonSize.medium,
                onPressed: () => openItemForm(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
