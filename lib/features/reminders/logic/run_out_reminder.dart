import 'package:equatable/equatable.dart';

import '../../items/logic/item.dart';
import '../../items/logic/run_out.dart';
import '../../purchases/logic/money.dart';

/// The iOS limit on pending local notifications.
const int maxRunOutReminders = 64;

/// The local hour a reminder fires, on the day before the run-out day.
const int reminderHour = 9;

/// A local notification warning that one staple is about to run out.
final class RunOutReminder extends Equatable {
  const RunOutReminder({
    required this.itemId,
    required this.itemName,
    required this.runsOutAt,
    required this.remindAt,
  });

  final String itemId;
  final String itemName;
  final DateTime runsOutAt;
  final DateTime remindAt;

  String get title => '$itemName is running out';

  String get body =>
      'Expected to run out on ${formatPurchaseDate(runsOutAt.toLocal())}.';

  @override
  List<Object?> get props => [itemId, itemName, runsOutAt, remindAt];
}

/// The reminders that should be scheduled right now, soonest first.
///
/// Calculated, never stored: the caller replaces everything scheduled with
/// this list. An item whose reminder time has already passed gets none,
/// because it is about to run out and firing at once would repeat on every
/// launch.
List<RunOutReminder> runOutReminders(
  List<Item> items, {
  required DateTime now,
}) {
  final planned = [
    for (final (index, item) in items.indexed)
      if (runOutAt(item) case final runsOut? when runsOut.isAfter(now))
        if (_reminderTime(runsOut) case final remindAt
            when remindAt.isAfter(now))
          (
            index: index,
            reminder: RunOutReminder(
              itemId: item.id,
              itemName: item.name,
              runsOutAt: runsOut,
              remindAt: remindAt,
            ),
          ),
  ];

  // `List.sort` is not stable, so the input position breaks the last tie.
  planned.sort((a, b) {
    final byTime = a.reminder.remindAt.compareTo(b.reminder.remindAt);
    if (byTime != 0) {
      return byTime;
    }
    final byName = a.reminder.itemName.toLowerCase().compareTo(
      b.reminder.itemName.toLowerCase(),
    );
    return byName != 0 ? byName : a.index - b.index;
  });
  return [for (final entry in planned.take(maxRunOutReminders)) entry.reminder];
}

/// 09:00 local on the calendar day before [runsOutAt].
///
/// Built from local date parts rather than by subtracting 24 hours, so a DST
/// change in between still lands on 09:00.
DateTime _reminderTime(DateTime runsOutAt) {
  final local = runsOutAt.toLocal();
  return DateTime(local.year, local.month, local.day - 1, reminderHour);
}
