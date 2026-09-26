import 'package:equatable/equatable.dart';

import '../../purchases/logic/money.dart';
import 'report_month.dart';
import 'spending_report.dart';

/// Which way the month went against the one before.
enum Trend { up, down, flat }

/// The change tag under the month total: `+45,50 € · 8% vs August`.
final class MonthChange extends Equatable {
  const MonthChange({required this.label, required this.trend});

  final String label;

  /// Up is more spent, which is against the household.
  final Trend trend;

  @override
  List<Object?> get props => [label, trend];
}

/// The change on the month before, or null when neither month has spending
/// to compare.
MonthChange? monthChange(SpendingReport report) {
  final previous = monthName(previousMonth(report.month));
  final change = report.monthOverMonthChange;
  if (report.monthTotal <= 0 && report.previousMonthTotal <= 0) {
    return null;
  }
  if (change.abs() < 0.005) {
    return MonthChange(label: 'Same as $previous', trend: Trend.flat);
  }
  final trend = change > 0 ? Trend.up : Trend.down;
  final fraction = report.monthOverMonthFraction;
  final amount = formatSignedEuro(change);
  return MonthChange(
    // With nothing spent the month before, a percentage would be infinite.
    label: fraction == null
        ? '$amount vs $previous'
        : '$amount · ${(fraction * 100).round().abs()}% vs $previous',
    trend: trend,
  );
}

String purchaseCountLabel(int count) =>
    count == 1 ? '1 purchase' : '$count purchases';

/// `Equal share: 122,48 € each, across 5 members`, or null with nobody to
/// split the month across.
String? equalShareNote(SpendingReport report) {
  final members = report.memberCount;
  if (members == 0) {
    return null;
  }
  return 'Equal share: ${formatEuro(report.equalShare)} each, across '
      '$members ${members == 1 ? 'member' : 'members'}';
}

/// How full a bar is, against the largest amount beside it.
double barLevel(double amount, double largest) =>
    largest <= 0 || !amount.isFinite ? 0 : (amount / largest).clamp(0, 1);

/// [amount] as a whole percentage of [total].
int percentOf(double amount, double total) =>
    total <= 0 ? 0 : (amount / total * 100).round();

/// Where a member stands against the equal share, under their balance.
String balanceCaption(MemberSpend spend) {
  if (!spend.hasShare) {
    return 'not in the household';
  }
  if (spend.matchesShare) {
    return 'their share';
  }
  return spend.difference > 0 ? 'over share' : 'under share';
}

/// The largest amount any member paid, which the member bars are drawn
/// against.
double largestPaid(SpendingReport report) => report.byPerson.fold(
  0,
  (largest, spend) => spend.paid > largest ? spend.paid : largest,
);
