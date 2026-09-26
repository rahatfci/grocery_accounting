import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/form_controls.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';
import 'package:grocery_accounting/features/items/presentation/item_detail_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_history_page.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';
import 'package:grocery_accounting/features/items/presentation/stock_event_sheet.dart';
import 'package:grocery_accounting/features/members/presentation/household_cubit.dart';
import 'package:grocery_accounting/features/purchases/data/purchase_repository.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_cubit.dart';

import '../../auth/fake_auth_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';
import '../fake_item_repository.dart';

/// Two days after `testItem`'s baseline.
final _now = DateTime(2026, 9, 3, 10, 30);

class _Fakes {
  final items = FakeItemRepository()..initialEvents = const [];
  final purchases = FakePurchaseRepository()..initialItemPurchases = const [];
  final members = FakeMemberRepository()
    ..initialMembers = [
      testMember(displayName: 'Rahat'),
      testMember(id: 'u2', displayName: 'Giulia'),
    ];
  final list = FakeShoppingListRepository()..initialEntries = const [];
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _Fakes fakes, {
  String itemId = 'abc123',
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ItemRepository>.value(value: fakes.items),
        RepositoryProvider<PurchaseRepository>.value(value: fakes.purchases),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                ItemsCubit(fakes.items, fakes.purchases, clock: () => _now),
          ),
          BlocProvider(
            create: (_) => HouseholdCubit(fakes.members, currentUser: testUser),
          ),
          BlocProvider(
            create: (_) => ShoppingListCubit(
              fakes.list,
              fakes.items,
              currentUser: testUser,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ItemDetailPage(itemId: itemId, user: testUser),
        ),
      ),
    ),
  );
}

StockEventRecord _used(double quantity, DateTime date, {String? note}) =>
    StockEventRecord(
      id: 'e$quantity$date',
      date: date,
      event: StockEvent(
        itemId: 'abc123',
        type: StockEventType.consumed,
        quantity: quantity,
        unit: ItemUnit.kg,
        userId: 'u2',
        note: note,
      ),
    );

