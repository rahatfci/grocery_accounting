import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/running_low.dart';
import 'package:grocery_accounting/features/shopping_list/logic/shopping_entry.dart';
import 'package:grocery_accounting/features/shopping_list/logic/shopping_match.dart';

import '../../items/fake_item_repository.dart';

ShoppingEntry _entry({
  required String id,
  String text = 'Rice',
  String? itemId,
}) => ShoppingEntry(
  id: id,
  text: text,
  itemId: itemId,
  addedByUserId: 'abc123',
  addedAt: DateTime(2026, 9, 20),
);

void main() {
  group('normalizeEntryText', () {
    test('ignores case, surrounding space and repeated space', () {
      expect(normalizeEntryText('  Olive   OIL \t'), 'olive oil');
    });

    test('leaves an already normal name alone', () {
      expect(normalizeEntryText('milk'), 'milk');
    });
  });

  group('validateEntryText', () {
    test('refuses nothing, empty and whitespace-only text', () {
      expect(validateEntryText(null), 'Enter something to buy');
      expect(validateEntryText(''), 'Enter something to buy');
      expect(validateEntryText('   '), 'Enter something to buy');
    });

    test('accepts any text with something in it', () {
      expect(validateEntryText(' bread '), isNull);
    });
  });

  group('linkedItemId', () {
    final items = [
      testItem(id: 'rice', name: 'Rice'),
      testItem(id: 'milk', name: 'Milk'),
    ];

    test('links the one item the text names', () {
      expect(linkedItemId('  MILK ', items), 'milk');
    });

    test('links nothing when no item matches', () {
      expect(linkedItemId('Bread', items), isNull);
    });

    test('links nothing when several items share the name', () {
      final duplicated = [...items, testItem(id: 'milk2', name: 'milk')];

      expect(linkedItemId('Milk', duplicated), isNull);
    });

    test('links nothing for empty text', () {
      expect(linkedItemId('  ', items), isNull);
    });

    test('never links to an item that has not been written', () {
      expect(linkedItemId('Bread', [newTestItem(name: 'Bread')]), isNull);
    });
  });

  group('entriesClearedBy', () {
    test('clears an entry linked to a purchased item', () {
      final entries = [_entry(id: 'e1', text: 'basmati', itemId: 'rice')];

      expect(entriesClearedBy(entries, [testItem(id: 'rice')]), {'e1'});
    });

    test('clears an unlinked entry that names a purchased item', () {
      final entries = [_entry(id: 'e1', text: ' rice ')];

      expect(entriesClearedBy(entries, [testItem(id: 'rice')]), {'e1'});
    });

    test('clears by name for an item created on the purchase', () {
      final entries = [_entry(id: 'e1', text: 'Bread')];

      expect(entriesClearedBy(entries, [newTestItem(name: 'bread')]), {'e1'});
    });

    test('keeps entries the purchase does not cover', () {
      final entries = [
        _entry(id: 'e1', text: 'Rice', itemId: 'rice'),
        _entry(id: 'e2', text: 'Milk', itemId: 'milk'),
        _entry(id: 'e3', text: 'Bread'),
      ];

      expect(entriesClearedBy(entries, [testItem(id: 'rice')]), {'e1'});
    });

    test('an item created on the purchase never matches an unlinked id', () {
      final entries = [_entry(id: 'e1', text: 'Something else')];

      expect(entriesClearedBy(entries, [newTestItem(name: 'Bread')]), isEmpty);
    });

    test('clears nothing for a purchase with no lines', () {
      expect(entriesClearedBy([_entry(id: 'e1')], const []), isEmpty);
    });

    test('skips an entry that has not been written', () {
      expect(entriesClearedBy([_entry(id: '')], [testItem()]), isEmpty);
    });
  });

  group('entryFor', () {
    test('finds the entry linked to the item', () {
      final rice = testItem(id: 'rice', name: 'Rice');

      expect(
        entryFor(rice, [_entry(id: 'e1', text: 'riso', itemId: 'rice')])?.id,
        'e1',
      );
    });

    test('finds an unlinked entry that names the item', () {
      final rice = testItem(id: 'rice', name: 'Rice');

      expect(entryFor(rice, [_entry(id: 'e2', text: '  RICE ')])?.id, 'e2');
    });

    test('is null when the item is not on the list', () {
      final rice = testItem(id: 'rice', name: 'Rice');

      expect(entryFor(rice, [_entry(id: 'e3', text: 'Milk')]), isNull);
    });
  });

  test('lowNotOnList drops what is already on the list, keeping order', () {
    final rice = LowStockItem(
      item: testItem(id: 'rice', name: 'Rice'),
      stock: 0,
    );
    final oil = LowStockItem(
      item: testItem(id: 'oil', name: 'Olive oil'),
      stock: 0.2,
    );
    final eggs = LowStockItem(
      item: testItem(id: 'eggs', name: 'Eggs'),
      stock: 1,
    );

    expect(
      lowNotOnList([rice, oil, eggs], [_entry(id: 'e1', text: 'Olive oil')]),
      [rice, eggs],
    );
  });
}
