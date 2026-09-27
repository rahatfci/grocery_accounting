import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/form_controls.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_category.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';

import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

Future<void> _pumpForm(
  WidgetTester tester,
  FakeItemRepository repository,
  FakePurchaseRepository purchases, {
  List<Item> existing = const [],
  Item? item,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider(
        create: (_) => ItemsCubit(repository, purchases),
        child: ItemFormPage(
          categories: availableCategories([...existing, ?item]),
          item: item,
        ),
      ),
    ),
  );
}

/// The text field under the label [label].
Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LabeledField, label),
  matching: find.byType(TextFormField),
);

Future<void> _chooseCategory(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoicePill, label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) =>
    tester.tap(find.widgetWithText(FilledButton, 'Save item'));

Future<void> _fillValidForm(
  WidgetTester tester, {
  String name = 'Rice',
  String lowThreshold = '2',
}) async {
  await tester.enterText(_field('Name'), name);
  await tester.enterText(_field('Low below'), lowThreshold);
  await _chooseCategory(tester, 'Pantry & Dry Goods');
}

void main() {
  late FakeItemRepository repository;
  late FakePurchaseRepository purchases;

  setUp(() {
    repository = FakeItemRepository();
    purchases = FakePurchaseRepository();
  });

  testWidgets('an empty submit reports every required field', (tester) async {
    await _pumpForm(tester, repository, purchases);

    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('daily usage starts at zero, the non-staple case', (
    tester,
  ) async {
    await _pumpForm(tester, repository, purchases);

    expect(
      tester.widget<TextFormField>(_field('Daily usage')).controller?.text,
      '0',
    );
  });

  testWidgets('the helpers name the unit the numbers are in', (tester) async {
    await _pumpForm(tester, repository, purchases);

    expect(find.text('kg a day'), findsOneWidget);

    await tester.tap(find.text('L'));
    await tester.pump();

    expect(find.text('L a day'), findsOneWidget);
    // Pieces only convert into a weight, so a litre item has no piece weight.
    expect(find.text('Average piece weight (optional)'), findsNothing);
  });

  testWidgets('a non-numeric amount is rejected', (tester) async {
    await _pumpForm(tester, repository, purchases);

    await tester.enterText(_field('Low below'), 'two');
    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Enter a valid number'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('a zero piece weight is rejected', (tester) async {
    await _pumpForm(tester, repository, purchases);

    await tester.enterText(_field('Average piece weight (optional)'), '0');
    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Must be greater than zero'), findsOneWidget);
  });

  testWidgets('a decimal comma is accepted, as the household writes it', (
    tester,
  ) async {
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester, lowThreshold: '1,5');

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.created.single.lowThreshold, 1.5);
  });

  testWidgets('a created item carries a zero baseline and the chosen fields', (
    tester,
  ) async {
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester, name: '  Rice  ');
    await tester.enterText(_field('Daily usage'), '0.25');
    await tester.tap(find.text('g'));
    await tester.pump();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    final created = repository.created.single;
    // The baseline pair makes the document a valid input to the stock formula
    // from the moment it exists. The server timestamp itself is the
    // repository's to write; see the DTO test.
    expect(created.stockAtBaseline, 0);
    expect(created.id, isEmpty, reason: 'an empty id is what makes it create');
    expect(created.name, 'Rice', reason: 'the name is trimmed');
    expect(created.category, 'pantry', reason: 'the key is stored, not label');
    expect(created.unit, ItemUnit.g);
    expect(created.dailyUsage, 0.25);
    expect(created.avgPieceWeight, isNull);
    expect(repository.updated, isEmpty);
  });

  testWidgets('a successful save closes the form', (tester) async {
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsNothing);
  });

  testWidgets('saving disables the form and shows progress', (tester) async {
    repository.writeGate = Completer<void>();
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Save item'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextFormField>(_field('Name')).enabled, isFalse);

    repository.writeGate?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a refused save shows the mapped message and stays open', (
    tester,
  ) async {
    repository.createResult = const Err(PermissionDenied());
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('You do not have access to this data'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(find.byType(ItemFormPage), findsOneWidget);
    expect(find.text('Save item'), findsOneWidget);
  });

  testWidgets('editing a field clears the previous failure', (tester) async {
    repository.createResult = const Err(PermissionDenied());
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    await tester.enterText(_field('Name'), 'Rice and beans');
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsNothing);
  });

  testWidgets('a write that never acknowledges still closes the form', (
    tester,
  ) async {
    // Offline, a queued write is durable but never acknowledged. The form must
    // not hang on it.
    repository.writeGate = Completer<void>();
    await _pumpForm(tester, repository, purchases);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsNothing);
    expect(repository.created, hasLength(1));

    repository.writeGate?.complete();
    await tester.pumpAndSettle();
  });

  group('the category chips', () {
    testWidgets('offer the built-ins and every category already in use', (
      tester,
    ) async {
      await _pumpForm(
        tester,
        repository,
        purchases,
        existing: [testItem(category: 'Baby things')],
      );

      expect(find.widgetWithText(ChoicePill, 'Produce'), findsOneWidget);
      expect(
        find.widgetWithText(ChoicePill, 'Household & Cleaning'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoicePill, 'Baby things'), findsOneWidget);
      expect(find.widgetWithText(ChoicePill, 'New category'), findsOneWidget);
    });

    testWidgets('a new category reveals a field and stores the text', (
      tester,
    ) async {
      await _pumpForm(tester, repository, purchases);
      await tester.enterText(_field('Name'), 'Nappies');
      await tester.enterText(_field('Low below'), '2');

      await _chooseCategory(tester, 'New category');
      await tester.enterText(_field('New category'), '  Baby   things ');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      // Trimmed and collapsed, so spacing cannot fork one category into two.
      expect(repository.created.single.category, 'Baby things');
    });

    testWidgets('an empty new category is rejected', (tester) async {
      await _pumpForm(tester, repository, purchases);
      await tester.enterText(_field('Name'), 'Nappies');
      await tester.enterText(_field('Low below'), '2');
      await _chooseCategory(tester, 'New category');

      await tester.enterText(_field('New category'), '   ');
      await _tapSave(tester);
      await tester.pump();

      expect(find.text('Choose a category'), findsOneWidget);
      expect(repository.created, isEmpty);
    });

    testWidgets('a near-duplicate folds onto the category already in use', (
      tester,
    ) async {
      await _pumpForm(
        tester,
        repository,
        purchases,
        existing: [testItem(category: 'Baby things')],
      );
      await tester.enterText(_field('Name'), 'Nappies');
      await tester.enterText(_field('Low below'), '2');
      await _chooseCategory(tester, 'New category');

      await tester.enterText(_field('New category'), 'BABY THINGS');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.created.single.category, 'Baby things');
    });

    testWidgets('typing a built-in label selects the built-in key', (
      tester,
    ) async {
      await _pumpForm(tester, repository, purchases);
      await tester.enterText(_field('Name'), 'Milk');
      await tester.enterText(_field('Low below'), '2');
      await _chooseCategory(tester, 'New category');

      await tester.enterText(_field('New category'), 'dairy & eggs');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      // Stores the key, not the label, so relabelling stays a code change.
      expect(repository.created.single.category, 'dairy');
    });
  });

  group('editing an existing item', () {
    final existing = testItem(
      id: 'abc123',
      name: 'Rice',
      unit: ItemUnit.g,
      category: 'pantry',
      avgPieceWeight: 2,
      dailyUsage: 0.25,
      lowThreshold: 1.5,
    );

    testWidgets('the form opens prefilled from the item', (tester) async {
      await _pumpForm(tester, repository, purchases, item: existing);

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Rice'), findsOneWidget);
      // A whole number reads as 2, not 2.0.
      expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0.25'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1.5'), findsOneWidget);
      final pantry = tester.widget<ChoicePill>(
        find.widgetWithText(ChoicePill, 'Pantry & Dry Goods'),
      );
      expect(pantry.selected, isTrue);
    });

    testWidgets('saving updates rather than creating', (tester) async {
      await _pumpForm(tester, repository, purchases, item: existing);

      await tester.enterText(_field('Name'), 'Basmati rice');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.created, isEmpty);
      final updated = repository.updated.single;
      expect(updated.id, 'abc123', reason: 'the same document is written');
      expect(updated.name, 'Basmati rice');
      expect(updated.avgPieceWeight, 2);
    });

    testWidgets('an edit carries the baseline pair through untouched', (
      tester,
    ) async {
      await _pumpForm(tester, repository, purchases, item: existing);

      await tester.enterText(_field('Name'), 'Basmati rice');
      await _tapSave(tester);
      await tester.pumpAndSettle();

      // Correcting a name must never reset an item's stock. The document-level
      // guarantee is that itemToFirestore omits both fields; see the DTO test.
      final updated = repository.updated.single;
      expect(updated.stockAtBaseline, existing.stockAtBaseline);
      expect(updated.baselineDate, existing.baselineDate);
    });

    testWidgets('an item whose category is not a derived option still shows', (
      tester,
    ) async {
      final odd = testItem(id: 'x', name: 'Odd', category: 'Legacy  category');
      await _pumpForm(tester, repository, purchases, item: odd);

      expect(tester.takeException(), isNull);
      expect(find.text('Legacy  category'), findsOneWidget);
    });

    testWidgets('a refused update keeps the form open with the message', (
      tester,
    ) async {
      repository.updateResult = const Err(PermissionDenied());
      await _pumpForm(tester, repository, purchases, item: existing);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('You do not have access to this data'), findsOneWidget);
      expect(find.byType(ItemFormPage), findsOneWidget);
    });
  });

  group('deleting an item', () {
    final existing = testItem(id: 'abc123', name: 'Rice');

    testWidgets('a new item has nothing to delete', (tester) async {
      await _pumpForm(tester, repository, purchases);

      expect(find.byTooltip('Delete item'), findsNothing);
    });

    testWidgets('deleting asks first and names the item', (tester) async {
      await _pumpForm(tester, repository, purchases, item: existing);

      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this item?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(repository.deleted, isEmpty);
    });

    testWidgets('cancelling leaves the item alone', (tester) async {
      await _pumpForm(tester, repository, purchases, item: existing);
      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
      expect(find.byType(ItemFormPage), findsOneWidget);
    });

    testWidgets('confirming removes it and closes the form', (tester) async {
      await _pumpForm(tester, repository, purchases, item: existing);
      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleted, [existing]);
      expect(find.byType(ItemFormPage), findsNothing);
    });

    testWidgets('an item a purchase references is refused before the dialog', (
      tester,
    ) async {
      purchases.referenceResult = const Ok(true);
      await _pumpForm(tester, repository, purchases, item: existing);

      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this item?'), findsNothing);
      expect(
        find.text('This item is on a purchase and cannot be deleted'),
        findsOneWidget,
      );
      expect(repository.deleted, isEmpty);
    });

    testWidgets('a check that cannot be completed refuses the delete', (
      tester,
    ) async {
      purchases.referenceResult = const Err(ConnectionUnavailable());
      await _pumpForm(tester, repository, purchases, item: existing);

      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this item?'), findsNothing);
      expect(
        find.text('No connection. Check your network and try again'),
        findsOneWidget,
      );
    });

    testWidgets('a refused delete shows the mapped message and stays open', (
      tester,
    ) async {
      repository.deleteResult = const Err(PermissionDenied());
      await _pumpForm(tester, repository, purchases, item: existing);
      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('You do not have access to this data'), findsOneWidget);
      expect(find.byType(ItemFormPage), findsOneWidget);
    });
  });
}