void main() {
  late _Fakes fakes;

  setUp(() => fakes = _Fakes());

  testWidgets('waits on a spinner until the stream reports', (tester) async {
    await _pumpDetail(tester, fakes);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Edit item'), findsNothing);
  });

  testWidgets('shows derived stock and the item facts', (tester) async {
    await _pumpDetail(tester, fakes);

    fakes.items.emitItemsToAll([
      testItem(
        name: 'Rice',
        dailyUsage: 0.25,
        lowThreshold: 2,
      ).copyWith(stockAtBaseline: 4),
    ]);
    await tester.pump();

    expect(find.text('Rice'), findsOneWidget);
    // Two days at 0.25 a day.
    expect(find.text('3.5 kg'), findsOneWidget);
    expect(find.text('0.25 kg'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(find.text('Pantry & Dry Goods'), findsOneWidget);
    expect(find.text('Staple · kg'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
    expect(find.text('Log use'), findsOneWidget);
    expect(find.text('Adjust'), findsOneWidget);
    expect(find.text('Recount'), findsOneWidget);
  });

  testWidgets('an item under its threshold says so, and when it runs out', (
    tester,
  ) async {
    await _pumpDetail(tester, fakes);

    fakes.items.emitItemsToAll([
      testItem(dailyUsage: 0.1, lowThreshold: 1).copyWith(stockAtBaseline: 0.5),
    ]);
    await tester.pump();

    expect(find.text('Running low'), findsOneWidget);
    expect(find.text('0.3 kg'), findsOneWidget);
    expect(find.text('Runs out around 06/09'), findsOneWidget);
  });

  testWidgets('a non-finite stored stock still renders and can be recounted', (
    tester,
  ) async {
    await _pumpDetail(tester, fakes);

    fakes.items.emitItemsToAll([
      testItem().copyWith(stockAtBaseline: double.nan),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Recount'), findsOneWidget);
  });

  testWidgets('a huge stored stock still renders', (tester) async {
    await _pumpDetail(tester, fakes);

    fakes.items.emitItemsToAll([testItem().copyWith(stockAtBaseline: 1e307)]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Recount'), findsOneWidget);
  });

  testWidgets('says so when the item is not a staple', (tester) async {
    await _pumpDetail(tester, fakes);

    fakes.items.emitItemsToAll([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 1),
    ]);
    await tester.pump();

    expect(find.text('Not a staple · kg'), findsOneWidget);
    expect(find.text('Not a staple'), findsOneWidget);
  });

  testWidgets('follows the stream as the stock changes', (tester) async {
    await _pumpDetail(tester, fakes);
    fakes.items.emitItemsToAll([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 1),
    ]);
    await tester.pump();

    fakes.items.emitItemsToAll([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 6),
    ]);
    await tester.pump();

    expect(find.text('6 kg'), findsOneWidget);
  });

  testWidgets('a failure shows the mapped message and a retry', (tester) async {
    await _pumpDetail(tester, fakes);

    fakes.items.emitError(const PermissionDenied());
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsWidgets);

    await tester.tap(find.text('Try again').first);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an item that has gone says so instead of closing', (
    tester,
  ) async {
    await _pumpDetail(tester, fakes);
    fakes.items.emitItemsToAll([testItem()]);
    await tester.pump();

    fakes.items.emitItemsToAll([testItem(id: 'other', name: 'Salt')]);
    await tester.pump();

    expect(find.text('This item is no longer in the pantry'), findsOneWidget);
    expect(find.byTooltip('Edit item'), findsNothing);
  });

  testWidgets('edit opens the form prefilled with the item', (tester) async {
    await _pumpDetail(tester, fakes);
    fakes.items.emitItemsToAll([testItem(id: 'abc123', name: 'Rice')]);
    await tester.pump();

    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();

    final form = tester.widget<ItemFormPage>(find.byType(ItemFormPage));
    expect(form.item?.id, 'abc123');
    expect(find.text('Edit item'), findsOneWidget);
  });

  for (final (button, type) in [
    ('Log use', StockEventType.consumed),
    ('Adjust', StockEventType.adjustment),
    ('Recount', StockEventType.recount),
  ]) {
    testWidgets('$button opens the stock sheet for that event', (tester) async {
      await _pumpDetail(tester, fakes);
      fakes.items.emitItemsToAll([testItem(name: 'Rice')]);
      await tester.pump();

      await tester.tap(find.text(button));
      await tester.pumpAndSettle();

      final sheet = tester.widget<StockEventSheet>(
        find.byType(StockEventSheet),
      );
      expect(sheet.type, type);
      expect(sheet.item.id, 'abc123');
      expect(sheet.user, testUser);
    });
  }

  testWidgets('a recorded event updates the stock behind the sheet', (
    tester,
  ) async {
    await _pumpDetail(tester, fakes);
    fakes.items.emitItemsToAll([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 1),
    ]);
    await tester.pump();

    await tester.tap(find.text('Recount'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Counted amount'),
        matching: find.byType(TextFormField),
      ),
      '5',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save recount'));
    await tester.pumpAndSettle();

    // The fake does not write, so the stream stands in for Firestore.
    fakes.items.emitItemsToAll([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 5),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(StockEventSheet), findsNothing);
    expect(find.text('5 kg'), findsWidgets);
    expect(fakes.items.recorded.single.event.quantity, 5);
  });

  testWidgets('the history explains the stock, newest first', (tester) async {
    fakes.items.initialItems = [testItem(name: 'Rice')];
    fakes.items.initialEvents = [
      _used(0.2, DateTime(2026, 9, 2, 20), note: 'pasta night'),
    ];
    fakes.purchases.initialItemPurchases = [
      testPurchase(
        shopName: 'Lidl',
        paidByUserId: testUser.uid,
        date: DateTime(2026, 9, 1),
        lines: [testLine(itemId: 'abc123', quantity: 1)],
      ),
    ];
    await _pumpDetail(tester, fakes);
    await tester.pumpAndSettle();

    expect(find.text('Logged use: pasta night'), findsOneWidget);
    expect(find.text('Giulia · 02/09/2026'), findsOneWidget);
    expect(find.text('−0.2 kg'), findsOneWidget);
    expect(find.text('Bought at Lidl'), findsOneWidget);
    expect(find.text('+1 kg'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('a long history opens in full from See all', (tester) async {
    fakes.items.initialItems = [testItem(name: 'Rice')];
    fakes.items.initialEvents = [
      for (var day = 1; day <= 6; day++) _used(0.1, DateTime(2026, 9, day, 9)),
    ];
    await _pumpDetail(tester, fakes);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemHistoryPage), findsOneWidget);
    expect(find.text('Logged use'), findsNWidgets(6));
  });

  testWidgets('adds the item to the shopping list, linked, just once', (
    tester,
  ) async {
    fakes.items.initialItems = [testItem(name: 'Rice')];
    await _pumpDetail(tester, fakes);
    await tester.pump();

    await tester.ensureVisible(find.text('Add to shopping list'));
    await tester.tap(find.text('Add to shopping list'));
    await tester.pump();

    expect(fakes.list.added.single.itemId, 'abc123');

    fakes.list.emitEntries([testEntry(text: 'Rice', itemId: 'abc123')]);
    await tester.pump();

    expect(find.text('On the shopping list'), findsOneWidget);
  });
}
