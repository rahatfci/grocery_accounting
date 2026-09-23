import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/logic/app_user.dart';
import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/stock.dart';
import '../logic/stock_event.dart';
import 'item_form_page.dart';
import 'items_cubit.dart';
import 'items_state.dart';
import 'stock_event_sheet.dart';

/// One item's pantry: its current stock, and the ways to correct it.
///
/// Reads the item by id from the catalogue's [ItemsCubit], so an edit, a stock
/// event or a purchase on another phone all show up here as they land.
class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({required this.itemId, required this.user, super.key});

  final String itemId;

  /// Stamped on every stock event recorded from this screen.
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ItemsCubit, ItemsState>(
      builder: (context, state) {
        final item = switch (state) {
          ItemsLoaded(:final items) =>
            items.where((candidate) => candidate.id == itemId).firstOrNull,
          _ => null,
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(item?.name ?? 'Item'),
            actions: [
              if (item != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit item',
                  onPressed: () => openItemForm(context, item: item),
                ),
            ],
          ),
          body: SafeArea(
            child: switch (state) {
              ItemsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              ItemsFailure(:final failure) => _DetailMessage(
                message: failure.message,
                onRetry: () => context.read<ItemsCubit>().retry(),
              ),
              // Deliberately not a pop: a pop from here removes whichever
              // route is on top, which mid-delete is the edit form.
              ItemsLoaded(:final now) when item != null => _ItemStock(
                item: item,
                now: now,
                onEvent: (type) => openStockEventSheet(
                  context,
                  item: item,
                  type: type,
                  user: user,
                ),
              ),
              ItemsLoaded() || ItemsEmpty() => const _DetailMessage(
                message: 'This item is no longer in the catalogue',
              ),
            },
          ),
        );
      },
    );
  }
}

class _ItemStock extends StatelessWidget {
  const _ItemStock({
    required this.item,
    required this.now,
    required this.onEvent,
  });

  final Item item;
  final DateTime now;
  final ValueChanged<StockEventType> onEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = item.unit;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Current stock', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                formatStock(currentStock(item, now: now), unit),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              _Fact(
                label: 'Daily usage',
                value: item.dailyUsage > 0
                    ? '${formatStock(item.dailyUsage, unit)} a day'
                    : 'Not a staple',
              ),
              _Fact(
                label: 'Low threshold',
                value: formatStock(item.lowThreshold, unit),
              ),
              _Fact(label: 'Category', value: categoryLabel(item.category)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => onEvent(StockEventType.consumed),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Log use'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onEvent(StockEventType.adjustment),
                icon: const Icon(Icons.tune),
                label: const Text('Adjust'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onEvent(StockEventType.recount),
                icon: const Icon(Icons.checklist),
                label: const Text('Recount'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (retry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: retry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
