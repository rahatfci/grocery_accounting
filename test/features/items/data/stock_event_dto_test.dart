import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/data/stock_event_dto.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';

void main() {
  final date = Timestamp.fromDate(DateTime(2026, 9, 23, 18, 5));

  test('writes every field under its stored key', () {
    const event = StockEvent(
      itemId: 'abc123',
      type: StockEventType.consumed,
      quantity: 2,
      unit: ItemUnit.pcs,
      userId: 'uid-1',
      note: 'Roast on Sunday',
    );

    expect(stockEventToFirestore(event, date: date), {
      'itemId': 'abc123',
      'quantity': 2.0,
      'unit': 'pcs',
      'date': date,
      'userId': 'uid-1',
      'type': 'consumed',
      'note': 'Roast on Sunday',
    });
  });

  test('keeps a removing adjustment negative and an absent note null', () {
    const event = StockEvent(
      itemId: 'abc123',
      type: StockEventType.adjustment,
      quantity: -0.5,
      unit: ItemUnit.kg,
      userId: 'uid-1',
    );

    final body = stockEventToFirestore(event, date: date);

    expect(body['type'], 'adjustment');
    expect(body['quantity'], -0.5);
    expect(body.containsKey('note'), isTrue);
    expect(body['note'], isNull);
  });

  test('stores a recount under its own type key', () {
    const event = StockEvent(
      itemId: 'abc123',
      type: StockEventType.recount,
      quantity: 0,
      unit: ItemUnit.l,
      userId: 'uid-1',
    );

    expect(stockEventToFirestore(event, date: date)['type'], 'recount');
    expect(stockEventToFirestore(event, date: date)['unit'], 'l');
  });
}
