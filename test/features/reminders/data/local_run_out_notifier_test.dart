import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/reminders/data/local_run_out_notifier.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('keeps the instant and carries it in UTC', () {
    final remindAt = DateTime(2026, 9, 4, 9);

    final scheduled = toScheduledDate(remindAt);

    expect(scheduled.location, tz.UTC);
    expect(scheduled.timeZoneOffset, Duration.zero);
    expect(scheduled.isAtSameMomentAs(remindAt), isTrue);
    expect(scheduled.millisecondsSinceEpoch, remindAt.millisecondsSinceEpoch);
  });

  test('keeps a UTC instant as it is', () {
    final remindAt = DateTime.utc(2026, 3, 29, 7);

    expect(toScheduledDate(remindAt).isAtSameMomentAs(remindAt), isTrue);
  });
}
