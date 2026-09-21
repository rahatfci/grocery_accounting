import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_category.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';

import '../fake_item_repository.dart';

Future<void> _pumpForm(
  WidgetTester tester,
  FakeItemRepository repository, {
  List<Item> existing = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => ItemsCubit(repository),
        child: ItemFormPage(categories: availableCategories(existing)),
      ),
    ),
  );
}

Future<void> _pumpEditForm(
  WidgetTester tester,
  FakeItemRepository repository,
  Item item,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => ItemsCubit(repository),
        child: ItemFormPage(
          categories: availableCategories([item]),
          item: item,
        ),
      ),
    ),
  );
}

Future<void> _chooseCategory(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<Object>));
  await tester.pumpAndSettle();
  // The open menu scrolls once enough categories are in use, and the final
  // "Add category" entry is the one that ends up at its edge.
  final option = find.text(label).last;
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

/// The form scrolls, and revealing the new-category field pushes the button
/// past the bottom of a phone-sized window, so scroll to it as a member would.
Future<void> _tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
}

Future<void> _fillValidForm(
  WidgetTester tester, {
  String name = 'Rice',
  String lowThreshold = '2',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Low threshold'),
    lowThreshold,
  );
  await _chooseCategory(tester, 'Pantry & Dry Goods');
}

