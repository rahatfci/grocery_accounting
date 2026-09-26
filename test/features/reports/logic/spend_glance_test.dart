import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/reports/logic/spend_glance.dart';
import 'package:grocery_accounting/features/reports/logic/spending_report.dart';

import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';

void main() {
  final september = DateTime(2026, 9);

  SpendingReport report(
    List<({String payer, double total, int month})> spend,
  ) => buildSpendingReport(
    month: september,
    purchases: [
      for (final (index, purchase) in spend.indexed)
        testPurchase(
          id: 'p$index',
          paidByUserId: purchase.payer,
          total: purchase.total,
          date: DateTime(2026, purchase.month, 10),
        ),
    ],
    items: const [],
    members: [
      testMember(id: 'me', displayName: 'Rahat'),
      testMember(id: 'them', displayName: 'Giulia'),
    ],
  );

  test('carries the total and the change on the month before', () {
    final glance = spendGlanceFor(
      report([
        (payer: 'me', total: 60, month: 9),
        (payer: 'them', total: 40, month: 9),
        (payer: 'them', total: 80, month: 8),
      ]),
      'me',
    );

    expect(glance.total, 100);
    expect(glance.change, 20);
    expect(glance.changeFraction, closeTo(0.25, 1e-9));
    expect(glance.hasSpending, isTrue);
  });

  test('carries the member against their share', () {
    final glance = spendGlanceFor(
      report([
        (payer: 'me', total: 60, month: 9),
        (payer: 'them', total: 40, month: 9),
      ]),
      'me',
    );

    expect(glance.balance?.paid, 60);
    expect(glance.balance?.difference, 10);
  });

  test('has no balance for someone outside the household list', () {
    final glance = spendGlanceFor(
      report([(payer: 'me', total: 60, month: 9)]),
      'stranger',
    );

    expect(glance.balance, isNull);
  });

  test('has nothing to show before the first purchase', () {
    final glance = spendGlanceFor(report(const []), 'me');

    expect(glance.hasSpending, isFalse);
    expect(glance.changeFraction, isNull);
  });

  test('still shows a month that fell to nothing', () {
    final glance = spendGlanceFor(
      report([(payer: 'me', total: 30, month: 8)]),
      'me',
    );

    expect(glance.hasSpending, isTrue);
    expect(glance.change, -30);
  });
}
