import 'item.dart';

/// The categories every household starts with.
///
/// The stored field is a plain string, not this enum: a member can add their
/// own category, and it is stored as the text they typed.
enum BuiltInCategory {
  produce('produce', 'Produce'),
  dairy('dairy', 'Dairy & Eggs'),
  meatFish('meat_fish', 'Meat & Fish'),
  bakery('bakery', 'Bakery'),
  pantry('pantry', 'Pantry & Dry Goods'),
  frozen('frozen', 'Frozen'),
  drinks('drinks', 'Drinks'),
  household('household', 'Household & Cleaning'),
  other('other', 'Other');

  const BuiltInCategory(this.key, this.label);

  final String key;
  final String label;

  static BuiltInCategory? fromKey(String key) {
    for (final category in values) {
      if (category.key == key) {
        return category;
      }
    }
    return null;
  }
}

/// The label for a stored category: a built-in's label, or the member's own
/// text unchanged.
String categoryLabel(String stored) =>
    BuiltInCategory.fromKey(stored)?.label ?? stored;

/// Trims and collapses internal whitespace so `"  Baby   food "` and
/// `"Baby food"` cannot become two categories.
String normalizeCategory(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Every category offered by the picker: the built-ins in declaration order,
/// then each distinct member-added category currently in use, sorted.
///
/// A member-added category only exists while an item carries it, because the
/// list is derived from the items rather than stored separately.
List<String> availableCategories(Iterable<Item> items) {
  final builtInKeys = {for (final c in BuiltInCategory.values) c.key};
  final seen = <String, String>{};

  for (final item in items) {
    final category = normalizeCategory(item.category);
    if (category.isEmpty || builtInKeys.contains(category)) {
      continue;
    }
    seen.putIfAbsent(category.toLowerCase(), () => category);
  }

  final custom = seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return [...builtInKeys, ...custom];
}
