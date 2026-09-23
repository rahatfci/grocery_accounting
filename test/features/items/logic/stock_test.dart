import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock.dart';

import '../fake_item_repository.dart';

void main() {
  final baseline = DateTime(2026, 9, 1, 10, 30);

  group('currentStock', () {
    test('is the baseline itself at the baseline moment', () {
      final item = testItem(
        dailyUsage: 0.5,
      ).copyWith(stockAtBaseline: 4, baselineDate: baseline);

      expect(currentStock(item, now: baseline), 4);
    });

    test('falls by the daily usage for each day since the baseline', () {
      final item = testItem(
        dailyUsage: 0.5,
      ).copyWith(stockAtBaseline: 4, baselineDate: baseline);

      expect(currentStock(item, now: baseline.add(const Duration(days: 2))), 3);
    });

    test('counts part of a day', () {
      final item = testItem(
        dailyUsage: 2,
      ).copyWith(stockAtBaseline: 5, baselineDate: baseline);

      expect(
        currentStock(item, now: baseline.add(const Duration(hours: 12))),
        4,
      );
    });

    test('does not move for an item that is not a staple', () {
      final item = testItem(
        dailyUsage: 0,
      ).copyWith(stockAtBaseline: 3, baselineDate: baseline);

      expect(
        currentStock(item, now: baseline.add(const Duration(days: 100))),
        3,
      );
    });

    test('goes negative once an item is past empty, rather than clamping', () {
      final item = testItem(
        dailyUsage: 1,
      ).copyWith(stockAtBaseline: 2, baselineDate: baseline);

      expect(
        currentStock(item, now: baseline.add(const Duration(days: 5))),
        -3,
      );
    });

    test('consumes nothing when the baseline is in the future', () {
      final item = testItem(
        dailyUsage: 1,
      ).copyWith(stockAtBaseline: 2, baselineDate: baseline);

      expect(
        currentStock(item, now: baseline.subtract(const Duration(days: 3))),
        2,
      );
    });
  });

  group('restockedBaseline', () {
    test('adds the bought quantity to what is left', () {
      final item = testItem(
        dailyUsage: 0.5,
      ).copyWith(stockAtBaseline: 4, baselineDate: baseline);

      expect(
        restockedBaseline(item, 2, now: baseline.add(const Duration(days: 2))),
        5,
      );
    });

    test('credits the whole purchase to an item that ran out days ago', () {
      final item = testItem(
        dailyUsage: 1,
      ).copyWith(stockAtBaseline: 1, baselineDate: baseline);

      expect(
        restockedBaseline(item, 1, now: baseline.add(const Duration(days: 4))),
        1,
      );
    });

    test('starts a new item at the quantity bought', () {
      final item = testItem(
        dailyUsage: 0,
      ).copyWith(stockAtBaseline: 0, baselineDate: baseline);

      expect(restockedBaseline(item, 1.5, now: baseline), 1.5);
    });
  });

  group('daysSince', () {
    test('is fractional', () {
      expect(daysSince(baseline, baseline.add(const Duration(hours: 6))), 0.25);
    });

    test('is zero for a baseline that has not happened yet', () {
      expect(
        daysSince(baseline, baseline.subtract(const Duration(days: 1))),
        0,
      );
    });
  });

  group('formatStock', () {
    test('drops a trailing zero and appends the unit label', () {
      expect(formatStock(3.5, ItemUnit.kg), '3.5 kg');
      expect(formatStock(2, ItemUnit.l), '2 L');
    });

    test('rounds to two decimals', () {
      expect(formatStock(1.23456, ItemUnit.kg), '1.23 kg');
      expect(formatStock(0.1 + 0.2, ItemUnit.kg), '0.3 kg');
    });

    test('reads a non-finite stock as unknown instead of throwing', () {
      expect(formatStock(double.nan, ItemUnit.kg), 'Unknown');
      expect(formatStock(double.infinity, ItemUnit.kg), 'Unknown');
    });

    test('renders any finite value without throwing', () {
      expect(formatStock(1e307, ItemUnit.kg), '1e+307 kg');
      expect(
        formatStock(12345678901234567890.0, ItemUnit.g),
        '12345678901234567168 g',
      );
      expect(formatStock(0.004, ItemUnit.kg), '0 kg');
      expect(formatStock(2.10, ItemUnit.kg), '2.1 kg');
      expect(formatStock(100, ItemUnit.g), '100 g');
    });

    test('shows stock past empty as zero', () {
      expect(formatStock(-1.5, ItemUnit.pcs), '0 pcs');
      expect(formatStock(-0.001, ItemUnit.g), '0 g');
    });
  });
}
