import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_cubit.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_section.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../fake_shopping_list_repository.dart';

void main() {
  late FakeShoppingListRepository entries;
  late FakeItemRepository items;
  late ShoppingListCubit cubit;

  setUp(() {
    entries = FakeShoppingListRepository();
    items = FakeItemRepository();
  });

  // Built inside the test, so its subscriptions run in the widget test's fake
  // async zone and `pump` delivers the stream's events.
  Future<void> pumpSection(WidgetTester tester) {
    cubit = ShoppingListCubit(
      entries,
      items,
      currentUser: testUser,
      clock: () => DateTime(2026, 9, 24, 8),
    );
    addTearDown(cubit.close);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CustomScrollView(slivers: [ShoppingListSection()]),
          ),
        ),
      ),
    );
  }

  Finder addField() => find.widgetWithText(TextField, 'Add to the list');

  testWidgets('shows a spinner under the heading while loading', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Shopping list'), findsOneWidget);
    expect(addField(), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says when the list is empty', (tester) async {
    await pumpSection(tester);

    entries.emitEntries(const []);
    await tester.pump();

    expect(find.text('The list is empty'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists each entry with a checkbox', (tester) async {
    await pumpSection(tester);

    entries.emitEntries([
      testEntry(id: 'e1', text: 'Milk'),
      testEntry(id: 'e2', text: 'Eggs'),
    ]);
    await tester.pump();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.bySemanticsLabel('Got Milk'), findsOneWidget);
  });

  testWidgets('shows a failure and resubscribes on retry', (tester) async {
    await pumpSection(tester);

    entries.emitError(const ConnectionUnavailable());
    await tester.pump();

    expect(find.text(const ConnectionUnavailable().message), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pump();

    expect(entries.watchCalls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('refuses an empty entry inline, and clears the error on edit', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.enterText(addField(), '   ');
    await tester.tap(find.byTooltip('Add'));
    await tester.pump();

    expect(find.text('Enter something to buy'), findsOneWidget);
    expect(entries.added, isEmpty);

    await tester.enterText(addField(), 'M');
    await tester.pump();

    expect(find.text('Enter something to buy'), findsNothing);
  });

  testWidgets('adding writes the entry and clears the field', (tester) async {
    await pumpSection(tester);

    await tester.enterText(addField(), 'Bread');
    await tester.tap(find.byTooltip('Add'));
    await tester.pump();

    expect(entries.added.single.text, 'Bread');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('the keyboard action adds too', (tester) async {
    await pumpSection(tester);

    await tester.enterText(addField(), 'Bread');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(entries.added.single.text, 'Bread');
  });

  testWidgets('a refused add shows its message', (tester) async {
    await pumpSection(tester);
    entries.addResult = const Err(PermissionDenied());

    await tester.enterText(addField(), 'Bread');
    await tester.tap(find.byTooltip('Add'));
    await tester.pump();

    expect(find.text(const PermissionDenied().message), findsOneWidget);
  });

  testWidgets('a write still pending after the window shows nothing', (
    tester,
  ) async {
    await pumpSection(tester);
    entries.writeGate = Completer<void>();
    entries.addResult = const Err(PermissionDenied());

    await tester.enterText(addField(), 'Bread');
    await tester.tap(find.byTooltip('Add'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsNothing);

    entries.writeGate?.complete();
    await tester.pump();
  });

  testWidgets('ticking an entry removes it', (tester) async {
    await pumpSection(tester);
    entries.emitEntries([testEntry(id: 'e1', text: 'Milk')]);
    await tester.pump();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(entries.removed, ['e1']);
  });

  testWidgets('tapping the text does not remove the entry', (tester) async {
    await pumpSection(tester);
    entries.emitEntries([testEntry(id: 'e1', text: 'Milk')]);
    await tester.pump();

    await tester.tap(find.text('Milk'));
    await tester.pump();

    expect(entries.removed, isEmpty);
  });

  testWidgets('a refused tick shows its message', (tester) async {
    await pumpSection(tester);
    entries.removeResult = const Err(PermissionDenied());
    entries.emitEntries([testEntry(id: 'e1', text: 'Milk')]);
    await tester.pump();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(find.text(const PermissionDenied().message), findsOneWidget);
  });
}
