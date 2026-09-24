import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/presentation/item_detail_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_list_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';

import '../../auth/fake_auth_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

/// Two days after `testItem`'s baseline, so a staple has visibly run down.
final _now = DateTime(2026, 9, 3, 10, 30);

Future<void> _pumpCatalogue(
  WidgetTester tester,
  FakeItemRepository repository,
  FakePurchaseRepository purchases,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => ItemsCubit(repository, purchases, clock: () => _now),
        child: const ItemListView(user: testUser),
      ),
    ),
  );
}

void main() {
  late FakeItemRepository repository;
  late FakePurchaseRepository purchases;

  setUp(() {
    repository = FakeItemRepository();
    purchases = FakePurchaseRepository();
  });

  testWidgets('waits on a spinner until the stream reports', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty catalogue explains itself and offers the add action', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);

    repository.emitItems(const []);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No items yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add item'), findsOneWidget);
  });

  testWidgets('a failure shows the mapped message and a retry', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);

    repository.emitError(const PermissionDenied());
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('the raw Firestore code never reaches the screen', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);

    repository.emitError(const PermissionDenied());
    await tester.pump();

    expect(find.textContaining('permission-denied'), findsNothing);
  });

  testWidgets('retry subscribes again and shows what arrives', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitError(const ConnectionUnavailable());
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.watchCalls, 2);

    repository.emitItems([testItem(name: 'Rice')]);
    await tester.pump();

    expect(find.text('Rice'), findsOneWidget);
  });

  testWidgets('a populated catalogue lists each item with its category', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);

    repository.emitItems([
      testItem(id: 'a', name: 'Rice', category: 'pantry'),
      testItem(id: 'b', name: 'Milk', category: 'dairy', unit: ItemUnit.l),
      testItem(id: 'c', name: 'Nappies', category: 'Baby things'),
    ]);
    await tester.pump();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Pantry & Dry Goods'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Dairy & Eggs'), findsOneWidget);
    // A member's own category shows the text they typed, not a lookup miss.
    expect(find.text('Baby things'), findsOneWidget);
  });

  testWidgets('each row shows current stock derived from its baseline', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);

    repository.emitItems([
      testItem(
        id: 'a',
        name: 'Rice',
        dailyUsage: 0.5,
      ).copyWith(stockAtBaseline: 4),
      testItem(
        id: 'b',
        name: 'Salt',
        dailyUsage: 0,
      ).copyWith(stockAtBaseline: 1),
      testItem(
        id: 'c',
        name: 'Pasta',
        dailyUsage: 1,
      ).copyWith(stockAtBaseline: 1),
    ]);
    await tester.pump();

    // Two days at 0.5 a day.
    expect(find.text('3 kg'), findsOneWidget);
    // Not a staple, so it has not moved.
    expect(find.text('1 kg'), findsOneWidget);
    // Past empty reads as zero, not as a negative.
    expect(find.text('0 kg'), findsOneWidget);
  });

  testWidgets('a long name truncates rather than overflowing', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);

    repository.emitItems([
      testItem(name: 'Extra virgin cold pressed olive oil in the large tin'),
    ]);
    await tester.pump();

    final title = tester.widget<Text>(
      find.text('Extra virgin cold pressed olive oil in the large tin'),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a very wide window keeps the table readable', (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(name: 'Rice')]);
    await tester.pump();

    expect(find.text('Daily use'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ListView)).width,
      lessThanOrEqualTo(1100),
    );
  });

  group('by width', () {
    void setWidth(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    // Stocked 3 kg at the baseline, a quarter kilo a day, two days on: 2.5 kg,
    // above its 2 kg threshold. Beans are a non-staple under their threshold.
    final rice = testItem(
      id: 'rice',
      name: 'Rice',
    ).copyWith(stockAtBaseline: 3);
    final beans = testItem(
      id: 'beans',
      name: 'Borlotti beans in a long, descriptive supermarket name',
      category: 'pantry',
      dailyUsage: 0,
      lowThreshold: 4,
    ).copyWith(stockAtBaseline: 1);

    testWidgets('a phone keeps the list', (tester) async {
      setWidth(tester, 400);
      await _pumpCatalogue(tester, repository, purchases);
      repository.emitItems([rice]);
      await tester.pump();

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Daily use'), findsNothing);
    });

    testWidgets('a wide screen shows every column as a table', (tester) async {
      setWidth(tester, 1000);
      await _pumpCatalogue(tester, repository, purchases);
      repository.emitItems([rice, beans]);
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
      for (final header in [
        'Name',
        'Category',
        'Stock',
        'Daily use',
        'Low below',
      ]) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('2.5 kg'), findsOneWidget);
      expect(find.text('0.25 kg/day'), findsOneWidget);
      expect(find.text('2 kg'), findsOneWidget);
      // A non-staple has no daily use.
      expect(find.text('-'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a stock under its threshold is marked', (tester) async {
      setWidth(tester, 1000);
      await _pumpCatalogue(tester, repository, purchases);
      repository.emitItems([rice, beans]);
      await tester.pump();

      final error = Theme.of(
        tester.element(find.text('Rice')),
      ).colorScheme.error;
      expect(tester.widget<Text>(find.text('1 kg')).style?.color, error);
      expect(tester.widget<Text>(find.text('2.5 kg')).style?.color, isNull);
    });

    testWidgets('a long name is cut short, not overflowing', (tester) async {
      setWidth(tester, 760);
      await _pumpCatalogue(tester, repository, purchases);
      repository.emitItems([beans]);
      await tester.pump();

      final name = tester.widget<Text>(find.textContaining('Borlotti'));
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a row opens the item', (tester) async {
      setWidth(tester, 1000);
      await _pumpCatalogue(tester, repository, purchases);
      repository.emitItems([rice]);
      await tester.pump();

      await tester.tap(find.text('Rice'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ItemDetailPage), findsOneWidget);
    });
  });

  testWidgets('the add action opens the form', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(name: 'Rice')]);
    await tester.pump();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsOneWidget);
  });

  testWidgets('the empty state opens the same form', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems(const []);
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsOneWidget);
  });

  testWidgets('the form is offered the categories already in use', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(name: 'Nappies', category: 'Baby things')]);
    await tester.pump();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add item'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ItemFormPage>(find.byType(ItemFormPage)).categories,
      contains('Baby things'),
    );
  });

  testWidgets('the form writes through the catalogue\'s own cubit', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems(const []);
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await tester.pumpAndSettle();

    // Handed the existing instance, so no second Firestore subscription.
    expect(repository.watchCalls, 1);
  });

  testWidgets('the add action is reachable from a populated catalogue', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(name: 'Rice')]);
    await tester.pump();

    expect(
      find.widgetWithText(FloatingActionButton, 'Add item'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row opens that item\'s detail screen', (tester) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(id: 'abc123', name: 'Rice')]);
    await tester.pump();

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();

    final detail = tester.widget<ItemDetailPage>(find.byType(ItemDetailPage));
    expect(detail.itemId, 'abc123');
    expect(detail.user, testUser);
    // On the catalogue's own cubit, not a second subscription.
    expect(repository.watchCalls, 1);
  });
}
