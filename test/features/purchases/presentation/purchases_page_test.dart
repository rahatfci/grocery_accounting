import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_labels.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_detail_page.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchases_page.dart';
import 'package:grocery_accounting/features/reports/logic/report_month.dart';
import 'package:grocery_accounting/features/reports/presentation/spending_tab.dart';

import '../../members/fake_member_repository.dart';
import '../../shell/shell_harness.dart';
import '../fake_purchase_repository.dart';

Finder _onPage(String text) =>
    find.descendant(of: find.byType(PurchasesPage), matching: find.text(text));

void main() {
  // The Spending tab follows the real clock, so the purchases do too.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  // Another day of this month: the first, unless that is today.
  final otherDay = DateTime(now.year, now.month, now.day > 1 ? 1 : 2, 9);

  late ShellFakes fakes;

  setUp(() {
    fakes = ShellFakes();
    fakes.members.initialMembers = [
      testMember(),
      testMember(id: 'zoe', displayName: 'Zoe'),
    ];
  });

  Future<void> openPurchases(WidgetTester tester) async {
    usePhone(tester, size: const Size(390, 2400));
    await pumpShell(tester, fakes);
    await openTab(tester, 'Spending');
    await tester.pumpAndSettle();
    final seeAll = find.text('See all');
    if (seeAll.evaluate().isEmpty) {
      return;
    }
    await tester.scrollUntilVisible(
      seeAll,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SpendingTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(seeAll);
    await tester.pumpAndSettle();
  }

  testWidgets('groups the month by day, newest first', (tester) async {
    fakes.purchases.initialPurchases = [
      testPurchase(id: 'old', date: otherDay, shopName: 'Lidl'),
      testPurchase(
        id: 'new',
        date: today,
        shopName: 'Conad City',
        paidByUserId: 'zoe',
        lines: [testLine(), testLine()],
      ),
    ];
    await openPurchases(tester);

    final todayHeading = _onPage(dayHeading(today, now: now));
    final otherHeading = _onPage(dayHeading(otherDay, now: now));
    expect(todayHeading, findsOneWidget);
    expect((tester.widget(todayHeading) as Text).data, startsWith('TODAY · '));
    expect(otherHeading, findsOneWidget);
    expect(_onPage('Zoe · 2 lines'), findsOneWidget);
    expect(_onPage('rahat · No lines'), findsOneWidget);
    // Today's group comes first when today is the later day.
    if (now.day > 1) {
      expect(
        tester.getTopLeft(todayHeading).dy,
        lessThan(tester.getTopLeft(otherHeading).dy),
      );
    }
  });

  testWidgets('moving the month here moves the tab behind it', (tester) async {
    fakes.purchases.initialPurchases = [testPurchase(date: today)];
    await openPurchases(tester);
    final lastMonth = previousMonth(DateTime(now.year, now.month));

    await tester.tap(find.byTooltip('Previous month').last);
    await tester.pumpAndSettle();

    expect(_onPage(monthLabel(lastMonth)), findsOneWidget);
    expect(
      _onPage('Nothing was recorded in ${monthLabel(lastMonth)}.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SpendingTab),
        matching: find.text(monthLabel(lastMonth)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a row opens the purchase', (tester) async {
    final purchase = testPurchase(id: 'p1', date: today, shopName: 'Conad');
    fakes.purchases.initialPurchases = [purchase];
    fakes.purchases.purchasesById = {'p1': purchase};
    await openPurchases(tester);

    await tester.tap(_onPage('rahat · No lines'));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseDetailPage), findsOneWidget);
  });
}
