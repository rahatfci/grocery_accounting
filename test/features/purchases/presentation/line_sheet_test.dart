import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/form_controls.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/presentation/line_sheet.dart';

import '../../items/fake_item_repository.dart';

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)),
  matching: find.byType(TextField),
);

/// The unit segment labelled [label].
Finder _unit(String label) => find.descendant(
  of: find.byType(SegmentedPicker<ItemUnit>),
  matching: find.text(label),
);

void main() {
  final rice = testItem(id: 'rice', name: 'Rice');
  // Weighed in kg, with no piece weight: pieces cannot be converted.
  final flour = testItem(id: 'flour', name: 'Flour');
  final eggs = testItem(id: 'eggs', name: 'Eggs', unit: ItemUnit.pcs);

  late LineSheetResult? result;

  /// Opens the sheet over a blank screen and keeps what it pops.
  Future<void> open(
    WidgetTester tester, {
    List<Item>? items,
    PurchaseDraftLine? line,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showLineSheet(
              context,
              items: items ?? [rice, flour, eggs],
              line: line,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  PurchaseDraftLine chosen() => switch (result) {
    LineChosen(:final line) => line,
    final other => throw StateError('Expected a chosen line, got $other'),
  };

  const scanned = PurchaseDraftLine(
    item: null,
    quantity: 400,
    unit: ItemUnit.g,
    lineTotal: 1.20,
    scannedText: 'FARINA 00 400G',
  );

  testWidgets('a receipt line keeps its unit when the item converts it', (
    tester,
  ) async {
    await open(tester, line: scanned);

    await tap(tester, find.text('Flour'));
    await tap(tester, find.widgetWithText(FilledButton, 'Match line'));

    final line = chosen();
    expect(line.item, flour);
    expect(line.quantity, 400);
    expect(line.unit, ItemUnit.g);
    expect(line.lineTotal, 1.20);
    expect(line.scannedText, 'FARINA 00 400G');
  });

  testWidgets('a unit the item cannot take gives way to its own', (
    tester,
  ) async {
    await open(tester, line: scanned);

    await tap(tester, find.text('Eggs'));

    // Eggs are counted, and grams do not convert into pieces.
    expect(_unit('g'), findsNothing);
    expect(_unit('kg'), findsNothing);
    await tap(tester, find.widgetWithText(FilledButton, 'Match line'));
    expect(chosen().unit, ItemUnit.pcs);
  });

  testWidgets('before an item is chosen every unit is offered', (tester) async {
    await open(tester);

    for (final unit in ItemUnit.values) {
      expect(_unit(unit.label), findsOneWidget);
    }
  });

  testWidgets('the learning note follows the quantity as it is typed', (
    tester,
  ) async {
    await open(tester, line: scanned);
    await tap(tester, find.text('Flour'));

    expect(
      find.text(
        'From now on, FARINA 00 400G becomes 400 g of Flour by itself.',
      ),
      findsOneWidget,
    );

    await tester.enterText(_field('Quantity'), '500');
    await tester.pump();

    expect(
      find.text(
        'From now on, FARINA 00 400G becomes 500 g of Flour by itself.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a line typed by hand has no learning note', (tester) async {
    await open(tester);
    await tap(tester, find.text('Rice'));

    expect(find.textContaining('From now on'), findsNothing);
    expect(_field('Line total'), findsOneWidget);
  });

  testWidgets('editing a learned line makes it the member\'s own match', (
    tester,
  ) async {
    await open(
      tester,
      line: PurchaseDraftLine(
        item: rice,
        quantity: 1,
        unit: ItemUnit.kg,
        lineTotal: 2.49,
        scannedText: 'RISO ARBORIO 1KG',
        learned: true,
      ),
    );

    expect(find.text('Edit line'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, 'Save line'));

    expect(chosen().learned, isFalse);
    expect(chosen().item, rice);
  });

  testWidgets('search narrows the pantry and says when nothing matches', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(_field('Pantry item'), 'FLO');
    await tester.pump();

    expect(find.text('Flour'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);

    await tester.enterText(_field('Pantry item'), 'caviar');
    await tester.pump();

    expect(find.text('Nothing in the pantry is called that'), findsOneWidget);
    expect(find.text('Create “Caviar”'), findsOneWidget);
  });

  testWidgets('the chosen item reads as the checked option', (tester) async {
    await open(tester);

    await tap(tester, find.text('Rice'));

    expect(
      tester.getSemantics(find.text('Rice')),
      matchesSemantics(
        label: 'Rice\nPantry & Dry Goods · kg',
        isChecked: true,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
  });

  testWidgets('a new item is created with nothing to track yet', (
    tester,
  ) async {
    await open(tester, line: scanned);

    await tap(tester, find.text('Create “Farina”'));
    await tap(tester, find.text('g').last);
    await tap(tester, find.text('Pantry & Dry Goods'));
    await tap(tester, find.widgetWithText(FilledButton, 'Add line'));

    final line = chosen();
    final item = line.item;
    expect(item?.id, isEmpty);
    expect(item?.name, 'Farina');
    expect(item?.unit, ItemUnit.g);
    expect(item?.category, 'pantry');
    expect(item?.dailyUsage, 0);
    expect(item?.lowThreshold, 0);
    expect(line.unit, ItemUnit.g);
    expect(line.quantity, 400);
    expect(line.lineTotal, 1.20);
    expect(line.scannedText, 'FARINA 00 400G');
  });

  testWidgets('cancel and dismiss decide nothing', (tester) async {
    await open(tester, line: scanned);

    await tap(tester, find.widgetWithText(FilledButton, 'Cancel'));

    expect(find.byType(LineSheet), findsNothing);
    expect(result, isNull);
  });

  testWidgets('an existing line can be removed', (tester) async {
    await open(tester, line: scanned);

    await tap(tester, find.widgetWithText(TextButton, 'Remove line'));

    expect(result, isA<LineRemoved>());
  });

  testWidgets('a new line cannot be removed, only cancelled', (tester) async {
    await open(tester);

    expect(find.widgetWithText(TextButton, 'Remove line'), findsNothing);
  });
}
