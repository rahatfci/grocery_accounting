import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/dates.dart';

void main() {
  final now = DateTime(2026, 9, 26, 9, 30);

  test('formatDayMonth pads the day and the month', () {
    expect(formatDayMonth(DateTime(2026, 3, 4)), '04/03');
  });

  test('weekdayName is the English name of the day', () {
    expect(weekdayName(DateTime(2026, 9, 24)), 'Thursday');
  });

  group('daysBefore', () {
    test('counts calendar days, not 24 hour spans', () {
      expect(daysBefore(DateTime(2026, 9, 25, 23, 50), now), 1);
      expect(daysBefore(DateTime(2026, 9, 26, 0, 5), now), 0);
    });

    test('is negative for a later day', () {
      expect(daysBefore(DateTime(2026, 9, 27), now), -1);
    });

    test('is not thrown by a daylight saving change', () {
      expect(daysBefore(DateTime(2026, 10, 24, 12), DateTime(2026, 10, 26)), 2);
    });
  });

  group('relativeDay', () {
    test('names today and yesterday', () {
      expect(relativeDay(DateTime(2026, 9, 26, 8), now: now), 'Today');
      expect(relativeDay(DateTime(2026, 9, 25, 20), now: now), 'Yesterday');
    });

    test('gives the date for anything older', () {
      expect(relativeDay(DateTime(2026, 9, 20), now: now), '20/09');
    });
  });
}
