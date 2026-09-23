import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';

import '../fake_item_repository.dart';

void main() {
  final baseline = DateTime(2026, 9, 1, 10, 30);
  final twoDaysLater = baseline.add(const Duration(days: 2));

  Item stocked({
    double stock = 4,
    double dailyUsage = 0,
    ItemUnit unit = ItemUnit.kg,
    double? avgPieceWeight,
  }) => testItem(
    dailyUsage: dailyUsage,
    unit: unit,
    avgPieceWeight: avgPieceWeight,
  ).copyWith(stockAtBaseline: stock, baselineDate: baseline);

  StockEvent event(
    StockEventType type,
    double quantity, {
    ItemUnit unit = ItemUnit.kg,
  }) => StockEvent(
    itemId: 'abc123',
    type: type,
    quantity: quantity,
    unit: unit,
    userId: 'uid-1',
  );

  group('baselineAfter', () {
    test('a consumption subtracts from the derived stock', () {
      final item = stocked(stock: 4, dailyUsage: 0.5);

      expect(
        baselineAfter(
          item,
          event(StockEventType.consumed, 1),
          now: twoDaysLater,
        ),
        2,
      );
    });

    test('a consumption larger than the stock leaves zero', () {
      final item = stocked(stock: 1);

      expect(
        baselineAfter(item, event(StockEventType.consumed, 3), now: baseline),
        0,
      );
    });

    test('an adding adjustment starts from zero when stock is past empty', () {
      // 1 kg at 0.5 a day is 1 kg short after four days.
      final item = stocked(stock: 1, dailyUsage: 0.5);

      expect(
        baselineAfter(
          item,
          event(StockEventType.adjustment, 2),
          now: baseline.add(const Duration(days: 4)),
        ),
        2,
      );
    });

    test('a removing adjustment subtracts', () {
      final item = stocked(stock: 4);

      expect(
        baselineAfter(
          item,
          event(StockEventType.adjustment, -1.5),
          now: baseline,
        ),
        2.5,
      );
    });

    test('a removing adjustment larger than the stock leaves zero', () {
      final item = stocked(stock: 1);

      expect(
        baselineAfter(
          item,
          event(StockEventType.adjustment, -5),
          now: baseline,
        ),
        0,
      );
    });

    test('a recount replaces the stock whatever it was', () {
      final item = stocked(stock: 4, dailyUsage: 0.5);

      expect(
        baselineAfter(
          item,
          event(StockEventType.recount, 7),
          now: twoDaysLater,
        ),
        7,
      );
    });

    test('a recount to zero is zero', () {
      final item = stocked(stock: 4);

      expect(
        baselineAfter(item, event(StockEventType.recount, 0), now: baseline),
        0,
      );
    });

    test('converts the entered unit into the item unit', () {
      final item = stocked(stock: 2);

      expect(
        baselineAfter(
          item,
          event(StockEventType.consumed, 500, unit: ItemUnit.g),
          now: baseline,
        ),
        1.5,
      );
    });

    test('converts pieces through the average piece weight', () {
      final item = stocked(stock: 0, avgPieceWeight: 1.5);

      expect(
        baselineAfter(
          item,
          event(StockEventType.recount, 2, unit: ItemUnit.pcs),
          now: baseline,
        ),
        3,
      );
    });

    test('starts from zero when the stored stock is not finite', () {
      final item = stocked(stock: double.nan);

      expect(
        baselineAfter(item, event(StockEventType.adjustment, 2), now: baseline),
        2,
      );
      expect(
        baselineAfter(item, event(StockEventType.consumed, 1), now: baseline),
        0,
      );
    });

    test('is null when the result overflows to infinity', () {
      final grams = stocked(stock: 0, unit: ItemUnit.g);

      expect(
        baselineAfter(
          grams,
          event(StockEventType.recount, 1e306),
          now: baseline,
        ),
        isNull,
      );
      expect(
        baselineAfter(
          stocked(stock: 1e308),
          event(StockEventType.adjustment, 1e308),
          now: baseline,
        ),
        isNull,
      );
    });

    test('is null for a unit the item cannot be measured in', () {
      final item = stocked(stock: 2);

      expect(
        baselineAfter(
          item,
          event(StockEventType.consumed, 1, unit: ItemUnit.l),
          now: baseline,
        ),
        isNull,
      );
    });
  });

  group('stockEventQuantityError', () {
    test('asks for a number when empty', () {
      for (final type in StockEventType.values) {
        expect(stockEventQuantityError(type, '  '), 'Enter a number');
        expect(stockEventQuantityError(type, null), 'Enter a number');
      }
    });

    test('rejects text that is not a number', () {
      expect(
        stockEventQuantityError(StockEventType.consumed, 'abc'),
        'Enter a valid number',
      );
    });

    test('rejects values that are not finite', () {
      for (final raw in ['NaN', 'Infinity', '-Infinity', '1e400']) {
        for (final type in StockEventType.values) {
          expect(
            stockEventQuantityError(type, raw),
            'Enter a valid number',
            reason: raw,
          );
        }
      }
    });

    test('accepts a decimal comma', () {
      expect(stockEventQuantityError(StockEventType.consumed, '0,5'), isNull);
    });

    test('refuses zero for a consumption or an adjustment', () {
      expect(
        stockEventQuantityError(StockEventType.consumed, '0'),
        'Must be greater than zero',
      );
      expect(
        stockEventQuantityError(StockEventType.adjustment, '0'),
        'Must be greater than zero',
      );
    });

    test('accepts zero for a recount but not a negative', () {
      expect(stockEventQuantityError(StockEventType.recount, '0'), isNull);
      expect(
        stockEventQuantityError(StockEventType.recount, '-1'),
        'Cannot be negative',
      );
    });
  });

  test('every type has a distinct stored key', () {
    expect(StockEventType.values.map((type) => type.key), [
      'consumed',
      'adjustment',
      'recount',
    ]);
  });
}
