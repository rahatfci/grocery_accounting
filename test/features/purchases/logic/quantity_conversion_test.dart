import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/quantity_conversion.dart';

import '../../items/fake_item_repository.dart';

void main() {
  group('convertToItemUnit', () {
    test('passes a quantity already in the item unit straight through', () {
      final item = testItem(unit: ItemUnit.kg);

      expect(convertToItemUnit(1.5, ItemUnit.kg, item), 1.5);
    });

    test('converts kilos into grams', () {
      final item = testItem(unit: ItemUnit.g);

      expect(convertToItemUnit(1.5, ItemUnit.kg, item), 1500);
    });

    test('converts grams into kilos', () {
      final item = testItem(unit: ItemUnit.kg);

      expect(convertToItemUnit(500, ItemUnit.g, item), 0.5);
    });

    test('converts pieces through the average piece weight', () {
      final item = testItem(unit: ItemUnit.kg, avgPieceWeight: 1.4);

      expect(convertToItemUnit(2, ItemUnit.pcs, item), closeTo(2.8, 0.0001));
    });

    test('converts pieces into grams as well', () {
      final item = testItem(unit: ItemUnit.g, avgPieceWeight: 250);

      expect(convertToItemUnit(2, ItemUnit.pcs, item), 500);
    });

    test('refuses pieces when the item has no average piece weight', () {
      final item = testItem(unit: ItemUnit.kg);

      expect(convertToItemUnit(2, ItemUnit.pcs, item), isNull);
    });

    test('refuses a weight for an item counted in pieces', () {
      final item = testItem(unit: ItemUnit.pcs, avgPieceWeight: 1.4);

      expect(convertToItemUnit(2, ItemUnit.kg, item), isNull);
    });

    test('refuses litres against a weight, in both directions', () {
      expect(
        convertToItemUnit(1, ItemUnit.l, testItem(unit: ItemUnit.kg)),
        isNull,
      );
      expect(
        convertToItemUnit(1, ItemUnit.kg, testItem(unit: ItemUnit.l)),
        isNull,
      );
    });

    test('accepts litres for an item measured in litres', () {
      expect(convertToItemUnit(2, ItemUnit.l, testItem(unit: ItemUnit.l)), 2);
    });
  });

  group('unitsFor', () {
    test('offers the item unit first', () {
      expect(unitsFor(testItem(unit: ItemUnit.g)).first, ItemUnit.g);
    });

    test('offers both weights when the item is weighed', () {
      expect(unitsFor(testItem(unit: ItemUnit.kg)), [ItemUnit.kg, ItemUnit.g]);
    });

    test('offers pieces once the item has an average piece weight', () {
      expect(unitsFor(testItem(unit: ItemUnit.kg, avgPieceWeight: 1.4)), [
        ItemUnit.kg,
        ItemUnit.g,
        ItemUnit.pcs,
      ]);
    });

    test('offers only its own unit for pieces and litres', () {
      expect(unitsFor(testItem(unit: ItemUnit.pcs)), [ItemUnit.pcs]);
      expect(unitsFor(testItem(unit: ItemUnit.l)), [ItemUnit.l]);
    });
  });
}
