import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/presentation/item_list_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';

import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

Future<void> _pumpCatalogue(
  WidgetTester tester,
  FakeItemRepository repository,
  FakePurchaseRepository purchases,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => ItemsCubit(repository, purchases),
        child: const ItemListView(),
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

  testWidgets('a populated catalogue lists each item with category and unit', (
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
    expect(find.text('Pantry & Dry Goods - kg'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Dairy & Eggs - L'), findsOneWidget);
    // A member's own category shows the text they typed, not a lookup miss.
    expect(find.text('Baby things - kg'), findsOneWidget);
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

  testWidgets('the list stays readable on a wide window', (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(name: 'Rice')]);
    await tester.pump();

    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(560));
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

  testWidgets('tapping a row opens the form prefilled for editing', (
    tester,
  ) async {
    await _pumpCatalogue(tester, repository, purchases);
    repository.emitItems([testItem(id: 'abc123', name: 'Rice')]);
    await tester.pump();

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();

    final form = tester.widget<ItemFormPage>(find.byType(ItemFormPage));
    expect(form.item?.id, 'abc123');
    expect(find.text('Edit item'), findsOneWidget);
  });
}
