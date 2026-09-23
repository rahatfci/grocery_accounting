import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';

import '../../items/fake_item_repository.dart';

PurchaseDraftLine _line(
  Item item, {
  double quantity = 1,
  ItemUnit? unit,
  double lineTotal = 2,
}) => PurchaseDraftLine(
  item: item,
  quantity: quantity,
  unit: unit ?? item.unit,
  lineTotal: lineTotal,
);

String? _byId(Item item) => item.id.isEmpty ? null : item.id;

void main() {
  final rice = testItem(id: 'rice', name: 'Rice');
  final milk = testItem(id: 'milk', name: 'Milk', unit: ItemUnit.l);

  group('a blank draft', () {
    test('starts today, with the signed-in member paying and no lines', () {
      final draft = PurchaseDraft.blank(
        date: DateTime(2026, 9, 21),
        paidByUserId: 'u1',
      );

      expect(draft.shopName, isEmpty);
      expect(draft.totalText, isEmpty);
      expect(draft.paidByUserId, 'u1');
      expect(draft.lines, isEmpty);
      expect(draft.linesTotal, 0);
    });
  });

  test('linesTotal sums the line totals', () {
    final draft =
        PurchaseDraft.blank(
          date: DateTime(2026, 9, 21),
          paidByUserId: 'u1',
        ).copyWith(
          lines: [_line(rice, lineTotal: 2.5), _line(milk, lineTotal: 1.2)],
        );

    expect(draft.linesTotal, closeTo(3.7, 0.0001));
  });

  group('toPurchase', () {
    test('writes a manual purchase with no receipt', () {
      final draft = PurchaseDraft(
        date: DateTime(2026, 9, 21),
        shopName: '  Conad  ',
        totalText: '12,50',
        paidByUserId: 'u1',
        lines: [_line(rice, quantity: 2, lineTotal: 3)],
      );

      final purchase = draft.toPurchase(resolveItemId: _byId);

      expect(purchase.id, isEmpty);
      expect(purchase.shopName, 'Conad');
      expect(purchase.total, 12.5);
      expect(purchase.paidByUserId, 'u1');
      expect(purchase.receiptImagePath, isNull);
      expect(purchase.source, PurchaseSource.manual);
      expect(purchase.lines.single.itemId, 'rice');
      expect(purchase.lines.single.rawText, 'Rice');
      expect(purchase.lines.single.quantity, 2);
      expect(purchase.lines.single.unit, ItemUnit.kg);
      expect(purchase.lines.single.lineTotal, 3);
      expect(purchase.itemIds, ['rice']);
    });

    test('records the day, not the moment the draft was started', () {
      final draft = PurchaseDraft.blank(
        date: DateTime(2026, 9, 21, 18, 30),
        paidByUserId: 'u1',
      );

      expect(
        draft.toPurchase(resolveItemId: _byId).date,
        DateTime(2026, 9, 21),
      );
    });

    test('keeps the entered unit rather than the item unit', () {
      final draft = PurchaseDraft.blank(
        date: DateTime(2026, 9, 21),
        paidByUserId: 'u1',
      ).copyWith(lines: [_line(rice, quantity: 500, unit: ItemUnit.g)]);

      expect(
        draft.toPurchase(resolveItemId: _byId).lines.single.unit,
        ItemUnit.g,
      );
    });

    test('takes the id the commit generated for an item created inline', () {
      final fresh = newTestItem(name: 'Passata');
      final draft = PurchaseDraft.blank(
        date: DateTime(2026, 9, 21),
        paidByUserId: 'u1',
      ).copyWith(lines: [_line(fresh)]);

      final purchase = draft.toPurchase(
        resolveItemId: (item) => item.id.isEmpty ? 'generated' : item.id,
      );

      expect(purchase.lines.single.itemId, 'generated');
      expect(purchase.lines.single.rawText, 'Passata');
      expect(purchase.itemIds, ['generated']);
    });
  });

  group('restockTargets', () {
    test('is empty without lines', () {
      expect(restockTargets(const []), isEmpty);
    });

    test('converts each line into the item unit', () {
      final targets = restockTargets([
        _line(rice, quantity: 500, unit: ItemUnit.g),
      ]);

      expect(targets.single.item, rice);
      expect(targets.single.quantity, 0.5);
    });

    test('sums two lines for the same item into one target', () {
      final targets = restockTargets([
        _line(rice, quantity: 1),
        _line(rice, quantity: 500, unit: ItemUnit.g),
      ]);

      expect(targets, hasLength(1));
      expect(targets.single.quantity, 1.5);
    });

    test('keeps different items apart, in the order they appear', () {
      final targets = restockTargets([_line(milk), _line(rice)]);

      expect(targets.map((target) => target.item.id), ['milk', 'rice']);
    });

    test('merges two lines for the same item created inline', () {
      final fresh = newTestItem(name: 'Passata');
      final targets = restockTargets([_line(fresh), _line(fresh, quantity: 2)]);

      expect(targets, hasLength(1));
      expect(targets.single.quantity, 3);
    });

    test('keeps two different inline items apart, ids or not', () {
      final targets = restockTargets([
        _line(newTestItem(name: 'Passata')),
        _line(newTestItem(name: 'Pesto')),
      ]);

      expect(targets.map((target) => target.item.name), ['Passata', 'Pesto']);
    });

    test('drops a line whose unit cannot reach the item unit', () {
      final targets = restockTargets([_line(rice, unit: ItemUnit.pcs)]);

      expect(targets, isEmpty);
    });
  });

  group('restockKey', () {
    test('is the document id for an item that has one', () {
      expect(restockKey(rice), 'rice');
    });

    test('is the item itself while it has no id', () {
      final fresh = newTestItem(name: 'Passata');

      expect(restockKey(fresh), fresh);
    });
  });
}
