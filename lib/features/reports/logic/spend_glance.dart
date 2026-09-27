import 'package:equatable/equatable.dart';

import 'spending_report.dart';

/// The one line of money Home shows above the scan hero.
final class SpendGlance extends Equatable {
  const SpendGlance({
    required this.month,
    required this.total,
    required this.change,
    required this.changeFraction,
    required this.balance,
  });

  final DateTime month;
  final double total;

  /// Against the month before. Positive means more was spent.
  final double change;

  /// [change] as a fraction of the month before, or null when nothing was
  /// spent then.
  final double? changeFraction;

  /// The signed-in member against the equal share, or null when they are
  /// not in the household list the share is split across.
  final MemberSpend? balance;

  /// Whether there is anything to show at all. A household that has not
  /// recorded a purchase this month or last has no glance.
  bool get hasSpending => total > 0 || change != 0;

  @override
  List<Object?> get props => [month, total, change, changeFraction, balance];
}

/// The glance for [memberId] from a month's report.
SpendGlance spendGlanceFor(SpendingReport report, String memberId) =>
    SpendGlance(
      month: report.month,
      total: report.monthTotal,
      change: report.monthOverMonthChange,
      changeFraction: report.monthOverMonthFraction,
      balance: report.byPerson
          .where((spend) => spend.hasShare && spend.memberId == memberId)
          .firstOrNull,
    );
