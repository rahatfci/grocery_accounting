import 'package:equatable/equatable.dart';

import 'item.dart';
import 'item_category.dart';
import 'running_low.dart';
import 'stock.dart';

/// What the pantry is narrowed to.
sealed class PantryFilter extends Equatable {
  const PantryFilter();

  @override
  List<Object?> get props => const [];
}

final class AllItemsFilter extends PantryFilter {
  const AllItemsFilter();
}

/// The same rule as Home's running low: under the threshold, out included.
final class RunningLowFilter extends PantryFilter {
  const RunningLowFilter();
}

/// Items with a daily usage.
final class StaplesFilter extends PantryFilter {
  const StaplesFilter();
}

final class CategoryFilter extends PantryFilter {
  const CategoryFilter(this.category);

  /// A built-in key or a member's own category, normalized.
  final String category;

  @override
  List<Object?> get props => [category];
}

/// One chip of the pantry's filter row.
final class PantryFilterOption extends Equatable {
  const PantryFilterOption({required this.filter, required this.label});

  final PantryFilter filter;
  final String label;

  @override
  List<Object?> get props => [filter, label];
}

/// One category's items, as the pantry groups them.
final class PantryGroup extends Equatable {
  const PantryGroup({
    required this.category,
    required this.label,
    required this.items,
  });

  final String category;
  final String label;
  final List<Item> items;

  @override
  List<Object?> get props => [category, label, items];
}

bool _matches(Item item, PantryFilter filter, DateTime now) => switch (filter) {
  AllItemsFilter() => true,
  RunningLowFilter() => isBelowThreshold(
    currentStock(item, now: now),
    item.lowThreshold,
  ),
  StaplesFilter() => item.dailyUsage > 0,
  CategoryFilter(:final category) => _groupOf(item) == category,
};

/// The category [item] is grouped under. One with no category counts as
/// `other`.
String _groupOf(Item item) => switch (normalizeCategory(item.category)) {
  '' => BuiltInCategory.other.key,
  final category => category,
};

/// The filter row: all, running low and staples with their counts, then
/// every category in use, built-ins first in their usual order.
List<PantryFilterOption> pantryFilters(
  List<Item> items, {
  required DateTime now,
}) {
  int count(PantryFilter filter) =>
      items.where((item) => _matches(item, filter, now)).length;

  return [
    PantryFilterOption(
      filter: const AllItemsFilter(),
      label: 'All · ${items.length}',
    ),
    PantryFilterOption(
      filter: const RunningLowFilter(),
      label: 'Running low · ${count(const RunningLowFilter())}',
    ),
    PantryFilterOption(
      filter: const StaplesFilter(),
      label: 'Staples · ${count(const StaplesFilter())}',
    ),
    for (final category in _categoriesInUse(items))
      PantryFilterOption(
        filter: CategoryFilter(category),
        label: categoryLabel(category),
      ),
  ];
}

/// The items [filter] and [query] leave, grouped by category and sorted by
/// name inside each group. [query] matches anywhere in the name, ignoring
/// case.
List<PantryGroup> pantryGroups(
  List<Item> items, {
  required DateTime now,
  PantryFilter filter = const AllItemsFilter(),
  String query = '',
}) {
  final wanted = query.trim().toLowerCase();
  final shown = [
    for (final item in items)
      if (_matches(item, filter, now) &&
          (wanted.isEmpty || item.name.toLowerCase().contains(wanted)))
        item,
  ];
  return [
    for (final category in _categoriesInUse(shown))
      PantryGroup(
        category: category,
        label: categoryLabel(category),
        items: [
          for (final item in shown)
            if (_groupOf(item) == category) item,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      ),
  ];
}

/// Every category [items] use, built-ins first in declaration order, then a
/// member's own alphabetically.
List<String> _categoriesInUse(List<Item> items) {
  final used = {for (final item in items) _groupOf(item)};
  final builtIn = [
    for (final category in BuiltInCategory.values)
      if (used.remove(category.key)) category.key,
  ];
  final own = used.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [...builtIn, ...own];
}
