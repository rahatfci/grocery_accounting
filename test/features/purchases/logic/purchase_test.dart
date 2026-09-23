import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';

PurchaseLine _line({String? itemId, String rawText = 'Rice'}) => PurchaseLine(
  itemId: itemId,
  rawText: rawText,
  quantity: 1,
  unit: ItemUnit.kg,
  lineTotal: 2,
);

Purchase _purchase(List<PurchaseLine> lines) => Purchase(
  id: 'p1',
  date: DateTime(2026, 9, 21),
  shopName: 'Conad',
  total: 12.5,
  paidByUserId: 'u1',
  receiptImagePath: null,
  source: PurchaseSource.manual,
  lines: lines,
);

void main() {
  group('Purchase.itemIds', () {
    test('is empty for a purchase with no lines', () {
      expect(_purchase(const []).itemIds, isEmpty);
    });

    test('lists each referenced item once, sorted', () {
      final purchase = _purchase([
        _line(itemId: 'b'),
        _line(itemId: 'a'),
        _line(itemId: 'b'),
      ]);

      expect(purchase.itemIds, ['a', 'b']);
    });

    test('skips a line that has not been matched to an item', () {
      final purchase = _purchase([_line(itemId: null), _line(itemId: 'a')]);

      expect(purchase.itemIds, ['a']);
    });
  });

  group('PurchaseSource', () {
    test('round-trips its stored keys', () {
      for (final source in PurchaseSource.values) {
        expect(PurchaseSource.fromKey(source.key), source);
      }
    });

    test('reads an unknown key as manual rather than failing', () {
      expect(PurchaseSource.fromKey('imported'), PurchaseSource.manual);
    });
  });
}
