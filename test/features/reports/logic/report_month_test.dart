import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/reports/logic/report_month.dart';

void main() {
  group('monthStart', () {
    test('strips the day and the time', () {
      expect(monthStart(DateTime(2026, 9, 22, 18, 45, 30)), DateTime(2026, 9));
    });

    test('leaves a date already on the first instant alone', () {
      expect(monthStart(DateTime(2026, 9)), DateTime(2026, 9));
    });
  });

  group('nextMonth', () {
    test('moves forward one month', () {
      expect(nextMonth(DateTime(2026, 9)), DateTime(2026, 10));
    });

    test('rolls December into January of the next year', () {
      expect(nextMonth(DateTime(2026, 12)), DateTime(2027));
    });
  });

  group('previousMonth', () {
    test('moves back one month', () {
      expect(previousMonth(DateTime(2026, 9)), DateTime(2026, 8));
    });

    test('rolls January back into December of the previous year', () {
      expect(previousMonth(DateTime(2026)), DateTime(2025, 12));
    });

    test('round trips with nextMonth across a year boundary', () {
      expect(nextMonth(previousMonth(DateTime(2026))), DateTime(2026));
    });
  });

  group('canViewNextMonth', () {
    final now = DateTime(2026, 9, 22, 18, 45);

    test('is false for the current month', () {
      expect(canViewNextMonth(DateTime(2026, 9), now: now), isFalse);
    });

    test('is false for a later month', () {
      expect(canViewNextMonth(DateTime(2026, 10), now: now), isFalse);
    });

    test('is true for an earlier month', () {
      expect(canViewNextMonth(DateTime(2026, 8), now: now), isTrue);
    });

    test('is true for the previous December', () {
      expect(canViewNextMonth(DateTime(2025, 12), now: now), isTrue);
    });
  });

  test('monthLabel names the month and the year', () {
    expect(monthLabel(DateTime(2026, 9)), 'September 2026');
    expect(monthLabel(DateTime(2025, 12)), 'December 2025');
  });
}
