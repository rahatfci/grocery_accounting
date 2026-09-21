import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_category.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';

Item _item(String category) => Item(
  id: category,
  name: 'x',
  unit: ItemUnit.kg,
  category: category,
  avgPieceWeight: null,
  dailyUsage: 0,
  lowThreshold: 0,
  stockAtBaseline: 0,
  baselineDate: DateTime(2026),
);

void main() {
  group('categoryLabel', () {
    test('resolves a built-in key to its label', () {
      expect(categoryLabel('meat_fish'), 'Meat & Fish');
      expect(categoryLabel('produce'), 'Produce');
    });

    test('shows a member-added category exactly as it was typed', () {
      expect(categoryLabel('Baby food'), 'Baby food');
      expect(categoryLabel('Pet'), 'Pet');
    });
  });

  group('normalizeCategory', () {
    test('trims and collapses whitespace so near-duplicates cannot form', () {
      expect(normalizeCategory('  Baby   food '), 'Baby food');
      expect(normalizeCategory('Pet'), 'Pet');
      expect(normalizeCategory('   '), '');
    });
  });

  group('availableCategories', () {
    test('offers every built-in even when nothing is in use', () {
      final categories = availableCategories([]);

      expect(categories.length, BuiltInCategory.values.length);
      expect(categories.first, 'produce');
      expect(categories, contains('other'));
    });

    test('adds member-added categories after the built-ins', () {
      final categories = availableCategories([_item('produce'), _item('Pet')]);

      expect(categories.last, 'Pet');
      expect(categories.length, BuiltInCategory.values.length + 1);
    });

    test('never duplicates a built-in that is in use', () {
      final categories = availableCategories([
        _item('produce'),
        _item('produce'),
      ]);

      expect(categories.where((c) => c == 'produce').length, 1);
    });

    test('folds case-insensitive near-duplicates into one entry', () {
      final categories = availableCategories([
        _item('Pet'),
        _item('pet'),
        _item('PET'),
      ]);

      final custom = categories.skip(BuiltInCategory.values.length).toList();
      expect(custom, ['Pet'], reason: 'the first spelling seen wins');
    });

    test('ignores an item whose category is only whitespace', () {
      final categories = availableCategories([_item('   ')]);

      expect(categories.length, BuiltInCategory.values.length);
    });
  });
}
