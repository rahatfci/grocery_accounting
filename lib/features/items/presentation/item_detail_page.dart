import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/level_bar.dart';
import '../../../core/widgets/notes.dart';
import '../../../core/widgets/refusal_snack.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/logic/app_user.dart';
import '../../members/presentation/household_cubit.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../reminders/logic/run_out_reminder.dart';
import '../../shopping_list/logic/shopping_entry.dart';
import '../../shopping_list/logic/shopping_match.dart';
import '../../shopping_list/presentation/shopping_list_cubit.dart';
import '../../shopping_list/presentation/shopping_list_state.dart';
import '../data/item_repository.dart';
import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/stock.dart';
import '../logic/stock_event.dart';
import '../logic/stock_labels.dart';
import '../logic/stock_status.dart';
import 'category_icons.dart';
import 'history_row.dart';
import 'item_form_page.dart';
import 'item_history_cubit.dart';
import 'item_history_page.dart';
import 'item_history_state.dart';
import 'items_cubit.dart';
import 'items_state.dart';
import 'stock_event_sheet.dart';
import 'stock_tone.dart';

/// How many history rows the detail screen shows before "See all".
const _historyPreview = 4;

/// One item's pantry: its derived stock and where that leaves it, the ways to
/// correct it, and the history that explains the number.
///
/// Reads the item by id from the pantry's [ItemsCubit], so an edit, a stock
/// event or a purchase on another phone all show up here as they land.
class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({required this.itemId, required this.user, super.key});

  final String itemId;

  /// Stamped on every stock event recorded from this screen.
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ItemHistoryCubit(
        context.read<ItemRepository>(),
        context.read<PurchaseRepository>(),
        itemId: itemId,
      ),
      child: BlocBuilder<ItemsCubit, ItemsState>(
        builder: (context, state) {
          final item = switch (state) {
            ItemsLoaded(:final items) =>
              items.where((candidate) => candidate.id == itemId).firstOrNull,
            _ => null,
          };

          return Scaffold(
            appBar: AppTopBar(
              title: item?.name ?? 'Item',
              actions: [
                if (item != null)
                  IconButton(
                    icon: const Icon(Symbols.edit_rounded),
                    tooltip: 'Edit item',
                    onPressed: () => openItemForm(context, item: item),
                  ),
              ],
            ),
            body: switch (state) {
              ItemsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              ItemsFailure(:final failure) => LoadFailure(
                message: failure.message,
                onRetry: () => context.read<ItemsCubit>().retry(),
              ),
              // Deliberately not a pop: a pop from here removes whichever
              // route is on top, which mid-delete is the edit form.
              ItemsLoaded(:final now) when item != null => _Detail(
                item: item,
                now: now,
                user: user,
              ),
              ItemsLoaded() || ItemsEmpty() => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.s24),
                  child: Text(
                    'This item is no longer in the pantry',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.item, required this.now, required this.user});

  final Item item;
  final DateTime now;
  final AppUser user;

  void _openSheet(BuildContext context, StockEventType type) =>
      openStockEventSheet(context, item: item, type: type, user: user);

  @override
  Widget build(BuildContext context) {
    return ListView(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StockCard(item: item, now: now),
                const SizedBox(height: AppSpace.s16),
                _Stats(item: item, now: now),
                const SizedBox(height: AppSpace.s16),
                AppButton(
                  label: 'Log use',
                  icon: Symbols.restaurant_rounded,
                  expand: true,
                  onPressed: () => _openSheet(context, StockEventType.consumed),
                ),
                const SizedBox(height: AppSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Adjust',
                        icon: Symbols.tune_rounded,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        onPressed: () =>
                            _openSheet(context, StockEventType.adjustment),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: AppButton(
                        label: 'Recount',
                        icon: Symbols.checklist_rounded,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        onPressed: () =>
                            _openSheet(context, StockEventType.recount),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                _AddToListButton(item: item),
                const SizedBox(height: AppSpace.s24),
                const _History(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item, required this.now});

  final Item item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stock = currentStock(item, now: now);
    final status = stockStatusOf(item, now: now);
    final tone = toneFor(status);
    final urgent = status == StockStatus.low || status == StockStatus.out;
    final tag = switch (status) {
      StockStatus.out => 'Out',
      StockStatus.low => 'Running low',
      StockStatus.soon => 'Runs out soon',
      StockStatus.healthy => 'In stock',
      StockStatus.untracked => null,
    };

    return AppCard(
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: categoryIcon(item.category),
                size: 44,
                iconSize: 24,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabel(item.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      kindLabel(item),
                      style: text.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (tag != null) StatusTag(label: tag, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Current stock',
            style: text.labelMedium?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            formatStock(stock, item.unit),
            style: text.displaySmall?.copyWith(
              color: urgent ? AppColors.negative : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          LevelBar(
            value: stockLevel(stock, item.lowThreshold),
            color: tone.data,
            height: 8,
          ),
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.lowThreshold > 0
                      ? 'Low below ${formatStock(item.lowThreshold, item.unit)}'
                      : 'No low threshold',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Flexible(
                child: Text(
                  runOutCaption(item, status, now: now),
                  textAlign: TextAlign.end,
                  style: text.labelMedium?.copyWith(
                    color: switch (status) {
                      StockStatus.low || StockStatus.out => AppColors.negative,
                      StockStatus.soon => AppColors.warning,
                      _ => AppColors.textTertiary,
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.item, required this.now});

  final Item item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final reminder = reminderFor(item, now: now);
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Daily use',
            value: item.dailyUsage > 0
                ? formatStock(item.dailyUsage, item.unit)
                : 'None',
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: _Stat(
            label: 'Low below',
            value: item.lowThreshold > 0
                ? formatStock(item.lowThreshold, item.unit)
                : 'None',
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: _Stat(
            label: 'Reminder',
            // The web has no local notifications to schedule.
            value: kIsWeb
                ? 'Phone only'
                : reminder == null
                ? 'None'
                : formatDayMonth(reminder.remindAt),
          ),
        ),
      ],
    );
  }
}

/// The Figma Stat: a caption over a value, on its own card.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpace.s2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: text.titleMedium),
          ),
        ],
      ),
    );
  }
}

/// Puts the item on the shared list, linked to it. Only one entry per item:
/// once it is on the list the button says so instead.
class _AddToListButton extends StatelessWidget {
  const _AddToListButton({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShoppingListCubit>().state;
    final entries = state is ShoppingListLoaded
        ? state.entries
        : const <ShoppingEntry>[];
    final onList = entryFor(item, entries) != null;

    return AppButton(
      label: onList ? 'On the shopping list' : 'Add to shopping list',
      icon: onList ? Symbols.check_rounded : Symbols.add_shopping_cart_rounded,
      variant: AppButtonVariant.tonal,
      expand: true,
      onPressed: onList
          ? null
          : () => reportRefusal(
              ScaffoldMessenger.of(context),
              context.read<ShoppingListCubit>().addItem(item),
            ),
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdCubit>().state.household;
    return BlocBuilder<ItemHistoryCubit, ItemHistoryState>(
      builder: (context, state) {
        final entries = state is ItemHistoryLoaded ? state.entries : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'History',
              actionLabel: (entries?.length ?? 0) > _historyPreview
                  ? 'See all'
                  : null,
              onAction: () {
                final cubit = context.read<ItemHistoryCubit>();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: const ItemHistoryPage(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpace.s12),
            switch (state) {
              ItemHistoryLoading() => const AppCard(
                padding: EdgeInsets.all(AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 180),
                    SizedBox(height: AppSpace.s8),
                    SkeletonBox(width: 120, height: 10),
                  ],
                ),
              ),
              ItemHistoryFailure(:final failure) => AppCard(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Row(
                  children: [
                    Expanded(child: Text(failure.message)),
                    TextButton(
                      onPressed: () => context.read<ItemHistoryCubit>().retry(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              ItemHistoryLoaded(:final entries) when entries.isEmpty =>
                const AppCard(
                  padding: EdgeInsets.zero,
                  child: NoteRow(
                    icon: Symbols.history_rounded,
                    text: 'Nothing has moved this stock yet',
                  ),
                ),
              ItemHistoryLoaded(:final entries) => RowGroup(
                children: [
                  for (final entry in entries.take(_historyPreview))
                    HistoryRow(entry: entry, household: household),
                ],
              ),
            },
          ],
        );
      },
    );
  }
}
