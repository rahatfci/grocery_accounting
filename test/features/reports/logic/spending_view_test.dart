import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/reports/logic/spending_report.dart';
import 'package:grocery_accounting/features/reports/logic/spending_view.dart';

/// The Italian currency format separates the amount from the symbol with a
/// non-breaking space, which is invisible in an expectation.
String _plain(String text) => text.replaceAll(' ', ' ');

SpendingReport _report({
  double total = 612.40,
  double previous = 566.90,
  int purchases = 14,
  int members = 5,
  List<MemberSpend> byPerson = const [],
}) => SpendingReport(
  month: DateTime(2026, 9),
  monthTotal: total,
  previousMonthTotal: previous,
  purchaseCount: purchases,
  memberCount: members,
  byPerson: byPerson,
  byCategory: const [],
  byShop: const [],
  purchases: const [],
);

MemberSpend _spend({
  double paid = 10,
  double share = 10,
  bool hasShare = true,
}) => MemberSpend(
  memberId: 'm',
  displayName: 'Giulia',
  paid: paid,
  share: share,
  hasShare: hasShare,
);

void main() {
  group('monthChange', () {
    test('says how much more and by what share, against last month', () {
      final change = monthChange(_report(total: 612.40, previous: 566.90));

      expect(_plain(change?.label ?? ''), '+45,50 € · 8% vs August');
      expect(change?.trend, Trend.up);
    });

    test('a smaller month trends down', () {
      final change = monthChange(_report(total: 400, previous: 500));

      expect(_plain(change?.label ?? ''), '−100,00 € · 20% vs August');
      expect(change?.trend, Trend.down);
    });

    test('has no percentage when nothing was spent the month before', () {
      final change = monthChange(_report(total: 50, previous: 0));

      expect(_plain(change?.label ?? ''), '+50,00 € vs August');
    });

    test('an unchanged month is flat', () {
      expect(
        monthChange(_report(total: 50, previous: 50)),
        const MonthChange(label: 'Same as August', trend: Trend.flat),
      );
    });

    test('two empty months have nothing to compare', () {
      expect(monthChange(_report(total: 0, previous: 0)), isNull);
    });
  });

  test('purchaseCountLabel speaks of one in the singular', () {
    expect(purchaseCountLabel(1), '1 purchase');
    expect(purchaseCountLabel(14), '14 purchases');
    expect(purchaseCountLabel(0), '0 purchases');
  });

  group('equalShareNote', () {
    test('names the share and how many it is split across', () {
      expect(
        _plain(equalShareNote(_report(total: 612.40, members: 5)) ?? ''),
        'Equal share: 122,48 € each, across 5 members',
      );
      expect(
        _plain(equalShareNote(_report(total: 20, members: 1)) ?? ''),
        'Equal share: 20,00 € each, across 1 member',
      );
    });

    test('is absent with nobody to split it across', () {
      expect(equalShareNote(_report(members: 0)), isNull);
    });
  });

  test('barLevel is a fraction of the largest, and safe', () {
    expect(barLevel(50, 100), 0.5);
    expect(barLevel(150, 100), 1);
    expect(barLevel(10, 0), 0);
    expect(barLevel(double.nan, 100), 0);
  });

  test('percentOf rounds to a whole percentage', () {
    expect(percentOf(142.30, 612.40), 23);
    expect(percentOf(5, 0), 0);
  });

  test('balanceCaption says where a member stands', () {
    expect(balanceCaption(_spend(paid: 20, share: 10)), 'over share');
    expect(balanceCaption(_spend(paid: 5, share: 10)), 'under share');
    expect(balanceCaption(_spend(paid: 10, share: 10.001)), 'their share');
    expect(balanceCaption(_spend(hasShare: false)), 'not in the household');
  });

  test('largestPaid is what the biggest payer paid', () {
    expect(
      largestPaid(_report(byPerson: [_spend(paid: 20), _spend(paid: 188.2)])),
      188.2,
    );
    expect(largestPaid(_report()), 0);
  });
}
