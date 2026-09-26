import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/core/widgets/form_controls.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';
import 'package:grocery_accounting/features/purchases/presentation/line_sheet.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_cubit.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_page.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_state.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_alias.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';
import 'package:grocery_accounting/features/receipts/presentation/receipt_photo_page.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../receipts/fake_receipts.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';
import '../fake_purchase_repository.dart';

final _now = DateTime(2026, 9, 21, 18, 30);

/// Labels sit above their fields, so a field is found through its label.
Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)),
  matching: find.byType(TextField),
);

/// A text inside the line sheet, where the screen behind may show it too.
Finder _inSheet(String text) =>
    find.descendant(of: find.byType(LineSheet), matching: find.text(text));

/// Money as the screen formats it, with the non-breaking space before the
/// symbol.
String _euro(String amount) => '$amount €';

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
  late FakeAliasRepository aliases;

  setUp(() {
    receiptPicker = FakeReceiptPicker();
    receipts = FakeReceiptStore();
    receiptReader = FakeReceiptReader();
    aliases = FakeAliasRepository();
    purchases = FakePurchaseRepository();
    items = FakeItemRepository();
    members = FakeMemberRepository();
  });

  RecordPurchaseCubit buildCubit() {
    // Built inside the test, not in setUp: a cubit created outside the test's
    // fake-async zone never delivers its stream events to the pump loop.
    final built = RecordPurchaseCubit(
      purchases: purchases,
      items: items,
      members: members,
      shoppingList: FakeShoppingListRepository(),
      receiptPicker: receiptPicker,
      receipts: receipts,
      receiptReader: receiptReader,
      aliases: aliases,
      currentUser: testUser,
      now: () => _now,
    );
    addTearDown(built.close);
    return built;
  }

  /// The screen on its own route over a home screen, so closing it can be
  /// seen.
  Future<void> pump(WidgetTester tester) async {
    // Phone width, where a row or a field is most likely to overflow, and
    // tall enough that the lines below the details are built.
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    cubit = buildCubit();

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
    await tester.tap(find.text('open'));
    // The screen spins until both collections report, so it never settles
    // before they do.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
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

  Future<void> save(WidgetTester tester) =>
      _tap(tester, find.widgetWithText(FilledButton, 'Save purchase'));

  Future<void> openAddLine(WidgetTester tester) =>
      _tap(tester, find.widgetWithText(TextButton, 'Add line'));

  /// Drives the line sheet the way a member would: pick the item, type the
  /// quantity and the price, confirm.
  Future<void> addLine(
    WidgetTester tester, {
    required String item,
    String quantity = '1',
    String lineTotal = '2,40',
  }) async {
    await openAddLine(tester);
    await _tap(tester, _inSheet(item));
    await tester.enterText(_field('Quantity'), quantity);
    await tester.enterText(_field('Line total'), lineTotal);
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));
  }

  group('before the collections report', () {
    testWidgets('waits rather than showing an empty form', (tester) async {
      await pump(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Shop'), findsNothing);
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

  group('the details', () {
    testWidgets('show the date, the fields, the payer and no lines yet', (
      tester,
    ) async {
      await pumpReady(tester, household: [testMember()]);

      expect(find.text('Review purchase'), findsOneWidget);
      expect(find.text('No receipt photo'), findsOneWidget);
      expect(find.text('21/09/2026'), findsOneWidget);
      expect(_field('Shop'), findsOneWidget);
      expect(_field('Total'), findsOneWidget);
      // The payer defaults to the signed-in member.
      expect(find.text('Paid by'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('rahat')),
        matchesSemantics(
          label: 'rahat',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      expect(
        find.text('No lines yet. The spend is recorded either way.'),
        findsOneWidget,
      );
    });

    testWidgets('send what is typed to the draft', (tester) async {
      await pumpReady(tester);
      await fillHeader(tester);

      expect(find.text(_euro('43,20')), findsOneWidget);
      expect(purchases.committed, isEmpty);
      await save(tester);

      expect(purchases.committed.single.shopName, 'Conad');
      expect(purchases.committed.single.totalText, '43,20');
      expect(purchases.committed.single.paidByUserId, testUser.uid);
    });

    testWidgets('a payer chip chooses who paid', (tester) async {
      await pumpReady(
        tester,
        household: [
          testMember(),
          testMember(id: 'zoe', displayName: 'Zoe'),
        ],
      );

      await _tap(tester, find.text('Zoe'));

      expect((cubit.state as RecordPurchaseReady).draft.paidByUserId, 'zoe');
    });

    testWidgets('refuse to save an empty form, field by field', (tester) async {
      await pumpReady(tester);

      await save(tester);

      expect(find.text('Enter a shop'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(purchases.committed, isEmpty);
    });

    testWidgets('refuse a total of zero', (tester) async {
      await pumpReady(tester);
      await tester.enterText(_field('Shop'), 'Lidl');
      await tester.enterText(_field('Total'), '0');
      await tester.pumpAndSettle();

      await save(tester);

      expect(find.text('Enter an amount greater than zero'), findsOneWidget);
      expect(purchases.committed, isEmpty);
    });

    testWidgets('open a date picker on the date field', (tester) async {
      await pumpReady(tester);

      await _tap(tester, find.text('21/09/2026'));

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('lines', () {
    testWidgets('are added through the sheet and shown against the total', (
      tester,
    ) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await fillHeader(tester);

      await openAddLine(tester);
      expect(find.byType(LineSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await addLine(tester, item: 'Rice');

      expect(find.byType(LineSheet), findsNothing);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('1 kg'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Matched\nRice')), findsOneWidget);
      // The lines against the receipt total, which are allowed to differ.
      expect(find.text('Lines add up to'), findsOneWidget);
      expect(find.text(_euro('2,40')), findsNWidgets(2));
      expect(
        find.textContaining('less than the receipt, usually a line that was'),
        findsOneWidget,
      );
    });

    testWidgets('can create an item that is not in the pantry yet', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      await openAddLine(tester);
      await tester.enterText(_field('Pantry item'), 'passata');
      await tester.pumpAndSettle();
      await _tap(tester, _inSheet('Create “Passata”'));

      expect(find.text('New pantry item'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Name')).controller?.text,
        'Passata',
      );
      await _tap(tester, _inSheet('Pantry & Dry Goods'));
      await tester.enterText(_field('Quantity'), '2');
      await tester.enterText(_field('Line total'), '1,80');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(find.text('Passata'), findsOneWidget);
      expect(find.text('2 kg · new pantry item'), findsOneWidget);

      await save(tester);

      final line = purchases.committed.single.lines.single;
      expect(line.item?.id, isEmpty);
      expect(line.item?.name, 'Passata');
      expect(line.item?.category, 'pantry');
      expect(line.item?.dailyUsage, 0);
      expect(line.quantity, 2);
      expect(line.lineTotal, 1.80);
    });

    testWidgets('refuse a new item with no name or category', (tester) async {
      await pumpReady(tester);

      await openAddLine(tester);
      await _tap(tester, _inSheet('Create a new item'));
      await tester.enterText(_field('Quantity'), '1');
      await tester.enterText(_field('Line total'), '1');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(find.byType(LineSheet), findsOneWidget);
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Choose a category'), findsOneWidget);
    });

    testWidgets('refuse to create an item the pantry already has', (
      tester,
    ) async {
      await pumpReady(tester, catalogue: [testItem(name: 'Rice')]);

      await openAddLine(tester);
      await _tap(tester, _inSheet('Create a new item'));
      await tester.enterText(_field('Name'), ' rice ');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(
        find.text('Already in the pantry. Pick it from the list'),
        findsOneWidget,
      );
    });

    testWidgets('going back from a new item returns to the search', (
      tester,
    ) async {
      await pumpReady(tester, catalogue: [testItem(name: 'Rice')]);

      await openAddLine(tester);
      await _tap(tester, _inSheet('Create a new item'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Back'));

      expect(_field('Pantry item'), findsOneWidget);
      expect(_inSheet('Rice'), findsOneWidget);
    });

    testWidgets('refuse a line with no item chosen', (tester) async {
      await pumpReady(tester, catalogue: [testItem(name: 'Rice')]);

      await openAddLine(tester);
      await tester.enterText(_field('Quantity'), '1');
      await tester.enterText(_field('Line total'), '1');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(find.text('Choose an item'), findsOneWidget);
      expect(find.byType(LineSheet), findsOneWidget);
    });

    testWidgets('are edited by tapping the row', (tester) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await fillHeader(tester);
      await addLine(tester, item: 'Rice');

      await _tap(tester, find.text('Rice'));
      expect(find.text('Edit line'), findsOneWidget);

      await tester.enterText(_field('Quantity'), '3');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilledButton, 'Save line'));

      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('1 kg'), findsNothing);
    });

    testWidgets('are swiped away', (tester) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await addLine(tester, item: 'Rice');

      await tester.drag(find.text('Rice'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Rice'), findsNothing);
      expect(
        find.text('No lines yet. The spend is recorded either way.'),
        findsOneWidget,
      );
    });

    testWidgets('are removed from the sheet', (tester) async {
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      await addLine(tester, item: 'Rice');

      await _tap(tester, find.text('Rice'));
      await _tap(tester, find.widgetWithText(TextButton, 'Remove line'));

      expect((cubit.state as RecordPurchaseReady).draft.lines, isEmpty);
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

    testWidgets('ends on what the save did, and Done closes it', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      await save(tester);

      expect(find.text('Purchase saved'), findsOneWidget);
      expect(
        find.text('${_euro('43,20')} at Conad, paid by Rahat'),
        findsOneWidget,
      );
      expect(find.text('Spend recorded'), findsOneWidget);

      await _tap(tester, find.widgetWithText(FilledButton, 'Done'));

      expect(find.byType(RecordPurchaseView), findsNothing);
      expect(find.text('open'), findsOneWidget);
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

      expect(find.text('Purchase saved'), findsOneWidget);
      purchases.writeGate?.complete();
    });

    testWidgets('stays open with the mapped message when refused', (
      tester,
    ) async {
      purchases.commitResult = const Err(PermissionDenied());
      await pumpReady(tester);
      await fillHeader(tester);

      await save(tester);

      expect(find.text('Review purchase'), findsOneWidget);
      expect(find.text('You do not have access to this data'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
    });

    testWidgets('shows a draft problem no single field can show', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      // Nothing on the screen can clear the payer. A draft that reaches the
      // commit without one still has to say so rather than failing quietly.
      cubit.setPaidByUserId('');
      await tester.pumpAndSettle();

      await save(tester);

      expect(find.text('Choose who paid'), findsOneWidget);
      expect(purchases.committed, isEmpty);
    });

    testWidgets('clears the message once the member edits the form', (
      tester,
    ) async {
      purchases.commitResult = const Err(PermissionDenied());
      await pumpReady(tester);
      await fillHeader(tester);
      await save(tester);
      expect(find.text('You do not have access to this data'), findsOneWidget);

      await tester.enterText(_field('Shop'), 'Lidl');
      await tester.pumpAndSettle();

      expect(find.text('You do not have access to this data'), findsNothing);
    });
  });

  group('receipt photo', () {
    Future<void> attachFrom(WidgetTester tester, String source) async {
      await _tap(tester, find.widgetWithText(FilledButton, 'Add photo'));
      await _tap(tester, find.text(source));
    }

    testWidgets('attaches a photo from the camera or the gallery', (
      tester,
    ) async {
      await pumpReady(tester);

      await attachFrom(tester, 'Take a photo');

      expect(receiptPicker.sources, [ReceiptSource.camera]);
      expect(find.text('Receipt read'), findsOneWidget);
      expect(
        find.text('Nothing could be read. Fill it in by hand'),
        findsOneWidget,
      );
      expect(find.byTooltip('View receipt photo'), findsOneWidget);
    });

    testWidgets('a photo added to a filled-in draft is kept, not read', (
      tester,
    ) async {
      await pumpReady(tester);
      await fillHeader(tester);

      await attachFrom(tester, 'Choose from gallery');

      expect(receiptReader.reads, isEmpty);
      expect(find.text('Receipt attached'), findsOneWidget);
    });

    testWidgets('replaces the photo, and removes it from the photo view', (
      tester,
    ) async {
      await pumpReady(tester);
      await attachFrom(tester, 'Choose from gallery');
      final first = (cubit.state as RecordPurchaseReady).draft.receipt;

      receiptPicker.result = Ok(testPhoto(9));
      await _tap(tester, find.widgetWithText(FilledButton, 'Replace'));
      await _tap(tester, find.text('Choose from gallery'));

      final second = (cubit.state as RecordPurchaseReady).draft.receipt;
      expect(second, isNotNull);
      expect(identical(first, second), isFalse);

      await _tap(tester, find.byTooltip('View receipt photo'));
      expect(find.byType(ReceiptPhotoPage), findsOneWidget);
      await _tap(tester, find.byTooltip('Remove photo'));

      expect(find.byType(ReceiptPhotoPage), findsNothing);
      expect((cubit.state as RecordPurchaseReady).draft.receipt, isNull);
      expect(find.text('No receipt photo'), findsOneWidget);
    });

    testWidgets('dismissing the photo sheet attaches nothing', (tester) async {
      await pumpReady(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Add photo'));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(receiptPicker.sources, isEmpty);
      expect(find.text('No receipt photo'), findsOneWidget);
    });

    testWidgets('a denied pick says why and attaches nothing', (tester) async {
      receiptPicker.result = const Err(ReceiptAccessDenied());
      await pumpReady(tester);

      await attachFrom(tester, 'Take a photo');

      expect(find.text(const ReceiptAccessDenied().message), findsOneWidget);
      expect(find.text('No receipt photo'), findsOneWidget);
    });

    testWidgets('a photo that could not be kept shows on the summary', (
      tester,
    ) async {
      receipts.keepResult = const Err(ConnectionUnavailable());
      await pumpReady(tester);
      await fillHeader(tester);
      await attachFrom(tester, 'Take a photo');

      await save(tester);

      expect(find.text('Purchase saved'), findsOneWidget);
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text(const ConnectionUnavailable().message), findsOneWidget);
    });

    testWidgets('a photo still queued says it uploads when online', (
      tester,
    ) async {
      receipts.queued.add('new1');
      await pumpReady(tester);
      await fillHeader(tester);
      await attachFrom(tester, 'Take a photo');

      await save(tester);

      expect(find.text('Uploads when online'), findsOneWidget);
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
      await _tap(tester, find.widgetWithText(FilledButton, 'Add photo'));
      await _tap(tester, find.text('Take a photo'));
    }

    testWidgets('shows that it is reading, then what it found', (tester) async {
      receiptReader.gate = Completer<void>();
      receiptReader.result = Ok(reading);
      await pumpReady(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Add photo'));
      await tester.tap(find.text('Take a photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Reading receipt...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save purchase'),
            )
            .onPressed,
        isNull,
      );

      receiptReader.gate?.complete();
      await tester.pumpAndSettle();

      expect(find.text('Reading receipt...'), findsNothing);
      expect(find.text('Receipt read'), findsOneWidget);
      expect(find.text('Total, date and 1 line found'), findsOneWidget);
    });

    testWidgets('prefills the details and lists the lines to match', (
      tester,
    ) async {
      receiptReader.result = Ok(reading);
      await pumpReady(tester);

      await attachPhoto(tester);

      expect(
        tester.widget<TextField>(_field('Total')).controller?.text,
        '5,48',
      );
      expect(find.text('20/09/2026'), findsOneWidget);
      expect(find.text('To match'), findsOneWidget);
      expect(find.text('RISO ARBORIO'), findsOneWidget);
      expect(find.text('Not matched · 1 kg'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Match'), findsOneWidget);
      // Filling the total in is not the member typing, so the empty shop is
      // not flagged yet.
      expect(find.text('Enter a shop'), findsNothing);
    });

    testWidgets('matching a line keeps its wording and says what it teaches', (
      tester,
    ) async {
      final rice = testItem(id: 'rice', name: 'Rice');
      receiptReader.result = Ok(reading);
      await pumpReady(tester, catalogue: [rice]);
      await attachPhoto(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Match'));
      expect(find.text('Match this line'), findsOneWidget);
      expect(_inSheet('RISO ARBORIO'), findsOneWidget);

      await _tap(tester, _inSheet('Rice'));
      expect(
        find.text('From now on, RISO ARBORIO becomes 1 kg of Rice by itself.'),
        findsOneWidget,
      );
      await _tap(tester, find.widgetWithText(FilledButton, 'Match line'));

      expect(find.text('To match'), findsNothing);
      expect(find.text('1 kg · RISO ARBORIO'), findsOneWidget);
      final line = (cubit.state as RecordPurchaseReady).draft.lines.single;
      expect(line.item, rice);
      expect(line.scannedText, 'RISO ARBORIO');
      expect(line.lineTotal, 1.80);
      expect(line.learned, isFalse);
    });

    testWidgets('a line matched by what was learned says so', (tester) async {
      receiptReader.result = Ok(reading);
      await pumpReady(
        tester,
        catalogue: [testItem(id: 'rice', name: 'Rice')],
      );
      aliases.emitAliases([
        ReceiptAlias(
          rawTextNormalized: normalizeReceiptText('RISO ARBORIO'),
          itemId: 'rice',
          defaultQuantity: 1,
          defaultUnit: ItemUnit.kg,
          shopName: null,
        ),
      ]);
      await tester.pump();

      await attachPhoto(tester);

      expect(find.text('To match'), findsNothing);
      expect(find.text('1 kg · learned from RISO ARBORIO'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Learned\nRice')), findsOneWidget);
    });

    testWidgets('a new item from a receipt line starts from its wording', (
      tester,
    ) async {
      receiptReader.result = const Ok(
        ReceiptReading(
          total: 1.78,
          lines: [
            ScannedLine(
              rawText: 'POMODORI PELATI 400G',
              quantity: 2,
              unit: ItemUnit.pcs,
              lineTotal: 1.78,
            ),
          ],
        ),
      );
      await pumpReady(tester);
      await attachPhoto(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Match'));
      await _tap(tester, _inSheet('Create “Pomodori pelati”'));
      expect(
        tester.widget<TextField>(_field('Line total')).controller?.text,
        '1,78',
      );
      await _tap(tester, _inSheet('Pantry & Dry Goods'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Add line'));

      expect(
        find.text('2 pcs · new pantry item · POMODORI PELATI 400G'),
        findsOneWidget,
      );
    });

    testWidgets('an unmatched line can be swiped away', (tester) async {
      receiptReader.result = Ok(reading);
      await pumpReady(tester);
      await attachPhoto(tester);

      await tester.drag(find.text('RISO ARBORIO'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('RISO ARBORIO'), findsNothing);
      expect(find.text('To match'), findsNothing);
    });
  });
}
