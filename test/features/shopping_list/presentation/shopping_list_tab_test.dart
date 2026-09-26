import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_entry_row.dart';

import '../../auth/fake_auth_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../shell/shell_harness.dart';
import '../fake_shopping_list_repository.dart';

Item _low(String id, String name) => Item(
  id: id,
  name: name,
  unit: ItemUnit.kg,
  category: 'pantry',
  avgPieceWeight: null,
  dailyUsage: 0,
  lowThreshold: 1,
  stockAtBaseline: 0.3,
  baselineDate: DateTime.now().subtract(const Duration(days: 1)),
);

Future<void> _openList(WidgetTester tester, ShellFakes fakes) async {
  usePhone(tester);
  await pumpShell(tester, fakes);
  await tester.tap(find.bySemanticsLabel('List'));
  await tester.pumpAndSettle();
}

void main() {
  late ShellFakes fakes;

  setUp(() {
    fakes = ShellFakes();
    fakes.members.initialMembers = [
      testMember(displayName: 'Rahat'),
      testMember(id: 'u2', displayName: 'Giulia'),
    ];
  });

  testWidgets('lists each entry with who added it', (tester) async {
    fakes.shoppingList.initialEntries = [
      testEntry(id: 'e1', text: 'Olive oil', addedByUserId: 'u2'),
      testEntry(id: 'e2', text: 'Oat milk', addedByUserId: testUser.uid),
    ];
    await _openList(tester, fakes);

    expect(find.text('Olive oil'), findsOneWidget);
    expect(find.textContaining('Added by Giulia'), findsOneWidget);
    expect(find.textContaining('Added by you'), findsOneWidget);
    expect(find.text('Shared live with the household'), findsOneWidget);
  });

  testWidgets('says when the list is empty', (tester) async {
    await _openList(tester, fakes);

    expect(
      find.text('The list is empty. Anyone in the household can add to it.'),
      findsOneWidget,
    );
  });

  testWidgets('a ticked entry shows ticked for a moment, then goes', (
    tester,
  ) async {
    fakes.shoppingList.initialEntries = [testEntry(id: 'e1', text: 'Milk')];
    await _openList(tester, fakes);

    await tester.tap(find.bySemanticsLabel('Got Milk'));
    await tester.pump();
    expect(fakes.shoppingList.removed, isEmpty);

    await tester.pump(tickedEntryDelay);

    expect(fakes.shoppingList.removed, ['e1']);
  });

  testWidgets('a second tap inside the moment keeps the entry', (tester) async {
    fakes.shoppingList.initialEntries = [testEntry(id: 'e1', text: 'Milk')];
    await _openList(tester, fakes);

    await tester.tap(find.bySemanticsLabel('Got Milk'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.bySemanticsLabel('Got Milk'));
    await tester.pump(const Duration(seconds: 2));

    expect(fakes.shoppingList.removed, isEmpty);
  });

  testWidgets('a ticked entry still goes when its row does', (tester) async {
    fakes.shoppingList.initialEntries = [testEntry(id: 'e1', text: 'Milk')];
    await _openList(tester, fakes);

    await tester.tap(find.bySemanticsLabel('Got Milk'));
    await tester.pump();
    // Another phone cleared the list inside the moment.
    fakes.shoppingList.emitEntries(const []);
    await tester.pump();

    expect(fakes.shoppingList.removed, ['e1']);
  });

  testWidgets('tapping the text does not remove the entry', (tester) async {
    fakes.shoppingList.initialEntries = [testEntry(id: 'e1', text: 'Milk')];
    await _openList(tester, fakes);

    await tester.tap(find.text('Milk'));
    await tester.pump(const Duration(seconds: 2));

    expect(fakes.shoppingList.removed, isEmpty);
    expect(find.byType(ShoppingEntryRow), findsOneWidget);
  });

  testWidgets('a refused removal shows its message', (tester) async {
    fakes.shoppingList.initialEntries = [testEntry(id: 'e1', text: 'Milk')];
    fakes.shoppingList.removeResult = const Err(PermissionDenied());
    await _openList(tester, fakes);

    await tester.tap(find.bySemanticsLabel('Got Milk'));
    await tester.pump(tickedEntryDelay);
    await tester.pump();

    expect(find.text(const PermissionDenied().message), findsOneWidget);
  });

  testWidgets('adding writes the entry and clears the field', (tester) async {
    await _openList(tester, fakes);

    await tester.enterText(find.byType(TextField), 'Basil');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(fakes.shoppingList.added.single.text, 'Basil');
    expect(find.text('Basil'), findsNothing);
  });

  testWidgets('an empty entry is refused inline', (tester) async {
    await _openList(tester, fakes);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter something to buy'), findsOneWidget);
    expect(fakes.shoppingList.added, isEmpty);
  });

  testWidgets('running low items not on the list are offered, and added '
      'linked', (tester) async {
    fakes.items.initialItems = [_low('rice', 'Rice'), _low('oil', 'Olive oil')];
    fakes.shoppingList.initialEntries = [testEntry(text: 'Olive oil')];
    await _openList(tester, fakes);

    expect(find.text('Running low, not on the list'), findsOneWidget);
    expect(find.byTooltip('Add Olive oil to the list'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Add Rice to the list'));
    await tester.tap(find.byTooltip('Add Rice to the list'));
    await tester.pump();

    final added = fakes.shoppingList.added.single;
    expect(added.text, 'Rice');
    expect(added.itemId, 'rice');
  });
}
