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

  group('stockEventFromFirestore', () {
    final date = Timestamp.fromDate(DateTime(2026, 9, 24, 20, 15));

    test('round-trips an event the app wrote', () {
      const event = StockEvent(
        itemId: 'rice',
        type: StockEventType.consumed,
        quantity: 0.2,
        unit: ItemUnit.kg,
        userId: 'abc123',
        note: 'pasta night',
      );

      final read = stockEventFromFirestore(
        'e1',
        stockEventToFirestore(event, date: date),
      );

      expect(
        read,
        StockEventRecord(id: 'e1', event: event, date: date.toDate()),
      );
    });

    test('skips an event it cannot explain', () {
      final valid = {
        'itemId': 'rice',
        'type': 'recount',
        'quantity': 1,
        'unit': 'kg',
        'date': date,
        'userId': 'abc123',
      };

      expect(stockEventFromFirestore('e', {...valid, 'itemId': ''}), isNull);
      expect(stockEventFromFirestore('e', {...valid, 'type': 'spilt'}), isNull);
      expect(stockEventFromFirestore('e', {...valid, 'quantity': '1'}), isNull);
      expect(stockEventFromFirestore('e', {...valid, 'date': null}), isNull);
      expect(stockEventFromFirestore('e', valid), isNotNull);
    });

    test('reads a blank note as no note and a missing user as unknown', () {
      final read = stockEventFromFirestore('e', {
        'itemId': 'rice',
        'type': 'adjustment',
        'quantity': -0.3,
        'unit': 'kg',
        'date': date,
        'note': '  ',
      });

      expect(read?.event.note, isNull);
      expect(read?.event.userId, isEmpty);
      expect(read?.event.quantity, -0.3);
    });
  });
}
