import 'package:equatable/equatable.dart';

import '../../items/logic/item.dart';
import '../../items/logic/item_category.dart';
import '../../members/logic/household_member.dart';
import '../../purchases/logic/purchase.dart';
import 'report_month.dart';

/// Half a cent. Money here is a double, as everywhere else in this project, so
/// "is there anything left over" is asked with a tolerance rather than against
/// an exact zero.
const double _cent = 0.005;

/// Lines whose item cannot be resolved: never matched, or matched to an item
/// that has since been deleted from the catalogue.
const String uncategorisedLabel = 'Uncategorised';

/// The part of the month's spend that no line accounts for.
const String notItemisedLabel = 'Not itemised';

const String unknownShopLabel = 'Unknown shop';

/// Whoever paid without having a `users` document.
const String unknownMemberLabel = 'Unknown member';

/// One labelled amount in a report section.
final class ReportRow extends Equatable {
  const ReportRow({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  List<Object?> get props => [label, amount];
}

/// What one member paid this month, against what an equal share would be.
final class MemberSpend extends Equatable {
  const MemberSpend({
    required this.memberId,
    required this.displayName,
    required this.paid,
    required this.share,
    required this.hasShare,
  });

  final String memberId;
  final String displayName;
  final double paid;

  /// Zero when [hasShare] is false.
  final double share;

  /// Whether [share] and [difference] mean anything.
  ///
  /// False for the row that collects payers with no `users` document. What
  /// they paid is part of the month, and therefore part of everyone else's
  /// share, but they are not themselves someone the share is split across.
  final bool hasShare;

  /// Positive when this member paid more than their share of the month.
  double get difference => paid - share;

  /// Whether what they paid and their share are the same to the cent. Kept
  /// here rather than in the widget, so the tolerance money is compared with
  /// lives in one place.
  bool get matchesShare => difference.abs() < _cent;

  @override
  List<Object?> get props => [memberId, displayName, paid, share, hasShare];
}

/// One month of spending, already grouped for the screen.
final class SpendingReport extends Equatable {
  const SpendingReport({
    required this.month,
    required this.monthTotal,
    required this.previousMonthTotal,
    required this.purchaseCount,
    required this.memberCount,
    required this.byPerson,
    required this.byCategory,
    required this.byShop,
  });

  /// The first instant of the month this report covers.
  final DateTime month;

  /// The sum of every `purchase.total`. The receipt total is authoritative and
  /// is never re-derived from the lines.
  final double monthTotal;

  final double previousMonthTotal;

  final int purchaseCount;

  /// The divisor behind every [MemberSpend.share]. Named on screen, because a
  /// `users` document appears only once a member has signed in, so the figure
  /// is only legible when the household size behind it is visible.
  final int memberCount;

  final List<MemberSpend> byPerson;
  final List<ReportRow> byCategory;
  final List<ReportRow> byShop;

  /// Nothing was recorded this month. The month frame still renders, so the
  /// month can be changed.
  bool get isEmpty => purchaseCount == 0;

  /// Positive when this month cost more than the one before it.
  double get monthOverMonthChange => monthTotal - previousMonthTotal;

  /// The change as a fraction of the previous month, or null when there is
  /// nothing to compare against and a percentage would be an infinity.
  double? get monthOverMonthFraction => previousMonthTotal.abs() < _cent
      ? null
      : monthOverMonthChange / previousMonthTotal;

  @override
  List<Object?> get props => [
    month,
    monthTotal,
    previousMonthTotal,
    purchaseCount,
    memberCount,
    byPerson,
    byCategory,
    byShop,
  ];
}

/// Groups one month of spending.
///
/// [purchases] spans the previous month start to the next month start, which
/// is one query rather than two, and is partitioned here.
SpendingReport buildSpendingReport({
  required DateTime month,
  required List<Purchase> purchases,
  required List<Item> items,
  required List<HouseholdMember> members,
}) {
  final selected = monthStart(month);
  final previous = previousMonth(selected);

  final inMonth = <Purchase>[];
  var previousTotal = 0.0;

  for (final purchase in purchases) {
    final bucket = monthStart(purchase.date);
    if (bucket == selected) {
      inMonth.add(purchase);
    } else if (bucket == previous) {
      previousTotal += purchase.total;
    }
  }

  final monthTotal = inMonth.fold<double>(
    0,
    (sum, purchase) => sum + purchase.total,
  );

  return SpendingReport(
    month: selected,
    monthTotal: monthTotal,
    previousMonthTotal: previousTotal,
    purchaseCount: inMonth.length,
    memberCount: members.length,
    byPerson: _byPerson(inMonth, members, monthTotal),
    byCategory: _byCategory(inMonth, items, monthTotal),
    byShop: _byShop(inMonth),
  );
}

List<MemberSpend> _byPerson(
  List<Purchase> purchases,
  List<HouseholdMember> members,
  double monthTotal,
) {
  final paid = <String, double>{};
  for (final purchase in purchases) {
    paid.update(
      purchase.paidByUserId,
      (amount) => amount + purchase.total,
      ifAbsent: () => purchase.total,
    );
  }

  // Guarded: a `users` document appears only once a member has signed in, and
  // an empty household would put a NaN on screen.
  final share = members.isEmpty ? 0.0 : monthTotal / members.length;

  // `remove` as it goes, so whatever is left over paid for something without
  // being a member.
  final rows = [
    for (final member in members)
      MemberSpend(
        memberId: member.id,
        displayName: member.displayName,
        paid: paid.remove(member.id) ?? 0,
        share: share,
        hasShare: true,
      ),
  ];

  final strays = paid.values.fold<double>(0, (sum, amount) => sum + amount);
  if (strays.abs() >= _cent) {
    // One row rather than one per id: a raw uid is not a name, and what
    // matters is that the money is not missing from the section.
    rows.add(
      MemberSpend(
        memberId: '',
        displayName: unknownMemberLabel,
        paid: strays,
        share: 0,
        hasShare: false,
      ),
    );
  }

  return rows;
}

List<ReportRow> _byCategory(
  List<Purchase> purchases,
  List<Item> items,
  double monthTotal,
) {
  final categoryByItemId = {for (final item in items) item.id: item.category};

  final totals = <String, double>{};
  var itemised = 0.0;

  for (final purchase in purchases) {
    for (final line in purchase.lines) {
      itemised += line.lineTotal;
      final stored = normalizeCategory(categoryByItemId[line.itemId] ?? '');
      final label = stored.isEmpty ? uncategorisedLabel : categoryLabel(stored);
      totals.update(
        label,
        (amount) => amount + line.lineTotal,
        ifAbsent: () => line.lineTotal,
      );
    }
  }

  // Held back so the two rows that say "we do not know" read together at the
  // bottom rather than sorting into the middle on amount.
  final uncategorised = totals.remove(uncategorisedLabel);

  final rows = [
    for (final entry in totals.entries)
      ReportRow(label: entry.key, amount: entry.value),
  ]..sort(_byAmountThenLabel);

  if (uncategorised != null) {
    rows.add(ReportRow(label: uncategorisedLabel, amount: uncategorised));
  }

  // The lines are optional and a priced line may still be zero, so a category
  // breakdown built from them is routinely short of the receipt total. This
  // row closes the gap, so the section adds up to the month.
  final remainder = monthTotal - itemised;
  if (remainder >= _cent) {
    rows.add(ReportRow(label: notItemisedLabel, amount: remainder));
  }

  return rows;
}

List<ReportRow> _byShop(List<Purchase> purchases) {
  // Keyed on the lowercase name and labelled with the first spelling seen, the
  // same technique the category picker uses, so `conad` and `Conad` are one
  // shop rather than two rows.
  final byKey = <String, ReportRow>{};

  for (final purchase in purchases) {
    final name = purchase.shopName.trim();
    final key = name.toLowerCase();
    final existing = byKey[key];
    byKey[key] = existing == null
        ? ReportRow(
            label: name.isEmpty ? unknownShopLabel : name,
            amount: purchase.total,
          )
        : ReportRow(
            label: existing.label,
            amount: existing.amount + purchase.total,
          );
  }

  return byKey.values.toList()..sort(_byAmountThenLabel);
}

/// Biggest first, then alphabetically, so the order is stable rather than
/// whatever the map happened to hold.
int _byAmountThenLabel(ReportRow a, ReportRow b) {
  final amount = b.amount.compareTo(a.amount);
  return amount != 0
      ? amount
      : a.label.toLowerCase().compareTo(b.label.toLowerCase());
}
