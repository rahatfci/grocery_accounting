import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/presentation/item_detail_page.dart';
import 'package:grocery_accounting/features/items/presentation/item_form_page.dart';

import '../../shell/shell_harness.dart';

/// An item whose stock stays put for the length of a test unless it is a
/// staple, in which case it runs down from [stock] from now.
Item _item(
  String name, {
  String category = 'pantry',
  double stock = 5,
  double threshold = 1,
  double usage = 0,
}) => Item(
  id: name.toLowerCase(),
  name: name,
  unit: ItemUnit.kg,
  category: category,
  avgPieceWeight: null,
  dailyUsage: usage,
  lowThreshold: threshold,
  stockAtBaseline: stock,
  baselineDate: DateTime.now(),
);

Future<void> _openPantry(WidgetTester tester, ShellFakes fakes) async {
  usePhone(tester, size: const Size(390, 1200));
  await pumpShell(tester, fakes);
  await openTab(tester, 'Pantry');
}

void main() {
  late ShellFakes fakes;

  setUp(() => fakes = ShellFakes());

  testWidgets('groups items by category with their stock and status', (
    tester,
  ) async {
    fakes.items.initialItems = [
      _item('Rice', stock: 0.3, usage: 0.1),
      _item('Pasta', stock: 3, usage: 0.1),
      _item('Milk', category: 'dairy', stock: 0, usage: 0.5),
      _item('Peeled tomatoes', threshold: 0),
    ];
    await _openPantry(tester, fakes);

    expect(find.text('DAIRY & EGGS'), findsOneWidget);
    expect(find.text('PANTRY & DRY GOODS'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Out'), findsOneWidget);
    expect(find.text('Not a staple'), findsOneWidget);
    expect(find.text('Logged by hand'), findsOneWidget);
    expect(find.text('0.1 kg a day'), findsNWidgets(2));
    expect(find.textContaining('days left'), findsOneWidget);
  });

  testWidgets('the filters count and narrow the pantry', (tester) async {
    fakes.items.initialItems = [
      _item('Rice', stock: 0.3, usage: 0.1),
      _item('Pasta', stock: 3, usage: 0.1),
      _item('Soap', category: 'household'),
    ];
    await _openPantry(tester, fakes);

    // The chip row scrolls sideways, so later chips may sit past its edge.
    expect(find.text('All · 3'), findsOneWidget);
    expect(find.text('Running low · 1', skipOffstage: false), findsOneWidget);
    expect(find.text('Staples · 2', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Running low · 1'));
    await tester.pump();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Pasta'), findsNothing);
    expect(find.text('Soap'), findsNothing);

    final chipRow = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.right,
    );
    await tester.scrollUntilVisible(
      find.text('Household & Cleaning'),
      150,
      scrollable: chipRow,
    );
    await tester.ensureVisible(find.text('Household & Cleaning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Household & Cleaning'));
    await tester.pump();

    expect(find.text('Soap'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
  });

  testWidgets('search finds an item by any part of its name', (tester) async {
    fakes.items.initialItems = [_item('Basmati rice'), _item('Pasta')];
    await _openPantry(tester, fakes);

    await tester.tap(find.byTooltip('Search the pantry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'RICE');
    await tester.pump();

    expect(find.text('Basmati rice'), findsOneWidget);
    expect(find.text('Pasta'), findsNothing);

    await tester.enterText(find.byType(TextField), 'caviar');
    await tester.pump();

    expect(find.text('Nothing in the pantry is called that'), findsOneWidget);
  });

  testWidgets('tapping an item opens it', (tester) async {
    fakes.items.initialItems = [_item('Rice')];
    await _openPantry(tester, fakes);

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemDetailPage), findsOneWidget);
  });

  testWidgets('the add button opens a new item', (tester) async {
    fakes.items.initialItems = [_item('Rice')];
    await _openPantry(tester, fakes);

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormPage), findsOneWidget);
    expect(find.text('New item'), findsOneWidget);
  });

  testWidgets('an empty pantry explains itself', (tester) async {
    await _openPantry(tester, fakes);

    expect(find.text('Nothing in the pantry yet'), findsOneWidget);
  });

  testWidgets('a failure shows the message and a way back', (tester) async {
    fakes.items.initialItems = null;
    await _openPantry(tester, fakes);

    fakes.items.emitErrorToAll(const PermissionDenied());
    await tester.pump();

    expect(find.text(const PermissionDenied().message), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a wide window lays the groups out in two columns', (
    tester,
  ) async {
    fakes.items.initialItems = [
      _item('Rice'),
      _item('Milk', category: 'dairy'),
    ];
    usePhone(tester, size: const Size(1400, 900));
    await pumpShell(tester, fakes);
    await tester.tap(find.text('Pantry'));
    await tester.pumpAndSettle();

    final dairy = tester.getTopLeft(find.text('DAIRY & EGGS'));
    final pantry = tester.getTopLeft(find.text('PANTRY & DRY GOODS'));
    expect(dairy.dy, pantry.dy);
    expect(dairy.dx, lessThan(pantry.dx));
  });
}
