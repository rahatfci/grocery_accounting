import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/presentation/item_detail_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';
import 'package:grocery_accounting/features/items/presentation/stock_event_sheet.dart';

import '../../auth/fake_auth_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

/// Two days after `testItem`'s baseline.
final _now = DateTime(2026, 9, 3, 10, 30);

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeItemRepository repository, {
  String itemId = 'abc123',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) =>
            ItemsCubit(repository, FakePurchaseRepository(), clock: () => _now),
        child: ItemDetailPage(itemId: itemId, user: testUser),
      ),
    ),
  );
}

void main() {
  late FakeItemRepository repository;

  setUp(() => repository = FakeItemRepository());

  testWidgets('waits on a spinner until the stream reports', (tester) async {
    await _pumpDetail(tester, repository);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Edit item'), findsNothing);
  });

  testWidgets('shows derived stock and the item facts', (tester) async {
    await _pumpDetail(tester, repository);

    repository.emitItems([
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
    expect(find.text('0.25 kg a day'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(find.text('Pantry & Dry Goods'), findsOneWidget);
    expect(find.text('Log use'), findsOneWidget);
    expect(find.text('Adjust'), findsOneWidget);
    expect(find.text('Recount'), findsOneWidget);
  });

  testWidgets('a non-finite stored stock still renders and can be recounted', (
    tester,
  ) async {
    await _pumpDetail(tester, repository);

    repository.emitItems([testItem().copyWith(stockAtBaseline: double.nan)]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Recount'), findsOneWidget);
  });

  testWidgets('a huge stored stock still renders', (tester) async {
    await _pumpDetail(tester, repository);

    repository.emitItems([testItem().copyWith(stockAtBaseline: 1e307)]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Recount'), findsOneWidget);
  });

  testWidgets('says so when the item is not a staple', (tester) async {
    await _pumpDetail(tester, repository);

    repository.emitItems([testItem(dailyUsage: 0)]);
    await tester.pump();

    expect(find.text('Not a staple'), findsOneWidget);
  });

  testWidgets('follows the stream as the stock changes', (tester) async {
    await _pumpDetail(tester, repository);
    repository.emitItems([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 1),
    ]);
    await tester.pump();

    repository.emitItems([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 6),
    ]);
    await tester.pump();

    expect(find.text('6 kg'), findsOneWidget);
  });

  testWidgets('a failure shows the mapped message and a retry', (tester) async {
    await _pumpDetail(tester, repository);

    repository.emitError(const PermissionDenied());
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(repository.watchCalls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an item that has gone says so instead of closing', (
    tester,
  ) async {
    await _pumpDetail(tester, repository);
    repository.emitItems([testItem()]);
    await tester.pump();

    repository.emitItems([testItem(id: 'other', name: 'Salt')]);
    await tester.pump();

    expect(
      find.text('This item is no longer in the catalogue'),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit item'), findsNothing);
    expect(find.byType(ItemDetailPage), findsOneWidget);
  });

  testWidgets('an emptied catalogue also reads as gone', (tester) async {
    await _pumpDetail(tester, repository);

    repository.emitItems(const []);
    await tester.pump();

    expect(
      find.text('This item is no longer in the catalogue'),
      findsOneWidget,
    );
  });

  testWidgets('edit opens the form prefilled with the item', (tester) async {
    await _pumpDetail(tester, repository);
    repository.emitItems([testItem(id: 'abc123', name: 'Rice')]);
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
      await _pumpDetail(tester, repository);
      repository.emitItems([testItem(name: 'Rice')]);
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
    await _pumpDetail(tester, repository);
    repository.emitItems([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 1),
    ]);
    await tester.pump();

    await tester.tap(find.text('Recount'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Counted amount'),
      '5',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // The fake does not write, so the stream stands in for Firestore.
    repository.emitItems([
      testItem(dailyUsage: 0).copyWith(stockAtBaseline: 5),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(StockEventSheet), findsNothing);
    expect(find.text('5 kg'), findsOneWidget);
    expect(repository.recorded.single.event.quantity, 5);
  });
}
