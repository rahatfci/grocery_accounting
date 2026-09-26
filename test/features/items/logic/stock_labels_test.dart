import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_labels.dart';
import 'package:grocery_accounting/features/items/logic/stock_status.dart';

final _baseline = DateTime(2026, 9, 26, 9);

Item _item({double stock = 2.1, double usage = 0.12, double threshold = 1}) =>
    Item(
      id: 'pasta',
      name: 'Pasta',
      unit: ItemUnit.kg,
      category: 'pantry',
      avgPieceWeight: null,
      dailyUsage: usage,
      lowThreshold: threshold,
      stockAtBaseline: stock,
      baselineDate: _baseline,
    );

void main() {
  test('usage reads per day, or as logged by hand', () {
    expect(usageLabel(_item(usage: 0.1)), '0.1 kg a day');
    expect(usageLabel(_item(usage: 0)), 'Logged by hand');
  });

  test('kind says staple or not, and the unit', () {
    expect(kindLabel(_item()), 'Staple · kg');
    expect(kindLabel(_item(usage: 0)), 'Not a staple · kg');
  });

  group('statusLabel', () {
    String label(Item item) =>
        statusLabel(item, stockStatusOf(item, now: _baseline), now: _baseline);

    test('a healthy staple counts its days', () {
      expect(label(_item()), '~17 days left');
    });

    test('a staple due soon gives its date', () {
      expect(
        label(_item(stock: 1.5, usage: 0.5, threshold: 0.2)),
        'Runs out 29/09',
      );
    });

    test('low, out and not a staple', () {
      expect(label(_item(stock: 0.3)), 'Low');
      expect(label(_item(stock: 0)), 'Out');
      expect(label(_item(usage: 0, threshold: 0)), 'Not a staple');
    });
  });

  group('runOutCaption', () {
    test('gives the date a staple runs out', () {
      final item = _item(stock: 0.3, usage: 0.1);

      expect(
        runOutCaption(item, StockStatus.low, now: _baseline),
        'Runs out around 29/09',
      );
    });

    test('gives the date an out item ran out', () {
      final item = _item(stock: 0, usage: 0);

      expect(
        runOutCaption(item, StockStatus.out, now: _baseline),
        'Out since 26/09',
      );
    });

    test('says when something is not a staple', () {
      expect(
        runOutCaption(_item(usage: 0), StockStatus.untracked, now: _baseline),
        'Not a staple',
      );
    });
  });

  test('a stock change carries its sign', () {
    expect(formatStockChange(1, ItemUnit.kg), '+1 kg');
    expect(formatStockChange(-0.2, ItemUnit.kg), '−0.2 kg');
    expect(formatStockChange(0, ItemUnit.pcs), '0 pcs');
  });
}