void main() {
  late FakeItemRepository repository;

  setUp(() => repository = FakeItemRepository());

  testWidgets('an empty submit reports every required field', (tester) async {
    await _pumpForm(tester, repository);

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
    await _pumpForm(tester, repository);

    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Daily usage'),
          )
          .controller
          ?.text,
      '0',
    );
  });

  testWidgets('a non-numeric amount is rejected', (tester) async {
    await _pumpForm(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Low threshold'),
      'two',
    );
    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Enter a valid number'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('a zero piece weight is rejected, a positive one accepted', (
    tester,
  ) async {
    await _pumpForm(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Average piece weight (optional)'),
      '0',
    );
    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Must be greater than zero'), findsOneWidget);
  });

  testWidgets('a decimal comma is accepted, as the household writes it', (
    tester,
  ) async {
    await _pumpForm(tester, repository);
    await _fillValidForm(tester, lowThreshold: '1,5');

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.created.single.lowThreshold, 1.5);
  });

  testWidgets('a created item carries a zero baseline and the chosen fields', (
    tester,
  ) async {
    await _pumpForm(tester, repository);
    await _fillValidForm(tester, name: '  Rice  ');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Daily usage'),
      '0.25',
    );

    await _tapSave(tester);
    await tester.pumpAndSettle();

    final created = repository.created.single;
    // The baseline pair makes the document a valid input to the stock formula
    // from the moment it exists. The server timestamp itself is the
    // repository's to write; see the DTO test.
    expect(created.stockAtBaseline, 0);
    expect(created.baselineDate, isNotNull);
    expect(created.id, isEmpty, reason: 'an empty id is what makes it create');
    expect(created.name, 'Rice', reason: 'the name is trimmed');
    expect(created.category, 'pantry', reason: 'the key is stored, not label');
    expect(created.unit, ItemUnit.kg);
    expect(created.dailyUsage, 0.25);
    expect(created.avgPieceWeight, isNull);
    expect(repository.updated, isEmpty);
  });

  testWidgets('a successful save closes the form', (tester) async {
    await _pumpForm(tester, repository);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsNothing);
  });

  testWidgets('saving disables the form and shows progress', (tester) async {
    repository.writeGate = Completer<void>();
    await _pumpForm(tester, repository);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Save'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Name'))
          .enabled,
      isFalse,
    );

    repository.writeGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a refused save shows the mapped message and stays open', (
    tester,
  ) async {
    repository.createResult = const Err(PermissionDenied());
    await _pumpForm(tester, repository);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('You do not have access to this data'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(find.byType(ItemFormPage), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('editing a field clears the previous failure', (tester) async {
    repository.createResult = const Err(PermissionDenied());
    await _pumpForm(tester, repository);
    await _fillValidForm(tester);
    await _tapSave(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Rice and beans',
    );
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsNothing);
  });

  testWidgets('a write that never acknowledges still closes the form', (
    tester,
  ) async {
    // Offline, a queued write is durable but never acknowledged. The form must
    // not hang on it.
    repository.writeGate = Completer<void>();
    await _pumpForm(tester, repository);
    await _fillValidForm(tester);

    await _tapSave(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsNothing);
    expect(repository.created, hasLength(1));

    repository.writeGate!.complete();
    await tester.pumpAndSettle();
  });

  group('the category picker', () {
    testWidgets('offers the built-ins and every category already in use', (
      tester,
    ) async {
      await _pumpForm(
        tester,
        repository,
        existing: [testItem(category: 'Baby things')],
      );

      await tester.tap(find.byType(DropdownButtonFormField<Object>));
      await tester.pumpAndSettle();

      expect(find.text('Produce'), findsOneWidget);
      expect(find.text('Household & Cleaning'), findsOneWidget);
      expect(find.text('Baby things'), findsOneWidget);
      expect(find.text('Add category'), findsOneWidget);
    });

    testWidgets('adding a category reveals a field and stores the text', (
      tester,
    ) async {
      await _pumpForm(tester, repository);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Nappies',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low threshold'),
        '2',
      );

      await _chooseCategory(tester, 'Add category');
      expect(
        find.widgetWithText(TextFormField, 'New category'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New category'),
        '  Baby   things ',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();

      // Trimmed and collapsed, so spacing cannot fork one category into two.
      expect(repository.created.single.category, 'Baby things');
    });

    testWidgets('an empty new category is rejected', (tester) async {
      await _pumpForm(tester, repository);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Nappies',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low threshold'),
        '2',
      );
      await _chooseCategory(tester, 'Add category');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New category'),
        '   ',
      );
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
        existing: [testItem(category: 'Baby things')],
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Nappies',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low threshold'),
        '2',
      );
      await _chooseCategory(tester, 'Add category');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New category'),
        'BABY THINGS',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.created.single.category, 'Baby things');
    });

    testWidgets('typing a built-in label selects the built-in key', (
      tester,
    ) async {
      await _pumpForm(tester, repository);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Milk',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low threshold'),
        '2',
      );
      await _chooseCategory(tester, 'Add category');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New category'),
        'dairy & eggs',
      );
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
      await _pumpEditForm(tester, repository, existing);

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Rice'), findsOneWidget);
      // A whole number reads as 2, not 2.0.
      expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0.25'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1.5'), findsOneWidget);
      expect(find.text('Pantry & Dry Goods'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
    });

    testWidgets('saving updates rather than creating', (tester) async {
      await _pumpEditForm(tester, repository, existing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rice'),
        'Basmati rice',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.created, isEmpty);
      final updated = repository.updated.single;
      expect(updated.id, 'abc123', reason: 'the same document is written');
      expect(updated.name, 'Basmati rice');
    });

    testWidgets('an edit carries the baseline pair through untouched', (
      tester,
    ) async {
      await _pumpEditForm(tester, repository, existing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rice'),
        'Basmati rice',
      );
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
      // A stored value that never normalized to one of the offered options
      // must not leave the dropdown without a value to render.
      final odd = testItem(id: 'x', name: 'Odd', category: 'Legacy  category');

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ItemsCubit(repository),
            child: ItemFormPage(
              categories: availableCategories(const []),
              item: odd,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Legacy  category'), findsOneWidget);
    });

    testWidgets('a refused update keeps the form open with the message', (
      tester,
    ) async {
      repository.updateResult = const Err(PermissionDenied());
      await _pumpEditForm(tester, repository, existing);

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('You do not have access to this data'), findsOneWidget);
      expect(find.byType(ItemFormPage), findsOneWidget);
    });
  });

  group('deleting an item', () {
    final existing = testItem(id: 'abc123', name: 'Rice');

    testWidgets('a new item has nothing to delete', (tester) async {
      await _pumpForm(tester, repository);

      expect(find.byTooltip('Delete item'), findsNothing);
    });

    testWidgets('deleting asks first and names the item', (tester) async {
      await _pumpEditForm(tester, repository, existing);

      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this item?'), findsOneWidget);
      expect(find.textContaining('Rice'), findsWidgets);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(repository.deleted, isEmpty);
    });

    testWidgets('cancelling leaves the item alone', (tester) async {
      await _pumpEditForm(tester, repository, existing);
      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
      expect(find.byType(ItemFormPage), findsOneWidget);
    });

    testWidgets('confirming removes it and closes the form', (tester) async {
      await _pumpEditForm(tester, repository, existing);
      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleted, [existing]);
      expect(find.byType(ItemFormPage), findsNothing);
    });

    testWidgets('a refused delete shows the mapped message and stays open', (
      tester,
    ) async {
      repository.deleteResult = const Err(PermissionDenied());
      await _pumpEditForm(tester, repository, existing);
      await tester.tap(find.byTooltip('Delete item'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('You do not have access to this data'), findsOneWidget);
      expect(find.byType(ItemFormPage), findsOneWidget);
    });
  });
}
