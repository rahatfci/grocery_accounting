import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/layout.dart';
import '../../auth/logic/app_user.dart';
import '../../purchases/data/purchase_repository.dart';
import '../data/item_repository.dart';
import '../logic/item.dart';
import '../logic/item_category.dart';
import '../logic/running_low.dart';
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
    return _RefreshOnResume(
      child: Scaffold(
        appBar: AppBar(title: const Text('Catalogue')),
        body: SafeArea(
          child: BlocBuilder<ItemsCubit, ItemsState>(
            builder: (context, state) => switch (state) {
              ItemsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
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
      ),
    );
  }
}

/// Re-derives stock when the app comes back to the foreground. The detail
/// screen reads the same cubit and this view stays mounted beneath it, so one
/// listener covers both.
class _RefreshOnResume extends StatefulWidget {
  const _RefreshOnResume({required this.child});

  final Widget child;

  @override
  State<_RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<_RefreshOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => context.read<ItemsCubit>().refresh(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= wideLayoutWidth
          ? _ItemTable(items: items, now: now, user: user)
          : _NarrowItemList(items: items, now: now, user: user),
    );
  }
}

class _NarrowItemList extends StatelessWidget {
  const _NarrowItemList({
    required this.items,
    required this.now,
    required this.user,
  });

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

/// The catalogue as a table, for a screen wide enough to compare items at a
/// glance. Same order and same tap as the list.
class _ItemTable extends StatelessWidget {
  const _ItemTable({
    required this.items,
    required this.now,
    required this.user,
  });

  final List<Item> items;
  final DateTime now;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            const _TableHeader(),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                // Clears the floating action button at the end of a full list.
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _TableRow(
                  key: ValueKey(items[index].id),
                  item: items[index],
                  now: now,
                  user: user,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _TableColumns(
          name: Text('Name', style: style),
          category: Text('Category', style: style),
          stock: Text('Stock', style: style, textAlign: TextAlign.end),
          dailyUse: Text('Daily use', style: style, textAlign: TextAlign.end),
          lowBelow: Text('Low below', style: style, textAlign: TextAlign.end),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.item,
    required this.now,
    required this.user,
    super.key,
  });

  final Item item;
  final DateTime now;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final stock = currentStock(item, now: now);
    final low = isBelowThreshold(stock, item.lowThreshold);
    final error = Theme.of(context).colorScheme.error;

    return InkWell(
      onTap: () => _openDetail(context, item, user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: _TableColumns(
          name: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          category: Text(
            categoryLabel(item.category),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          stock: Text(
            formatStock(stock, item.unit),
            textAlign: TextAlign.end,
            style: low ? TextStyle(color: error) : null,
          ),
          dailyUse: Text(
            item.dailyUsage > 0
                ? '${formatStock(item.dailyUsage, item.unit)}/day'
                : '-',
            textAlign: TextAlign.end,
          ),
          lowBelow: Text(
            formatStock(item.lowThreshold, item.unit),
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  }
}

/// One set of column widths, shared by the header and every row so they line
/// up.
class _TableColumns extends StatelessWidget {
  const _TableColumns({
    required this.name,
    required this.category,
    required this.stock,
    required this.dailyUse,
    required this.lowBelow,
  });

  final Widget name;
  final Widget category;
  final Widget stock;
  final Widget dailyUse;
  final Widget lowBelow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: name),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: category),
        const SizedBox(width: 16),
        Expanded(child: stock),
        const SizedBox(width: 16),
        Expanded(child: dailyUse),
        const SizedBox(width: 16),
        Expanded(child: lowBelow),
      ],
    );
  }
}
