import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/items/logic/stock_event.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';
import 'package:grocery_accounting/features/items/presentation/stock_event_sheet.dart';

import '../../auth/fake_auth_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

final _now = DateTime(2026, 9, 3, 10, 30);

Future<void> _pumpSheet(
  WidgetTester tester,
  FakeItemRepository repository, {
  required StockEventType type,
  Item? item,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        // Eager, so the cubit is listening before a test emits items.
        lazy: false,
        create: (_) =>
            ItemsCubit(repository, FakePurchaseRepository(), clock: () => _now),
        child: Scaffold(
          body: StockEventSheet(
            item: item ?? testItem(),
            type: type,
            user: testUser,
          ),
        ),
      ),
    ),
  );
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pump();
}

void main() {
  late FakeItemRepository repository;

  setUp(() => repository = FakeItemRepository());

  testWidgets('logging use records a consumption by the signed-in member', (
    tester,
  ) async {
    await _pumpSheet(tester, repository, type: StockEventType.consumed);

    expect(find.text('Log use'), findsOneWidget);
    await tester.enterText(_field('Amount used'), '0,5');
    await tester.enterText(_field('Note (optional)'), '  Risotto  ');
    await _save(tester);

    final recorded = repository.recorded.single;
    expect(
      recorded.event,
      const StockEvent(
        itemId: 'abc123',
        type: StockEventType.consumed,
        quantity: 0.5,
        unit: ItemUnit.kg,
        userId: 'abc123',
        note: 'Risotto',
      ),
    );
    expect(recorded.now, _now);
  });

  testWidgets('a blank note is stored as no note', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.recount);

    await tester.enterText(_field('Counted amount'), '3');
    await tester.enterText(_field('Note (optional)'), '   ');
    await _save(tester);

    expect(repository.recorded.single.event.note, isNull);
  });

  testWidgets('a recount of zero is accepted', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.recount);

    await tester.enterText(_field('Counted amount'), '0');
    await _save(tester);

    expect(repository.recorded.single.event.type, StockEventType.recount);
    expect(repository.recorded.single.event.quantity, 0);
  });

  testWidgets('a removing adjustment is stored negative', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.adjustment);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.enterText(_field('Amount'), '1.5');
    await _save(tester);

    expect(repository.recorded.single.event.quantity, -1.5);
    expect(repository.recorded.single.event.type, StockEventType.adjustment);
  });

  testWidgets('an adding adjustment is stored positive', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.adjustment);

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.enterText(_field('Amount'), '2');
    await _save(tester);

    expect(repository.recorded.single.event.quantity, 2);
  });

  testWidgets('an adjustment without a direction is refused', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.adjustment);

    await tester.enterText(_field('Amount'), '2');
    await _save(tester);

    expect(find.text('Choose add or remove'), findsOneWidget);
    expect(repository.recorded, isEmpty);
  });

  testWidgets('choosing a direction clears its error at once', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.adjustment);

    // Typing a quantity revalidates the whole form, so the unchosen
    // direction reports its error before any save.
    await tester.enterText(_field('Amount'), '1');
    await tester.pump();
    expect(find.text('Choose add or remove'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pump();

    expect(find.text('Choose add or remove'), findsNothing);
  });

  testWidgets('the direction choice is only offered for an adjustment', (
    tester,
  ) async {
    await _pumpSheet(tester, repository, type: StockEventType.consumed);

    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('a quantity can be entered in a convertible unit', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      repository,
      type: StockEventType.consumed,
      item: testItem(unit: ItemUnit.kg, avgPieceWeight: 1.4),
    );

    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();
    // Only the units this item can be measured in are offered.
    expect(find.text('L'), findsNothing);
    await tester.tap(find.text('pcs').last);
    await tester.pumpAndSettle();

    await tester.enterText(_field('Amount used'), '1');
    await _save(tester);

    expect(repository.recorded.single.event.unit, ItemUnit.pcs);
    expect(repository.recorded.single.event.quantity, 1);
  });

  testWidgets('an invalid quantity shows its message and writes nothing', (
    tester,
  ) async {
    await _pumpSheet(tester, repository, type: StockEventType.consumed);

    await _save(tester);
    expect(find.text('Enter a number'), findsOneWidget);

    await tester.enterText(_field('Amount used'), '0');
    await _save(tester);
    expect(find.text('Must be greater than zero'), findsOneWidget);

    expect(repository.recorded, isEmpty);
  });

  testWidgets('a refused write stays open with the message until edited', (
    tester,
  ) async {
    repository.recordResult = const Err(PermissionDenied());
    await _pumpSheet(tester, repository, type: StockEventType.consumed);

    await tester.enterText(_field('Amount used'), '1');
    await _save(tester);
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsOneWidget);
    expect(find.byType(StockEventSheet), findsOneWidget);

    await tester.enterText(_field('Amount used'), '2');
    await tester.pump();

    expect(find.text('You do not have access to this data'), findsNothing);
  });

  testWidgets('saving disables the fields and the button', (tester) async {
    repository.writeGate = Completer<void>();
    await _pumpSheet(tester, repository, type: StockEventType.consumed);

    await tester.enterText(_field('Amount used'), '1');
    await _save(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    repository.writeGate?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an offline write closes the sheet after the refusal window', (
    tester,
  ) async {
    // Never completes, as a write does while offline.
    repository.writeGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ItemsCubit(
            repository,
            FakePurchaseRepository(),
            clock: () => _now,
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openStockEventSheet(
                  context,
                  item: testItem(),
                  type: StockEventType.recount,
                  user: testUser,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Counted amount'), '4');
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(StockEventSheet), findsNothing);
    expect(repository.recorded.single.event.quantity, 4);
  });

  testWidgets('saves against the newest version of the item', (tester) async {
    await _pumpSheet(tester, repository, type: StockEventType.consumed);
    final newer = testItem().copyWith(stockAtBaseline: 9);
    repository.emitItems([newer]);
    await tester.pump();

    await tester.enterText(_field('Amount used'), '1');
    await _save(tester);

    expect(repository.recorded.single.item, newer);
  });
}
