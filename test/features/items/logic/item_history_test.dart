import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_history.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';

import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

StockEventRecord _event(
  StockEventType type,
  double quantity, {
  ItemUnit unit = ItemUnit.kg,
  DateTime? date,
  String? note,
  String itemId = 'rice',
}) => StockEventRecord(
  id: '${type.key}$quantity',
  date: date ?? DateTime(2026, 9, 20),
  event: StockEvent(
    itemId: itemId,
    type: type,
    quantity: quantity,
    unit: unit,
    userId: 'u1',
    note: note,
  ),
);

void main() {
  final rice = testItem(id: 'rice', avgPieceWeight: 0.5);

  test('signs each event the way it moved the stock', () {
    final history = itemHistory(
      item: rice,
      events: [
        _event(StockEventType.consumed, 0.2, date: DateTime(2026, 9, 24)),
        _event(StockEventType.adjustment, -0.3, date: DateTime(2026, 9, 23)),
        _event(StockEventType.adjustment, 0.5, date: DateTime(2026, 9, 22)),
        _event(StockEventType.recount, 1.2, date: DateTime(2026, 9, 21)),
      ],
      purchases: const [],
    );

    expect(history.map((entry) => (entry.kind, entry.quantity)), [
      (HistoryKind.use, -0.2),
      (HistoryKind.adjustment, -0.3),
      (HistoryKind.adjustment, 0.5),
      (HistoryKind.recount, 1.2),
    ]);
  });

  test('a purchase adds what it bought of the item, in the item unit', () {
    final history = itemHistory(
      item: rice,
      events: const [],
      purchases: [
        testPurchase(
          shopName: ' Lidl ',
          paidByUserId: 'u2',
          lines: [
            testLine(itemId: 'rice', quantity: 500, unit: ItemUnit.g),
            testLine(itemId: 'rice', quantity: 2, unit: ItemUnit.pcs),
            testLine(itemId: 'milk'),
          ],
        ),
      ],
    );

    final bought = history.single;
    expect(bought.kind, HistoryKind.purchase);
    expect(bought.quantity, 1.5);
    expect(bought.unit, ItemUnit.kg);
    expect(bought.shopName, 'Lidl');
    expect(bought.userId, 'u2');
  });

  test('an event in another unit reads in the item unit', () {
    final history = itemHistory(
      item: rice,
      events: [_event(StockEventType.consumed, 300, unit: ItemUnit.g)],
      purchases: const [],
    );

    expect(history.single.quantity, closeTo(-0.3, 1e-9));
    expect(history.single.unit, ItemUnit.kg);
  });

  test('a line that no longer converts is shown as it was entered', () {
    final history = itemHistory(
      item: rice,
      events: const [],
      purchases: [
        testPurchase(
          lines: [testLine(itemId: 'rice', quantity: 1, unit: ItemUnit.l)],
        ),
      ],
    );

    expect(history.single.quantity, 1);
    expect(history.single.unit, ItemUnit.l);
  });

  test('lists newest first, events and purchases together', () {
    final history = itemHistory(
      item: rice,
      events: [
        _event(StockEventType.consumed, 0.1, date: DateTime(2026, 9, 10)),
        _event(StockEventType.consumed, 0.1, date: DateTime(2026, 9, 25)),
      ],
      purchases: [
        testPurchase(
          date: DateTime(2026, 9, 15),
          lines: [testLine(itemId: 'rice')],
        ),
      ],
    );

    expect(history.map((entry) => entry.date), [
      DateTime(2026, 9, 25),
      DateTime(2026, 9, 15),
      DateTime(2026, 9, 10),
    ]);
  });

  test('leaves out events for other items and purchases without it', () {
    final history = itemHistory(
      item: rice,
      events: [_event(StockEventType.consumed, 1, itemId: 'milk')],
      purchases: [
        testPurchase(lines: [testLine(itemId: 'milk')]),
      ],
    );

    expect(history, isEmpty);
  });

  test('keeps the note that explains an event', () {
    final history = itemHistory(
      item: rice,
      events: [_event(StockEventType.consumed, 0.2, note: 'pasta night')],
      purchases: const [],
    );

    expect(history.single.note, 'pasta night');
  });
}
