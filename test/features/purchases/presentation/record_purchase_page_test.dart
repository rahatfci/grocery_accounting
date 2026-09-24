import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_line_sheet.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_cubit.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_page.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_state.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../receipts/fake_receipts.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';
import '../fake_purchase_repository.dart';

final _now = DateTime(2026, 9, 21, 18, 30);

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakePurchaseRepository purchases;
  late FakeItemRepository items;
  late FakeMemberRepository members;
  late RecordPurchaseCubit cubit;
  late FakeReceiptPicker receiptPicker;
  late FakeReceiptStore receipts;
  late FakeReceiptReader receiptReader;

  setUp(() {
    receiptPicker = FakeReceiptPicker();
    receipts = FakeReceiptStore();
    receiptReader = FakeReceiptReader();
    purchases = FakePurchaseRepository();
    items = FakeItemRepository();
    members = FakeMemberRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    // A phone-width window, which is where a line row or a form field is most
    // likely to overflow.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Built inside the test, not in setUp: a cubit created outside the test's
    // fake-async zone never delivers its stream events to the pump loop.
    cubit = RecordPurchaseCubit(
      purchases: purchases,
      items: items,
      members: members,
      shoppingList: FakeShoppingListRepository(),
      receiptPicker: receiptPicker,
      receipts: receipts,
      receiptReader: receiptReader,
      currentUser: testUser,
      now: () => _now,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RecordPurchaseCubit>.value(
          value: cubit,
          child: const RecordPurchaseView(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Both collections reported, which is the state the screen is used in.
  Future<void> pumpReady(
    WidgetTester tester, {
    List<Item> catalogue = const [],
    List<HouseholdMember> household = const [],
  }) async {
    await pump(tester);
    items.emitItems(catalogue);
    members.emitMembers(household);
    await tester.pumpAndSettle();
  }

  Future<void> fillHeader(WidgetTester tester) async {
    await tester.enterText(_field('Shop'), 'Conad');
    await tester.enterText(_field('Total'), '43,20');
    await tester.pumpAndSettle();
  }

  /// Drives the line sheet the way a member would: pick the item, type the
  /// quantity and the price, confirm.
  Future<void> addLine(
    WidgetTester tester, {
    required String item,
    String quantity = '1',
    String lineTotal = '2,40',
    String confirm = 'Add line',
  }) async {
    await _tap(tester, find.byType(DropdownButtonFormField<Object>));
    await _tap(tester, find.text(item).last);
    await tester.enterText(_field('Quantity'), quantity);
    await tester.enterText(_field('Line total'), lineTotal);
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(FilledButton, confirm));
  }

  group('before the collections report', () {
    testWidgets('waits rather than showing an empty form', (tester) async {
      await pump(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_field('Shop'), findsNothing);
    });
  });

  group('a stream failure', () {
    testWidgets('shows the mapped message and offers a retry', (tester) async {
      await pumpReady(tester);

      items.emitError(const ConnectionUnavailable());
      await tester.pumpAndSettle();

      expect(
        find.text('No connection. Check your network and try again'),
        findsOneWidget,
      );

      // Not pumpAndSettle: retrying goes back to the spinner, which never
      // settles because it never stops animating.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(items.watchCalls, 2);
      expect(members.watchCalls, 2);
    });
  });

  group('the form', () {
    testWidgets('shows the date, the header fields and the payer', (
      tester,
    ) async {
      await pumpReady(tester, household: [testMember()]);

      expect(find.text('21/09/2026'), findsOneWidget);
      expect(_field('Shop'), findsOneWidget);
      expect(_field('Total'), findsOneWidget);
      // The payer defaults to the signed-in member.
      expect(find.text('rahat'), findsOneWidget);
      expect(
        find.text('No lines yet. The spend is recorded either way.'),
        findsOneWidget,
      );
    });

    testWidgets('sends what is typed to the draft', (tester) async {
      await pumpReady(tester);
      await fillHeader(tester);

      expect(purchases.committed, isEmpty);
      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(purchases.committed.single.shopName, 'Conad');
      expect(purchases.committed.single.totalText, '43,20');
      expect(purchases.committed.single.paidByUserId, testUser.uid);
    });

    testWidgets('refuses to save an empty form, field by field', (
      tester,
    ) async {
      await pumpReady(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(find.text('Enter a shop'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(purchases.committed, isEmpty);
    });

    testWidgets('refuses a total of zero', (tester) async {
      await pumpReady(tester);
      await tester.enterText(_field('Shop'), 'Lidl');
      await tester.enterText(_field('Total'), '0');
      await tester.pumpAndSettle();

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
      expect(purchases.committed, isEmpty);
    });

    testWidgets('opens a date picker on the date field', (tester) async {
      await pumpReady(tester);

      await _tap(tester, find.text('21/09/2026'));

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('lines', () {
    testWidgets('are added through the sheet and show against the total', (
      tester,
    ) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await fillHeader(tester);

      await _tap(tester, find.widgetWithText(TextButton, 'Add line'));
      expect(find.byType(PurchaseLineSheet), findsOneWidget);

      await addLine(tester, item: 'Rice');

      expect(find.byType(PurchaseLineSheet), findsNothing);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('1 kg'), findsOneWidget);
      // The lines against the receipt total, which are allowed to differ.
      expect(
        find.text('Lines 2,40\u00a0\u20ac of 43,20\u00a0\u20ac'),
        findsOneWidget,
      );
    });

    testWidgets('can create an item that is not in the catalogue yet', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      await _tap(tester, find.widgetWithText(TextButton, 'Add line'));
      await _tap(tester, find.byType(DropdownButtonFormField<Object>));
      await _tap(tester, find.text('New item').last);

      expect(_field('New item name'), findsOneWidget);

      await tester.enterText(_field('New item name'), 'Passata');
      await tester.enterText(_field('Quantity'), '2');
      await tester.enterText(_field('Line total'), '1,80');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(find.text('Passata'), findsOneWidget);
      expect(find.text('2 kg - new item'), findsOneWidget);

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      final line = purchases.committed.single.lines.single;
      expect(line.item?.id, isEmpty);
      expect(line.item?.name, 'Passata');
      expect(line.item?.dailyUsage, 0);
      expect(line.quantity, 2);
    });

    testWidgets('refuses a new item with no name', (tester) async {
      await pumpReady(tester);

      await _tap(tester, find.widgetWithText(TextButton, 'Add line'));
      await _tap(tester, find.byType(DropdownButtonFormField<Object>));
      await _tap(tester, find.text('New item').last);
      await tester.enterText(_field('Quantity'), '1');
      await tester.enterText(_field('Line total'), '1');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(find.byType(PurchaseLineSheet), findsOneWidget);
      expect(find.text('Enter a name'), findsOneWidget);
    });

    testWidgets('refuses a line with no item chosen', (tester) async {
      await pumpReady(tester, catalogue: [testItem(name: 'Rice')]);

      await _tap(tester, find.widgetWithText(TextButton, 'Add line'));
      await tester.enterText(_field('Quantity'), '1');
      await tester.enterText(_field('Line total'), '1');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(find.text('Choose an item'), findsOneWidget);
    });

    testWidgets('are edited by tapping the row', (tester) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await fillHeader(tester);
      await _tap(tester, find.widgetWithText(TextButton, 'Add line'));
      await addLine(tester, item: 'Rice');

      await _tap(tester, find.text('Rice'));
      expect(find.text('Edit line'), findsOneWidget);

      await tester.enterText(_field('Quantity'), '3');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Save line'));

      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('1 kg'), findsNothing);
    });

    testWidgets('are removed from the row', (tester) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await _tap(tester, find.widgetWithText(TextButton, 'Add line'));
      await addLine(tester, item: 'Rice');

      await _tap(tester, find.byTooltip('Remove line'));

      expect(find.text('Rice'), findsNothing);
      expect(
        find.text('No lines yet. The spend is recorded either way.'),
        findsOneWidget,
      );
    });
  });

  group('saving', () {
    testWidgets('shows progress while the write is in flight', (tester) async {
      purchases.writeGate = Completer<void>();
      await pumpReady(tester);
      await fillHeader(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save purchase'));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      purchases.writeGate?.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('closes the screen once the purchase is written', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(find.byType(RecordPurchaseView), findsNothing);
    });

    testWidgets('keeps an offline write, rather than waiting on it', (
      tester,
    ) async {
      // A write that never completes is what offline looks like with
      // persistence on: the local cache already has it.
      purchases.writeGate = Completer<void>();
      await pumpReady(tester);
      await fillHeader(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save purchase'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(RecordPurchaseView), findsNothing);
      purchases.writeGate?.complete();
    });

    testWidgets('stays open with the mapped message when refused', (
      tester,
    ) async {
      purchases.commitResult = const Err(PermissionDenied());
      await pumpReady(tester);
      await fillHeader(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(find.byType(RecordPurchaseView), findsOneWidget);
      expect(find.text('You do not have access to this data'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
    });

    testWidgets('shows a draft problem no single field can show', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      // Nothing on the screen can clear the payer, and the dropdown keeps the
      // value it was given. A draft that reaches the commit without one still
      // has to say so rather than failing quietly.
      cubit.setPaidByUserId('');
      await tester.pumpAndSettle();

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(find.text('Choose who paid'), findsOneWidget);
      expect(purchases.committed, isEmpty);
    });

    testWidgets('clears the message once the member edits the form', (
      tester,
    ) async {
      purchases.commitResult = const Err(PermissionDenied());
      await pumpReady(tester);
      await fillHeader(tester);
      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));
      expect(find.text('You do not have access to this data'), findsOneWidget);

      await tester.enterText(_field('Shop'), 'Lidl');
      await tester.pumpAndSettle();

      expect(find.text('You do not have access to this data'), findsNothing);
    });
  });

  group('receipt photo', () {
    Future<void> attachFrom(WidgetTester tester, String source) async {
      await _tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Attach receipt photo'),
      );
      await _tap(tester, find.text(source));
    }

    testWidgets('attaches a photo from the camera or the gallery', (
      tester,
    ) async {
      await pumpReady(tester);

      await attachFrom(tester, 'Take photo');

      expect(receiptPicker.sources, [ReceiptSource.camera]);
      expect(find.bySemanticsLabel('Receipt photo'), findsOneWidget);
      expect(find.text('Attach receipt photo'), findsNothing);
    });

    testWidgets('replaces and removes the attached photo', (tester) async {
      await pumpReady(tester);
      await attachFrom(tester, 'Choose from gallery');
      final first = (cubit.state as RecordPurchaseReady).draft.receipt;

      receiptPicker.result = Ok(testPhoto(9));
      await _tap(tester, find.widgetWithText(TextButton, 'Replace'));
      await _tap(tester, find.text('Choose from gallery'));

      final second = (cubit.state as RecordPurchaseReady).draft.receipt;
      expect(second, isNotNull);
      expect(identical(first, second), isFalse);

      await _tap(tester, find.widgetWithText(TextButton, 'Remove'));

      expect((cubit.state as RecordPurchaseReady).draft.receipt, isNull);
      expect(find.text('Attach receipt photo'), findsOneWidget);
    });

    testWidgets('dismissing the source sheet attaches nothing', (tester) async {
      await pumpReady(tester);

      await _tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Attach receipt photo'),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(receiptPicker.sources, isEmpty);
      expect(find.text('Attach receipt photo'), findsOneWidget);
    });

    testWidgets('a denied pick says why and attaches nothing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      receiptPicker.result = const Err(ReceiptAccessDenied());
      await pumpReady(tester);

      await attachFrom(tester, 'Take photo');

      expect(find.text(const ReceiptAccessDenied().message), findsOneWidget);
      expect(find.text('Attach receipt photo'), findsOneWidget);
    });

    testWidgets('a photo that could not be kept is reported after saving', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      receipts.keepResult = const Err(ConnectionUnavailable());
      cubit = RecordPurchaseCubit(
        purchases: purchases,
        items: items,
        members: members,
        shoppingList: FakeShoppingListRepository(),
        receiptPicker: receiptPicker,
        receipts: receipts,
        receiptReader: receiptReader,
        currentUser: testUser,
        now: () => _now,
      );
      addTearDown(cubit.close);
      // Pushed over a screen of its own, so the message has somewhere to
      // show once the review screen closes.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: cubit,
                      child: const RecordPurchaseView(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      // The screen spins until both collections report, so it never settles
      // before they do.
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      items.emitItems(const []);
      members.emitMembers(const []);
      await tester.pumpAndSettle();
      await fillHeader(tester);
      await attachFrom(tester, 'Take photo');

      await _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

      expect(find.byType(RecordPurchaseView), findsNothing);
      expect(
        find.text(
          'Saved without the photo. ${const ConnectionUnavailable().message}',
        ),
        findsOneWidget,
      );
    });
  });

  group('reading a receipt', () {
    final reading = ReceiptReading(
      total: 5.48,
      date: DateTime(2026, 9, 20),
      lines: const [
        ScannedLine(
          rawText: 'RISO ARBORIO',
          quantity: 1,
          unit: ItemUnit.kg,
          lineTotal: 1.80,
        ),
      ],
    );

    Future<void> attachPhoto(WidgetTester tester) async {
      await _tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Attach receipt photo'),
      );
      await _tap(tester, find.text('Take photo'));
    }

    testWidgets('prefills the total and marks unmatched lines', (tester) async {
      receiptReader.result = Ok(reading);
      await pumpReady(tester);

      await attachPhoto(tester);

      expect(
        tester.widget<TextFormField>(_field('Total')).controller?.text,
        '5,48',
      );
      expect(find.text('20/09/2026'), findsOneWidget);
      expect(find.text('RISO ARBORIO'), findsOneWidget);
      expect(find.textContaining('Not matched'), findsOneWidget);
      // Filling the total in is not the member typing, so the empty shop is
      // not flagged yet.
      expect(find.text('Enter a shop'), findsNothing);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('shows that it is reading', (tester) async {
      receiptReader.gate = Completer<void>();
      await pumpReady(tester);

      await _tap(
        tester,
        find.widgetWithText(OutlinedButton, 'Attach receipt photo'),
      );
      await tester.tap(find.text('Take photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Reading receipt'), findsOneWidget);

      receiptReader.gate?.complete();
      await tester.pumpAndSettle();

      expect(find.text('Reading receipt'), findsNothing);
    });

    testWidgets('says so when nothing could be read', (tester) async {
      await pumpReady(tester);

      await attachPhoto(tester);

      expect(
        find.text('Nothing could be read from the receipt. Fill it in by hand'),
        findsOneWidget,
      );
    });

    testWidgets('matching a line keeps its receipt wording', (tester) async {
      final rice = testItem(id: 'rice', name: 'Rice');
      receiptReader.result = Ok(reading);
      await pumpReady(tester, catalogue: [rice]);
      await attachPhoto(tester);

      await _tap(tester, find.text('RISO ARBORIO'));
      await _tap(tester, find.byType(DropdownButtonFormField<Object>));
      await _tap(tester, find.text('Rice').last);
      await _tap(tester, find.widgetWithText(FilledButton, 'Save line'));

      expect(find.textContaining('Not matched'), findsNothing);
      final line = (cubit.state as RecordPurchaseReady).draft.lines.single;
      expect(line.item, rice);
      expect(line.scannedText, 'RISO ARBORIO');
      expect(line.lineTotal, 1.80);
    });

    testWidgets('an unmatched line can be removed', (tester) async {
      receiptReader.result = Ok(reading);
      await pumpReady(tester);
      await attachPhoto(tester);

      await _tap(tester, find.byTooltip('Remove line'));

      expect(find.text('RISO ARBORIO'), findsNothing);
    });
  });
}
