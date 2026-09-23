import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/run_out.dart';
import 'package:grocery_accounting/features/items/logic/stock.dart';

import '../fake_item_repository.dart';

void main() {
  final baseline = DateTime(2026, 9, 1, 10, 30);

  test('is when the derived stock reaches zero', () {
    final item = testItem(
      dailyUsage: 0.5,
    ).copyWith(stockAtBaseline: 2, baselineDate: baseline);

    final runsOut = runOutAt(item);

    expect(runsOut, baseline.add(const Duration(days: 4)));
    expect(currentStock(item, now: runsOut!), 0);
  });

  test('counts part of a day', () {
    final item = testItem(
      dailyUsage: 2,
    ).copyWith(stockAtBaseline: 1, baselineDate: baseline);

    expect(runOutAt(item), baseline.add(const Duration(hours: 12)));
  });

  test('is the baseline itself for a staple with nothing left', () {
    final item = testItem(
      dailyUsage: 1,
    ).copyWith(stockAtBaseline: 0, baselineDate: baseline);

    expect(runOutAt(item), baseline);
  });

  test('is null for anything that is not a staple', () {
    final item = testItem(
      dailyUsage: 0,
    ).copyWith(stockAtBaseline: 3, baselineDate: baseline);

    expect(runOutAt(item), isNull);
  });

  test('is null for a negative usage', () {
    final item = testItem(
      dailyUsage: -1,
    ).copyWith(stockAtBaseline: 3, baselineDate: baseline);

    expect(runOutAt(item), isNull);
  });

  test('is null for a non-finite stock or usage', () {
    final base = testItem().copyWith(baselineDate: baseline);

    expect(runOutAt(base.copyWith(stockAtBaseline: double.nan)), isNull);
    expect(runOutAt(base.copyWith(stockAtBaseline: double.infinity)), isNull);
    expect(
      runOutAt(base.copyWith(stockAtBaseline: 1, dailyUsage: double.nan)),
      isNull,
    );
  });

  test('is null further out than the cap, without overflowing', () {
    final base = testItem(dailyUsage: 1).copyWith(baselineDate: baseline);

    expect(
      runOutAt(base.copyWith(stockAtBaseline: maxRunOutDays.toDouble())),
      isNotNull,
    );
    expect(runOutAt(base.copyWith(stockAtBaseline: maxRunOutDays + 1)), isNull);
    expect(runOutAt(base.copyWith(stockAtBaseline: 1e300)), isNull);
    expect(
      runOutAt(base.copyWith(stockAtBaseline: 1, dailyUsage: 1e-300)),
      isNull,
    );
  });
}
