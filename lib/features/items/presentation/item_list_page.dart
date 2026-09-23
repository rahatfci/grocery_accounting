import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/logic/app_user.dart';
import '../../purchases/data/purchase_repository.dart';
import '../data/item_repository.dart';
import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/stock.dart';
import 'item_detail_page.dart';
import 'item_form_page.dart';
import 'items_cubit.dart';
import 'items_state.dart';

/// The catalogue, owning the cubit for as long as the screen is on the stack.
class ItemListPage extends StatelessWidget {
  const ItemListPage({required this.user, super.key});

  /// Stamped on every stock event recorded from the catalogue.
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ItemsCubit(
        context.read<ItemRepository>(),
        context.read<PurchaseRepository>(),
      ),
      child: ItemListView(user: user),
    );
  }
}

/// The catalogue without its cubit, so a test can supply one.
@visibleForTesting
class ItemListView extends StatelessWidget {
  const ItemListView({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue')),
      body: SafeArea(
        child: BlocBuilder<ItemsCubit, ItemsState>(
          builder: (context, state) => switch (state) {
            ItemsLoading() => const Center(child: CircularProgressIndicator()),
            ItemsEmpty() => const _CatalogueEmpty(),
            ItemsFailure(:final failure) => _CatalogueFailure(
              message: failure.message,
            ),
            ItemsLoaded(:final items, :final now) => _ItemList(
              items: items,
              now: now,
              user: user,
            ),
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openItemForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }
}

/// Opens an item's detail screen, on the catalogue's own cubit so it follows
/// the same stream rather than opening a second one.
void _openDetail(BuildContext context, Item item, AppUser user) {
  final cubit = context.read<ItemsCubit>();

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ItemDetailPage(itemId: item.id, user: user),
      ),
    ),
  );
}

class _CatalogueEmpty extends StatelessWidget {
  const _CatalogueEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No items yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add the things the household buys and they will show up here.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => openItemForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogueFailure extends StatelessWidget {
  const _CatalogueFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.read<ItemsCubit>().retry(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.now, required this.user});

  final List<Item> items;
  final DateTime now;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // Phone stays one column; a wide window centres the list instead of
        // stretching each row across the screen.
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView.separated(
          // Clears the floating action button at the end of a full list.
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _ItemRow(item: items[index], now: now, user: user),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.now, required this.user});

  final Item item;
  final DateTime now;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _openDetail(context, item, user),
      title: Text(
        item.name,
        // A long name truncates rather than overflowing the row.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(categoryLabel(item.category)),
      trailing: Text(formatStock(currentStock(item, now: now), item.unit)),
    );
  }
}
