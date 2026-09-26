import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_status.dart';

final _baseline = DateTime(2026, 9, 20, 9);

Item _item({
  double stock = 2,
  double dailyUsage = 0.1,
  double lowThreshold = 1,
  DateTime? baselineDate,
}) => Item(
  id: 'rice',
  name: 'Rice',
  unit: ItemUnit.kg,
  category: 'pantry',
  avgPieceWeight: null,
  dailyUsage: dailyUsage,
  lowThreshold: lowThreshold,
  stockAtBaseline: stock,
  baselineDate: baselineDate ?? _baseline,
);

void main() {
  group('stockStatusOf', () {
    test('a staple with weeks left is healthy', () {
      expect(
        stockStatusOf(_item(stock: 3), now: _baseline),
        StockStatus.healthy,
      );
    });

    test('a staple that runs out within a week is soon', () {
      expect(
        stockStatusOf(
          _item(stock: 1.5, dailyUsage: 0.5, lowThreshold: 0.2),
          now: _baseline,
        ),
        StockStatus.soon,
      );
    });

    test('under the threshold is low however long it would last', () {
      expect(
        stockStatusOf(
          _item(stock: 0.3, dailyUsage: 0.01, lowThreshold: 1),
          now: _baseline,
        ),
        StockStatus.low,
      );
    });

    test('nothing left is out, before it is low', () {
      final ranOut = _item(stock: 0.2);

      expect(
        stockStatusOf(ranOut, now: _baseline.add(const Duration(days: 3))),
        StockStatus.out,
      );
    });

    test('a non-staple with stock is untracked', () {
      expect(
        stockStatusOf(_item(dailyUsage: 0, lowThreshold: 0), now: _baseline),
        StockStatus.untracked,
      );
    });

    test('a non-staple with nothing left is still out', () {
      expect(
        stockStatusOf(_item(stock: 0, dailyUsage: 0), now: _baseline),
        StockStatus.out,
      );
    });

    test('a stock that is not a number is untracked, not out', () {
      expect(
        stockStatusOf(_item(stock: double.nan), now: _baseline),
        StockStatus.untracked,
      );
    });

    test('a staple too slow to have a run-out date is healthy', () {
      expect(
        stockStatusOf(
          _item(stock: 500, dailyUsage: 0.1, lowThreshold: 1),
          now: _baseline,
        ),
        StockStatus.healthy,
      );
    });
  });

  group('daysLeft', () {
    test('counts whole days to the run-out date', () {
      expect(daysLeft(_item(stock: 2.1, dailyUsage: 0.12), now: _baseline), 17);
    });

    test('is zero once the date has passed', () {
      expect(
        daysLeft(_item(), now: _baseline.add(const Duration(days: 40))),
        0,
      );
    });

    test('is null for something that is not a staple', () {
      expect(daysLeft(_item(dailyUsage: 0), now: _baseline), isNull);
    });
  });

  group('outSince', () {
    test('a staple ran out when its stock reached zero', () {
      final item = _item(stock: 0.2, dailyUsage: 0.1);

      expect(
        outSince(item, now: _baseline.add(const Duration(days: 5))),
        _baseline.add(const Duration(days: 2)),
      );
    });

    test('anything else ran out at the event that emptied it', () {
      final item = _item(stock: 0, dailyUsage: 0);

      expect(
        outSince(item, now: _baseline.add(const Duration(days: 5))),
        _baseline,
      );
    });

    test('is null while there is still stock', () {
      expect(outSince(_item(), now: _baseline), isNull);
    });
  });

  group('stockLevel', () {
    test('is the stock against the threshold', () {
      expect(stockLevel(0.2, 0.5), closeTo(0.4, 1e-9));
    });

    test('is full at or over the threshold', () {
      expect(stockLevel(3, 1), 1);
    });

    test('is empty at or below zero and for a non-number', () {
      expect(stockLevel(0, 1), 0);
      expect(stockLevel(-1, 1), 0);
      expect(stockLevel(double.nan, 1), 0);
    });

    test('is full for stock with no threshold', () {
      expect(stockLevel(2, 0), 1);
    });
  });
}
