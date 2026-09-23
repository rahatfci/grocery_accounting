import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/widgets/failure_message.dart';
import 'package:grocery_accounting/features/purchases/logic/money.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/reports/presentation/reports_cubit.dart';
import 'package:grocery_accounting/features/reports/presentation/reports_page.dart';

import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';

void main() {
  /// A fixed clock, so the current month is September 2026 in every test.
  final now = DateTime(2026, 9, 22, 18, 30);

  late FakePurchaseRepository purchases;
  late FakeItemRepository items;
  late FakeMemberRepository members;

  setUp(() {
    purchases = FakePurchaseRepository();
    items = FakeItemRepository();
    members = FakeMemberRepository();
  });

  Future<void> pumpReports(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ReportsCubit(
            purchases: purchases,
            items: items,
            members: members,
            now: () => now,
          ),
          child: const ReportsView(),
        ),
      ),
    );
  }

  /// Reports everything the screen needs, so a test can get to a rendered
  /// month in one line.
  Future<void> reportAll(
    WidgetTester tester, {
    List<Purchase> window = const [],
  }) async {
    purchases.emitPurchases(window);
    items.emitItems([testItem()]);
    members.emitMembers([testMember()]);
    await tester.pump();
  }

  testWidgets('waits on a spinner until the month has loaded', (tester) async {
    await pumpReports(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('names the month it opened on', (tester) async {
    await pumpReports(tester);

    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('the month bar is up before the month has loaded', (
    tester,
  ) async {
    await pumpReports(tester);

    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
  });

  testWidgets('the next month cannot be reached from the current one', (
    tester,
  ) async {
    await pumpReports(tester);
    await reportAll(tester);

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('the previous month can be reached and names itself', (
    tester,
  ) async {
    await pumpReports(tester);
    await reportAll(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the next month is reachable once it is behind us', (
    tester,
  ) async {
    await pumpReports(tester);
    await reportAll(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();

    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNotNull);
  });

  testWidgets('a month with nothing in it says so, at zero', (tester) async {
    await pumpReports(tester);
    await reportAll(tester);

    expect(find.text('Nothing recorded this month'), findsOneWidget);
    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text(formatEuro(0)), findsOneWidget);
  });

  testWidgets('a month with spending in it shows the total', (tester) async {
    await pumpReports(tester);
    await reportAll(tester, window: [testPurchase(total: 42.5)]);

    // Scoped to the total card: the same amount also appears in the person
    // and shop sections, which is correct rather than a duplicate.
    expect(
      find.descendant(
        of: find.widgetWithText(Card, 'Total spent'),
        matching: find.text(formatEuro(42.5)),
      ),
      findsOneWidget,
    );
    expect(find.text('Nothing recorded this month'), findsNothing);
  });

  testWidgets('a failure shows the mapped message and a retry', (tester) async {
    await pumpReports(tester);

    purchases.emitPurchasesError(const PermissionDenied());
    await tester.pump();

    expect(find.byType(FailureMessage), findsOneWidget);
    expect(find.text('You do not have access to this data'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('a failed month can still be navigated away from', (
    tester,
  ) async {
    await pumpReports(tester);

    purchases.emitPurchasesError(const PermissionDenied());
    await tester.pump();

    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.byType(FailureMessage), findsNothing);
  });

  testWidgets('retrying subscribes again', (tester) async {
    await pumpReports(tester);

    purchases.emitPurchasesError(const PermissionDenied());
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pump();

    expect(purchases.windows.length, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  /// A month with something in every section, so one setup serves the lot.
  Future<void> reportAFullMonth(WidgetTester tester) async {
    purchases.emitPurchases([
      testPurchase(
        id: 'a',
        shopName: 'Conad',
        total: 60,
        paidByUserId: 'one',
        lines: [testLine(itemId: 'i1', lineTotal: 25)],
      ),
      testPurchase(
        id: 'b',
        shopName: 'Lidl',
        total: 40,
        paidByUserId: 'ghost',
        lines: const [],
      ),
      testPurchase(
        id: 'august',
        date: DateTime(2026, 8, 12),
        total: 80,
        paidByUserId: 'one',
      ),
    ]);
    items.emitItems([testItem(id: 'i1', category: 'produce')]);
    members.emitMembers([
      testMember(id: 'one', displayName: 'rahat'),
      testMember(id: 'two', displayName: 'sara'),
    ]);
    await tester.pump();
  }

  group('the sections', () {
    testWidgets('every section is on the screen', (tester) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.text('By person'), findsOneWidget);
      expect(find.text('By category'), findsOneWidget);
      expect(find.text('By shop'), findsOneWidget);
      expect(find.text('Compared with August 2026'), findsOneWidget);
    });

    testWidgets('the equal share names the divisor behind it', (tester) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(
        find.text('Equal share across 2 members: ${formatEuro(50)}'),
        findsOneWidget,
      );
    });

    testWidgets('a member who paid more than their share says so', (
      tester,
    ) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.text('rahat'), findsOneWidget);
      expect(find.text('${formatEuro(10)} over their share'), findsOneWidget);
    });

    testWidgets('a member who paid nothing is under their share', (
      tester,
    ) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.text('sara'), findsOneWidget);
      expect(find.text('${formatEuro(50)} under their share'), findsOneWidget);
    });

    testWidgets('a payer who is not a member has no share', (tester) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.text('Unknown member'), findsOneWidget);
      expect(find.text('Not in the household list'), findsOneWidget);
    });

    testWidgets('categories carry the part no line accounts for', (
      tester,
    ) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.text('Produce'), findsOneWidget);
      expect(find.text('Not itemised'), findsOneWidget);
      expect(find.text(formatEuro(75)), findsOneWidget);
    });

    testWidgets('shops are listed biggest first', (tester) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .toList();
      expect(labels.indexOf('Conad'), lessThan(labels.indexOf('Lidl')));
    });

    testWidgets('the comparison reports the change and the percentage', (
      tester,
    ) async {
      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.text('Change'), findsOneWidget);
      expect(find.text('+${formatEuro(20)}'), findsOneWidget);
      expect(find.text('+25% on the month before'), findsOneWidget);
    });

    testWidgets('a month with nothing before it has no percentage', (
      tester,
    ) async {
      await pumpReports(tester);
      await reportAll(tester, window: [testPurchase(total: 30)]);

      expect(
        find.text('Nothing was spent that month, so there is no percentage.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty month shows no sections at all', (tester) async {
      await pumpReports(tester);
      await reportAll(tester);

      expect(find.text('By person'), findsNothing);
      expect(find.text('By shop'), findsNothing);
    });
  });

  group('the layout', () {
    testWidgets('a phone reads in one column', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.byKey(oneColumnKey), findsOneWidget);
      expect(find.byKey(twoColumnKey), findsNothing);
      expect(find.text('By category'), findsOneWidget);
    });

    testWidgets('a wide window uses two columns', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpReports(tester);
      await reportAFullMonth(tester);

      expect(find.byKey(twoColumnKey), findsOneWidget);
      expect(find.byKey(oneColumnKey), findsNothing);
      expect(find.text('By person'), findsOneWidget);
      expect(find.text('By category'), findsOneWidget);
      expect(find.text('By shop'), findsOneWidget);
      expect(find.text('Compared with August 2026'), findsOneWidget);
    });
  });
}
