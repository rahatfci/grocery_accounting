import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/reminders/logic/run_out_reminder.dart';

import '../../items/fake_item_repository.dart';

void main() {
  final baseline = DateTime(2026, 9, 1, 10, 30);

  /// A staple that runs out [days] after [baseline].
  Item staple(String name, {required double days, String? id}) => testItem(
    id: id ?? name,
    name: name,
    dailyUsage: 1,
  ).copyWith(stockAtBaseline: days, baselineDate: baseline);

  test('reminds at 09:00 on the day before the run-out day', () {
    final reminders = runOutReminders([staple('Rice', days: 4)], now: baseline);

    expect(reminders, [
      RunOutReminder(
        itemId: 'Rice',
        itemName: 'Rice',
        runsOutAt: DateTime(2026, 9, 5, 10, 30),
        remindAt: DateTime(2026, 9, 4, 9),
      ),
    ]);
  });

  test('uses the calendar day, not 24 hours before', () {
    // Runs out at 06:30 on 5 September, so the reminder is 09:00 on the 4th,
    // more than 24 hours earlier.
    final item = testItem(dailyUsage: 1).copyWith(
      stockAtBaseline: 3.5,
      baselineDate: DateTime(2026, 9, 1, 18, 30),
    );

    final reminders = runOutReminders([item], now: baseline);

    expect(reminders.single.remindAt, DateTime(2026, 9, 4, 9));
  });

  test('crosses a month boundary', () {
    final item = testItem(
      dailyUsage: 1,
    ).copyWith(stockAtBaseline: 1, baselineDate: DateTime(2026, 9, 30, 12));

    final reminders = runOutReminders([item], now: DateTime(2026, 9, 29));

    expect(reminders.single.remindAt, DateTime(2026, 9, 30, 9));
  });

  test('leaves out anything that is not a staple', () {
    final item = testItem(
      dailyUsage: 0,
    ).copyWith(stockAtBaseline: 3, baselineDate: baseline);

    expect(runOutReminders([item], now: baseline), isEmpty);
  });

  test('leaves out a staple already out', () {
    final reminders = runOutReminders([
      staple('Rice', days: 2),
    ], now: baseline.add(const Duration(days: 3)));

    expect(reminders, isEmpty);
  });

  test('leaves out a staple whose reminder time has already passed', () {
    // Runs out at 10:30 on the 2nd, so the reminder would be 09:00 on the 1st,
    // before the 10:30 now.
    final reminders = runOutReminders([staple('Rice', days: 1)], now: baseline);

    expect(reminders, isEmpty);
  });

  test('keeps a reminder due later today', () {
    final reminders = runOutReminders([
      staple('Rice', days: 1),
    ], now: DateTime(2026, 9, 1, 8));

    expect(reminders.single.remindAt, DateTime(2026, 9, 1, 9));
  });

  test('leaves out a non-finite or far-off staple', () {
    final reminders = runOutReminders([
      staple('Nan', days: double.nan),
      staple('Far', days: 1e9),
    ], now: baseline);

    expect(reminders, isEmpty);
  });

  test('orders by reminder time, then name, then input order', () {
    final reminders = runOutReminders([
      staple('pasta', days: 10),
      staple('Rice', days: 4, id: 'rice-1'),
      staple('Beans', days: 4),
      staple('Rice', days: 4, id: 'rice-2'),
    ], now: baseline);

    expect(
      [for (final r in reminders) r.itemId],
      ['Beans', 'rice-1', 'rice-2', 'pasta'],
    );
  });

  test('keeps only the soonest reminders up to the cap', () {
    final items = [
      for (var i = maxRunOutReminders + 5; i > 0; i--)
        staple('Item $i', days: 2.0 + i),
    ];

    final reminders = runOutReminders(items, now: baseline);

    expect(reminders, hasLength(maxRunOutReminders));
    expect(reminders.first.itemName, 'Item 1');
    expect(reminders.last.itemName, 'Item $maxRunOutReminders');
  });

  test('is empty for an empty catalogue', () {
    expect(runOutReminders(const [], now: baseline), isEmpty);
  });

  test('does not change as the clock moves on', () {
    final items = [staple('Rice', days: 4)];

    expect(
      runOutReminders(items, now: baseline),
      runOutReminders(items, now: baseline.add(const Duration(hours: 20))),
    );
  });

  test('names the item and the run-out day', () {
    final reminder = RunOutReminder(
      itemId: 'rice',
      itemName: 'Rice',
      runsOutAt: DateTime(2026, 9, 5, 10, 30),
      remindAt: DateTime(2026, 9, 4, 9),
    );

    expect(reminder.title, 'Rice is running out');
    expect(reminder.body, 'Expected to run out on 05/09/2026.');
  });
}
