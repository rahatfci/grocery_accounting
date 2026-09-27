import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_detail_page.dart';
import 'package:grocery_accounting/features/receipts/presentation/receipt_photo_page.dart';
import 'package:grocery_accounting/features/reports/presentation/spending_tab.dart';

import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../receipts/fake_receipts.dart';
import '../../shell/shell_harness.dart';
import '../fake_purchase_repository.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);

  late ShellFakes fakes;

  setUp(() {
    fakes = ShellFakes();
    fakes.members.initialMembers = [
      testMember(),
      testMember(id: 'zoe', displayName: 'Zoe'),
    ];
    fakes.items.initialItems = [testItem(id: 'rice', name: 'Rice')];
  });

  /// Opens [purchase] the way a member does: from the Spending tab.
  Future<void> openDetail(WidgetTester tester, Purchase purchase) async {
    fakes.purchases.initialPurchases = [purchase];
    usePhone(tester, size: const Size(390, 2400));
    await pumpShell(tester, fakes);
    await openTab(tester, 'Spending');
    await tester.pumpAndSettle();
    final row = find.descendant(
      of: find.byType(SpendingTab),
      matching: find.textContaining(' · '),
    );
    await tester.scrollUntilVisible(
      row.last,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SpendingTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(row.last);
    await tester.pumpAndSettle();
  }

  final scanned = testPurchase(
    id: 'p1',
    date: today,
    shopName: 'Conad City',
    total: 40.8,
    paidByUserId: 'zoe',
    source: PurchaseSource.scanned,
    receiptImagePath: 'receipts/p1',
    lines: [
      testLine(itemId: 'rice', rawText: 'RISO ARBORIO 1KG', lineTotal: 2.49),
      testLine(
        itemId: null,
        rawText: 'POMODORI PELATI 400G',
        quantity: 2,
        unit: ItemUnit.pcs,
        lineTotal: 1.78,
      ),
    ],
  );

  testWidgets('shows where, when, how much and who paid', (tester) async {
    fakes.purchases.purchasesById = {'p1': scanned};
    fakes.store.photos['p1'] = testPhoto().bytes;
    await openDetail(tester, scanned);

    expect(find.byType(PurchaseDetailPage), findsOneWidget);
    expect(find.text('Conad City'), findsOneWidget);
    expect(find.text('Scanned'), findsOneWidget);
    expect(find.text('40,80 €'), findsOneWidget);
    expect(find.text('Paid by Zoe'), findsOneWidget);
    expect(
      find.text('Tap the photo to zoom. Kept in the household receipt bucket.'),
      findsOneWidget,
    );
  });

  testWidgets('lists the spend-only lines first', (tester) async {
    fakes.purchases.purchasesById = {'p1': scanned};
    await openDetail(tester, scanned);

    expect(find.text('Spend only · 2 pcs'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('1 kg · RISO ARBORIO 1KG'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('POMODORI PELATI 400G')).dy,
      lessThan(tester.getTopLeft(find.text('Rice')).dy),
    );
  });

  testWidgets('the photo opens full size', (tester) async {
    fakes.purchases.purchasesById = {'p1': scanned};
    fakes.store.photos['p1'] = testPhoto().bytes;
    await openDetail(tester, scanned);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Receipt photo')));
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptPhotoPage), findsOneWidget);
    expect(find.byTooltip('Remove photo'), findsNothing);
  });

  testWidgets('a photo that cannot load says why and tries again', (
    tester,
  ) async {
    fakes.purchases.purchasesById = {'p1': scanned};
    fakes.store.readFailure = const ConnectionUnavailable();
    await openDetail(tester, scanned);

    expect(find.text(const ConnectionUnavailable().message), findsOneWidget);

    fakes.store.photos['p1'] = testPhoto().bytes;
    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(fakes.store.reads, ['p1', 'p1']);
    expect(find.bySemanticsLabel(RegExp(r'^Receipt photo')), findsOneWidget);
  });

  testWidgets('a manual purchase without a photo has neither', (tester) async {
    final manual = testPurchase(id: 'p1', date: today);
    fakes.purchases.purchasesById = {'p1': manual};
    await openDetail(tester, manual);

    expect(find.text('Manual'), findsWidgets);
    expect(find.textContaining('Tap the photo'), findsNothing);
    expect(find.text('Only the spend was recorded.'), findsOneWidget);
  });

  testWidgets('a purchase that is gone says so', (tester) async {
    final gone = testPurchase(id: 'p1', date: today);
    await openDetail(tester, gone);

    expect(find.text('This purchase is no longer recorded.'), findsOneWidget);
  });
}
