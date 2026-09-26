import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/account/presentation/account_page.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/presentation/pantry_tab.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_page.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../../shell/shell_harness.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';

/// An item whose stock is [stock] now, under a 1 kg threshold, and no staple,
/// so it stays where it is for the length of a test.
Item _low(String id, String name, double stock) => Item(
  id: id,
  name: name,
  unit: ItemUnit.kg,
  category: 'pantry',
  avgPieceWeight: null,
  dailyUsage: 0,
  lowThreshold: 1,
  stockAtBaseline: stock,
  baselineDate: DateTime.now().subtract(const Duration(days: 2)),
);

/// A route push is followed by a transition, and a review screen reading a
/// receipt keeps a progress bar moving, so settle a fixed time instead.
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Home's list, not the scrollable inside the list's add field.
Future<void> _scrollTo(WidgetTester tester, Finder target) => tester
    .scrollUntilVisible(target, 200, scrollable: find.byType(Scrollable).first);

void main() {
  late ShellFakes fakes;

  setUp(() {
    fakes = ShellFakes();
    fakes.members.initialMembers = [testMember(displayName: 'Rahat')];
  });

  testWidgets('greets the signed-in member by name', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    expect(find.text('Rahat'), findsOneWidget);
    expect(find.textContaining(RegExp('^Good ')), findsOneWidget);
  });

  testWidgets('the glance shows the month, the change and your balance', (
    tester,
  ) async {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1, 12);
    final lastMonth = DateTime(now.year, now.month - 1, 10, 12);
    fakes.members.initialMembers = [
      testMember(displayName: 'Rahat'),
      testMember(id: 'u2', displayName: 'Giulia'),
    ];
    fakes.purchases.initialPurchases = [
      testPurchase(id: 'a', total: 60, date: thisMonth),
      testPurchase(id: 'b', total: 40, paidByUserId: 'u2', date: thisMonth),
      testPurchase(id: 'c', total: 80, date: lastMonth),
    ];
    usePhone(tester);
    await pumpShell(tester, fakes);

    expect(find.textContaining(RegExp(r'^\w+ spend$')), findsOneWidget);
    expect(find.textContaining('100,00'), findsOneWidget);
    expect(find.textContaining('25% vs'), findsOneWidget);
    expect(find.textContaining('+10,00'), findsOneWidget);
    expect(find.textContaining('over your share'), findsOneWidget);
  });

  testWidgets('with nothing spent there is no glance above the scan hero', (
    tester,
  ) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    expect(find.textContaining(RegExp(r'^\w+ spend$')), findsNothing);
    expect(find.text('Scan a receipt'), findsOneWidget);
  });

  testWidgets('take photo opens the review on the camera', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    await tester.tap(find.text('Take photo'));
    await _pumpRoute(tester);

    expect(find.byType(RecordPurchasePage), findsOneWidget);
    expect(fakes.picker.sources, [ReceiptSource.camera]);
  });

  testWidgets('the hero offers every way in, including by hand', (
    tester,
  ) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    await tester.tap(find.text('Scan a receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Add a purchase'), findsOneWidget);

    await tester.tap(find.text('Enter manually').last);
    await _pumpRoute(tester);

    expect(find.byType(RecordPurchasePage), findsOneWidget);
    expect(fakes.picker.sources, isEmpty);
  });

  testWidgets('the gallery link picks from the gallery', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    await tester.tap(find.text('Choose from gallery'));
    await _pumpRoute(tester);

    expect(fakes.picker.sources, [ReceiptSource.gallery]);
  });

  testWidgets('an empty pantry offers adding a staple', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    expect(find.text('Your pantry fills itself'), findsOneWidget);
    await tester.ensureVisible(find.text('Add a staple'));
    await tester.tap(find.text('Add a staple'));
    await _pumpRoute(tester);

    expect(find.byType(ItemFormPage), findsOneWidget);
  });

  testWidgets('a stocked pantry has no first-run card', (tester) async {
    fakes.items.initialItems = [testItem()];
    usePhone(tester);
    await pumpShell(tester, fakes);

    expect(find.text('Your pantry fills itself'), findsNothing);
  });

  testWidgets('running low shows out and low, and says when nothing is', (
    tester,
  ) async {
    usePhone(tester);
    await pumpShell(tester, fakes);
    await _scrollTo(tester, find.text('Running low'));
    expect(find.text('Nothing is running low'), findsOneWidget);

    fakes.items.emitItemsToAll([
      _low('rice', 'Rice', 0.3),
      _low('eggs', 'Eggs', 0),
    ]);
    await tester.pump();

    expect(find.text('Out'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.textContaining('0.3 kg left · low below 1 kg'), findsOneWidget);
    expect(find.textContaining('Out since'), findsOneWidget);
  });

  testWidgets('a running low item goes on the list with one tap, linked', (
    tester,
  ) async {
    fakes.items.initialItems = [_low('rice', 'Rice', 0.3)];
    usePhone(tester);
    await pumpShell(tester, fakes);
    await _scrollTo(tester, find.byTooltip('Add Rice to the list'));

    await tester.tap(find.byTooltip('Add Rice to the list'));
    await tester.pump();

    final added = fakes.shoppingList.added.single;
    expect(added.text, 'Rice');
    expect(added.itemId, 'rice');
  });

  testWidgets('an item already on the list shows as on it', (tester) async {
    fakes.items.initialItems = [_low('rice', 'Rice', 0.3)];
    fakes.shoppingList.initialEntries = [testEntry(text: 'rice')];
    usePhone(tester);
    await pumpShell(tester, fakes);
    await _scrollTo(tester, find.text('Running low'));

    expect(find.byTooltip('Add Rice to the list'), findsNothing);
    // The row is tappable, so its parts are read out as one label.
    expect(
      find.bySemanticsLabel(RegExp('Rice is on the shopping list')),
      findsOneWidget,
    );
  });

  testWidgets('the list preview shows entries and adds inline', (tester) async {
    fakes.shoppingList.initialEntries = [
      testEntry(id: 'e1', text: 'Olive oil', addedByUserId: testUser.uid),
    ];
    usePhone(tester);
    await pumpShell(tester, fakes);
    await _scrollTo(tester, find.text('Olive oil'));

    expect(find.textContaining('Added by you'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Basil');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(fakes.shoppingList.added.single.text, 'Basil');
  });

  testWidgets('the running low action opens the pantry tab', (tester) async {
    fakes.items.initialItems = [_low('rice', 'Rice', 0.3)];
    usePhone(tester);
    await pumpShell(tester, fakes);
    await _scrollTo(tester, find.widgetWithText(TextButton, 'Pantry'));

    await tester.tap(find.widgetWithText(TextButton, 'Pantry'));
    await tester.pump();

    expect(find.byType(PantryTab), findsOneWidget);
  });

  testWidgets('the avatar opens Account', (tester) async {
    usePhone(tester);
    await pumpShell(tester, fakes);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsOneWidget);
  });

  testWidgets('Home lays out on a small phone without overflowing', (
    tester,
  ) async {
    fakes.items.initialItems = [_low('rice', 'Parmigiano Reggiano', 0.3)];
    usePhone(tester, size: const Size(320, 640));
    await pumpShell(tester, fakes);

    expect(tester.takeException(), isNull);
  });
}
