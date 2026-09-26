import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_detail_page.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchases_page.dart';
import 'package:grocery_accounting/features/reports/logic/report_month.dart';
import 'package:grocery_accounting/features/reports/presentation/spending_tab.dart';

import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../../shell/shell_harness.dart';

/// Money as the screen formats it, with the non-breaking space before the
/// symbol.
String _euro(String amount) => '$amount €';

/// A text on the Spending tab, where Home, kept alive behind it, may show
/// the same figure.
Finder _inTab(String text) =>
    find.descendant(of: find.byType(SpendingTab), matching: find.text(text));

void main() {
  // The tab follows the real clock, so the purchases do too.
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = previousMonth(thisMonth);
  DateTime day(int day) => DateTime(now.year, now.month, day, 10);

  late ShellFakes fakes;

  setUp(() {
    fakes = ShellFakes();
    fakes.members.initialMembers = [
      testMember(),
      testMember(id: 'zoe', displayName: 'Zoe'),
    ];
    fakes.items.initialItems = [testItem(id: 'rice', category: 'pantry')];
  });

  Future<void> openSpending(WidgetTester tester) async {
    usePhone(tester, size: const Size(390, 2400));
    await pumpShell(tester, fakes);
    await openTab(tester, 'Spending');
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the month against the last, and who paid', (tester) async {
    fakes.purchases.initialPurchases = [
      testPurchase(
        id: 'a',
        date: day(1),
        total: 60,
        lines: [testLine(itemId: 'rice', lineTotal: 40)],
      ),
      testPurchase(id: 'b', date: day(1), total: 20, paidByUserId: 'zoe'),
      testPurchase(
        id: 'old',
        date: DateTime(lastMonth.year, lastMonth.month, 5),
        total: 50,
      ),
    ];
    await openSpending(tester);

    expect(_inTab(monthLabel(thisMonth)), findsOneWidget);
    // The total, the month's comparison bar, and the one shop.
    expect(_inTab(_euro('80,00')), findsNWidgets(3));
    expect(
      find.text('+${_euro('30,00')} · 60% vs ${monthName(lastMonth)}'),
      findsOneWidget,
    );
    expect(find.text('2 purchases'), findsOneWidget);
    expect(
      find.text('Equal share: ${_euro('40,00')} each, across 2 members'),
      findsOneWidget,
    );
    expect(find.text('Paid ${_euro('60,00')}'), findsOneWidget);
    expect(find.text('+${_euro('20,00')}'), findsOneWidget);
    expect(find.text('over share'), findsOneWidget);
    expect(find.text('−${_euro('20,00')}'), findsOneWidget);
    expect(find.text('under share'), findsOneWidget);
  });

  testWidgets('breaks the month down by category and by shop', (tester) async {
    fakes.purchases.initialPurchases = [
      testPurchase(
        id: 'a',
        date: day(1),
        total: 80,
        shopName: 'Conad',
        lines: [testLine(itemId: 'rice', lineTotal: 20)],
      ),
      testPurchase(id: 'b', date: day(1), total: 20, shopName: 'Lidl'),
    ];
    await openSpending(tester);
    await scrollTo(tester, find.text('By shop'));

    expect(find.text('Pantry & Dry Goods'), findsOneWidget);
    expect(find.text('20%'), findsNWidgets(2));
    expect(find.text('Not itemised'), findsOneWidget);
    expect(find.text('80%'), findsNWidgets(2));
    expect(find.text('Conad'), findsWidgets);
    expect(find.text('Lidl'), findsWidgets);
  });

  testWidgets('lists the latest three purchases and opens them all', (
    tester,
  ) async {
    fakes.purchases.initialPurchases = [
      for (var index = 1; index <= 4; index++)
        testPurchase(
          id: 'p$index',
          date: day(1),
          shopName: 'Shop $index',
          source: index.isEven ? PurchaseSource.scanned : PurchaseSource.manual,
        ),
    ];
    await openSpending(tester);
    await scrollTo(tester, find.text('See all'));

    expect(find.text('Shop 1'), findsWidgets);
    expect(find.text('Shop 3'), findsWidgets);
    // The fourth is only in the shop breakdown, not in the purchase rows.
    expect(find.text('rahat · ${_dayOf(day(1))} · No lines'), findsNWidgets(3));

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(PurchasesPage), findsOneWidget);
    expect(find.text('rahat · No lines'), findsNWidgets(4));
    expect(find.text('Receipt'), findsNWidgets(2));
    expect(find.text('Manual'), findsNWidgets(2));
  });

  testWidgets('a purchase row opens the purchase', (tester) async {
    final purchase = testPurchase(id: 'p1', date: day(1), shopName: 'Conad');
    fakes.purchases.initialPurchases = [purchase];
    fakes.purchases.purchasesById = {'p1': purchase};
    await openSpending(tester);
    await scrollTo(tester, find.text('rahat · ${_dayOf(day(1))} · No lines'));

    await tester.tap(find.text('rahat · ${_dayOf(day(1))} · No lines'));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseDetailPage), findsOneWidget);
    expect(find.text('Paid by rahat'), findsOneWidget);
  });

  testWidgets('an empty month says so and has nothing to export', (
    tester,
  ) async {
    await openSpending(tester);

    expect(
      find.text(
        'Nothing recorded in ${monthName(thisMonth)}. Saved purchases show up '
        'here.',
      ),
      findsOneWidget,
    );
    expect(find.text('0 purchases'), findsOneWidget);

    await tester.tap(find.byTooltip('Export this month'));
    await tester.pump();
    expect(fakes.sharer.shared, isEmpty);
  });

  testWidgets('exports the month on screen', (tester) async {
    fakes.purchases.initialPurchases = [testPurchase(date: day(1))];
    await openSpending(tester);

    await tester.tap(find.byTooltip('Export this month'));
    await tester.pumpAndSettle();

    expect(fakes.sharer.shared, hasLength(1));
  });

  testWidgets('moves between months', (tester) async {
    await openSpending(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    expect(find.text(monthLabel(lastMonth)), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text(monthLabel(thisMonth)), findsOneWidget);
  });

  testWidgets('a failure offers a retry', (tester) async {
    fakes.purchases.initialPurchases = null;
    usePhone(tester, size: const Size(390, 1200));
    await pumpShell(tester, fakes);
    await openTab(tester, 'Spending');

    fakes.purchases.emitPurchasesErrorToAll(const PermissionDenied());
    await tester.pump();
    await tester.pump();

    expect(_inTab(const PermissionDenied().message), findsOneWidget);
    expect(_inTab('Try again'), findsOneWidget);
  });

  testWidgets('a wide window puts the breakdowns beside the total', (
    tester,
  ) async {
    fakes.purchases.initialPurchases = [testPurchase(date: day(1))];
    usePhone(tester, size: const Size(1400, 1200));
    await pumpShell(tester, fakes);
    await tester.tap(find.text('Spending'));
    await tester.pumpAndSettle();

    final total = tester.getTopLeft(find.text('Total spent'));
    final categories = tester.getTopLeft(find.text('By category'));
    expect(categories.dx, greaterThan(total.dx));
    expect(categories.dy, lessThan(total.dy + 200));
  });
}

String _dayOf(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
