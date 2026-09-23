import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/running_low.dart';

import '../fake_item_repository.dart';

void main() {
  final baseline = DateTime(2026, 9, 1, 10, 30);

  Item stocked(
    String name, {
    required double stock,
    required double threshold,
    double dailyUsage = 0,
  }) => testItem(
    id: name,
    name: name,
    dailyUsage: dailyUsage,
    lowThreshold: threshold,
  ).copyWith(stockAtBaseline: stock, baselineDate: baseline);

  List<String> names(List<LowStockItem> low) => [
    for (final entry in low) entry.item.name,
  ];

  test('lists an item under its threshold with the stock it was judged on', () {
    final rice = stocked('Rice', stock: 1, threshold: 2);

    expect(runningLow([rice], now: baseline), [
      LowStockItem(item: rice, stock: 1),
    ]);
  });

  test('leaves out an item exactly at its threshold', () {
    expect(
      runningLow([stocked('Rice', stock: 2, threshold: 2)], now: baseline),
      isEmpty,
    );
  });

  test('leaves out an item over its threshold', () {
    expect(
      runningLow([stocked('Rice', stock: 3, threshold: 2)], now: baseline),
      isEmpty,
    );
  });

  test('never flags a non-staple at zero with a zero threshold', () {
    expect(
      runningLow([stocked('Salt', stock: 0, threshold: 0)], now: baseline),
      isEmpty,
    );
  });

  test('flags a staple that ran past empty, even at a zero threshold', () {
    final milk = stocked('Milk', stock: 1, threshold: 0, dailyUsage: 1);
    final now = baseline.add(const Duration(days: 3));

    expect(runningLow([milk], now: now), [LowStockItem(item: milk, stock: -2)]);
  });

  test('picks up a staple once it has run down below the threshold', () {
    final pasta = stocked('Pasta', stock: 3, threshold: 2, dailyUsage: 0.5);

    expect(runningLow([pasta], now: baseline), isEmpty);
    expect(
      names(runningLow([pasta], now: baseline.add(const Duration(days: 3)))),
      ['Pasta'],
    );
  });

  test('leaves out a non-finite stock or threshold', () {
    expect(
      runningLow([
        stocked('Nan stock', stock: double.nan, threshold: 2),
        stocked('Nan threshold', stock: 1, threshold: double.nan),
        stocked('Infinite', stock: double.negativeInfinity, threshold: 2),
        stocked('Infinite threshold', stock: 1, threshold: double.infinity),
      ], now: baseline),
      isEmpty,
    );
  });

  test('puts anything out first, then orders by name ignoring case', () {
    final low = runningLow([
      stocked('pasta', stock: 1, threshold: 2),
      stocked('Milk', stock: 0, threshold: 1),
      stocked('Apples', stock: 1, threshold: 2),
      stocked('Eggs', stock: -1, threshold: 1, dailyUsage: 0),
      stocked('bread', stock: 0.5, threshold: 2),
    ], now: baseline);

    expect(names(low), ['Eggs', 'Milk', 'Apples', 'bread', 'pasta']);
  });

  test('keeps input order between items with the same name', () {
    final first = stocked('Rice', stock: 1, threshold: 2).copyWith(id: 'a');
    final second = stocked('rice', stock: 1.5, threshold: 2).copyWith(id: 'b');

    expect(
      [
        for (final low in runningLow([first, second], now: baseline))
          low.item.id,
      ],
      ['a', 'b'],
    );
    expect(
      [
        for (final low in runningLow([second, first], now: baseline))
          low.item.id,
      ],
      ['b', 'a'],
    );
  });

  test('is empty for an empty catalogue', () {
    expect(runningLow(const [], now: baseline), isEmpty);
  });
}
