import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/receipt_matching.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_alias.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_cubit.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_state.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_picker.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';
import 'package:grocery_accounting/features/receipts/data/receipt_reader.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../receipts/fake_receipts.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';
import '../fake_purchase_repository.dart';

final _now = DateTime(2026, 9, 21, 18, 30);

/// Records what the cubit reports through `addError`.
class _RecordingObserver extends BlocObserver {
  final reported = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    reported.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  late FakePurchaseRepository purchases;
  late FakeItemRepository items;
  late FakeMemberRepository members;
  late FakeShoppingListRepository shoppingList;
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
    shoppingList = FakeShoppingListRepository();
  });

  RecordPurchaseCubit build() {
    final cubit = RecordPurchaseCubit(
      purchases: purchases,
      items: items,
      members: members,
      shoppingList: shoppingList,
      receiptPicker: receiptPicker,
      receipts: receipts,
      receiptReader: receiptReader,
      aliases: aliases,
      currentUser: testUser,
      now: () => _now,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// A cubit with both collections already reported, which is where every
  /// test about the draft itself starts.
  Future<RecordPurchaseCubit> ready({
    List<dynamic> catalogue = const [],
    List<dynamic> household = const [],
  }) async {
    final cubit = build();
    items.emitItems(catalogue.cast());
    members.emitMembers(household.cast());
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  PurchaseDraft draftOf(RecordPurchaseCubit cubit) =>
      (cubit.state as RecordPurchaseReady).draft;

  group('loading', () {
    test('waits until both collections have reported', () async {
      final cubit = build();
      expect(cubit.state, const RecordPurchaseLoading());

      items.emitItems([testItem()]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const RecordPurchaseLoading());

      members.emitMembers([testMember()]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<RecordPurchaseReady>());
    });

    test('subscribes to both collections once', () async {
      build();
      await Future<void>.delayed(Duration.zero);

      expect(items.watchCalls, 1);
      expect(members.watchCalls, 1);
    });
  });

  group('a ready draft', () {
    test(
      'starts today, with the signed-in member paying and no lines',
      () async {
        final cubit = await ready();
        final draft = draftOf(cubit);

        expect(draft.date, _now);
        expect(draft.paidByUserId, testUser.uid);
        expect(draft.shopName, isEmpty);
        expect(draft.totalText, isEmpty);
        expect(draft.lines, isEmpty);
      },
    );

    test(
      'offers the signed-in member as payer even with no user documents',
      () async {
        final cubit = await ready();
        final state = cubit.state as RecordPurchaseReady;

        expect(state.payers, hasLength(1));
        expect(state.payers.single.id, testUser.uid);
        expect(state.payers.single.displayName, 'rahat');
      },
    );

    test(
      'lists the household without repeating the signed-in member',
      () async {
        final cubit = await ready(
          household: [
            testMember(id: 'zoe', displayName: 'zoe'),
            testMember(id: testUser.uid, displayName: 'rahat'),
          ],
        );
        final state = cubit.state as RecordPurchaseReady;

        expect(state.payers.map((payer) => payer.id), [testUser.uid, 'zoe']);
      },
    );

    test('carries the catalogue for the item picker', () async {
      final cubit = await ready(catalogue: [testItem(name: 'Rice')]);

      expect((cubit.state as RecordPurchaseReady).items, hasLength(1));
    });

    test('takes a later catalogue update', () async {
      final cubit = await ready();

      items.emitItems([testItem(), testItem(id: 'b', name: 'Milk')]);
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as RecordPurchaseReady).items, hasLength(2));
    });

    test('takes a later household update', () async {
      final cubit = await ready();

      members.emitMembers([testMember(id: 'zoe', displayName: 'zoe')]);
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as RecordPurchaseReady).payers, hasLength(2));
    });
  });

  group('editing', () {
    test('keeps what was typed into the header', () async {
      final cubit = await ready();

      cubit.setShopName('Conad');
      cubit.setTotalText('43,20');
      cubit.setPaidByUserId('zoe');
      cubit.setDate(DateTime(2026, 9, 19));

      final draft = draftOf(cubit);
      expect(draft.shopName, 'Conad');
      expect(draft.totalText, '43,20');
      expect(draft.paidByUserId, 'zoe');
      expect(draft.date, DateTime(2026, 9, 19));
    });

    test('adds, changes and removes lines', () async {
      final rice = testItem(id: 'rice', name: 'Rice');
      final cubit = await ready(catalogue: [rice]);

      cubit.addLine(
        PurchaseDraftLine(
          item: rice,
          quantity: 1,
          unit: ItemUnit.kg,
          lineTotal: 2,
        ),
      );
      expect(draftOf(cubit).lines, hasLength(1));

      cubit.updateLine(
        0,
        PurchaseDraftLine(
          item: rice,
          quantity: 2,
          unit: ItemUnit.kg,
          lineTotal: 4,
        ),
      );
      expect(draftOf(cubit).lines.single.quantity, 2);
      expect(draftOf(cubit).linesTotal, 4);

      cubit.removeLine(0);
      expect(draftOf(cubit).lines, isEmpty);
    });

    test('ignores a line index that is not there', () async {
      final cubit = await ready();
      final before = draftOf(cubit);

      cubit.removeLine(0);
      cubit.updateLine(
        3,
        PurchaseDraftLine(
          item: testItem(),
          quantity: 1,
          unit: ItemUnit.kg,
          lineTotal: 1,
        ),
      );

      expect(draftOf(cubit), before);
    });

    test('does not leave the loading state before the collections report', () {
      final cubit = build();

      cubit.setShopName('Conad');

      expect(cubit.state, const RecordPurchaseLoading());
    });
  });

  group('a stream failure', () {
    test('from the catalogue becomes a failure state', () async {
      final cubit = await ready();

      items.emitError(const ConnectionUnavailable());
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const RecordPurchaseFailure(ConnectionUnavailable()));
    });

    test('from the household becomes a failure state', () async {
      final cubit = await ready();

      members.emitError(const PermissionDenied());
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const RecordPurchaseFailure(PermissionDenied()));
    });

    test('that is not a DataFailure still renders', () async {
      final cubit = await ready();

      items.emitError(StateError('nothing to do with Firestore'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const RecordPurchaseFailure(UnexpectedDataFailure()));
    });

    test('is recovered by retry, which resubscribes to both', () async {
      final cubit = await ready();
      cubit.setShopName('Conad');

      items.emitError(const ConnectionUnavailable());
      await Future<void>.delayed(Duration.zero);

      cubit.retry();
      expect(cubit.state, const RecordPurchaseLoading());
      expect(items.watchCalls, 2);
      expect(members.watchCalls, 2);

      items.emitItems([]);
      members.emitMembers([]);
      await Future<void>.delayed(Duration.zero);

      // What was typed survives the reconnection.
      expect(draftOf(cubit).shopName, 'Conad');
    });
  });

  group('commit', () {
    Future<RecordPurchaseCubit> filledIn() async {
      final cubit = await ready(catalogue: [testItem(id: 'rice')]);
      cubit.setShopName('Conad');
      cubit.setTotalText('43,20');
      return cubit;
    }

    test('refuses a draft with no shop', () async {
      final cubit = await filledIn();
      cubit.setShopName('  ');

      expect(await cubit.commit(), const CommitInvalid('Enter a shop'));
      expect(purchases.committed, isEmpty);
    });

    test('refuses a draft with no total', () async {
      final cubit = await filledIn();
      cubit.setTotalText('');

      expect(await cubit.commit(), const CommitInvalid('Enter an amount'));
    });

    test('refuses a total of zero', () async {
      final cubit = await filledIn();
      cubit.setTotalText('0');

      expect(
        await cubit.commit(),
        const CommitInvalid('Enter an amount greater than zero'),
      );
    });

    test('refuses a draft with nobody paying', () async {
      final cubit = await filledIn();
      cubit.setPaidByUserId('');

      expect(await cubit.commit(), const CommitInvalid('Choose who paid'));
    });

    test('refuses a purchase dated in the future', () async {
      final cubit = await filledIn();
      cubit.setDate(_now.add(const Duration(days: 1)));

      expect(
        await cubit.commit(),
        const CommitInvalid('A purchase cannot be in the future'),
      );
    });

    test('refuses a line that cannot restock its item', () async {
      final cubit = await filledIn();
      cubit.addLine(
        PurchaseDraftLine(
          item: testItem(id: 'rice', name: 'Rice'),
          quantity: 2,
          unit: ItemUnit.pcs,
          lineTotal: 3,
        ),
      );

      expect(
        await cubit.commit(),
        const CommitInvalid('Rice cannot be measured in pcs'),
      );
      expect(purchases.committed, isEmpty);
    });

    test('writes the draft with the injected clock', () async {
      final cubit = await filledIn();
      final rice = testItem(id: 'rice', name: 'Rice');
      cubit.addLine(
        PurchaseDraftLine(
          item: rice,
          quantity: 1,
          unit: ItemUnit.kg,
          lineTotal: 2.4,
        ),
      );

      expect(await cubit.commit(), const CommitSucceeded());
      expect(purchases.committed.single.shopName, 'Conad');
      expect(purchases.committed.single.lines.single.item, rice);
      expect(purchases.commitClocks.single, _now);
    });

    test(
      'commits a purchase with no lines, which records spend only',
      () async {
        final cubit = await filledIn();

        expect(await cubit.commit(), const CommitSucceeded());
        expect(purchases.committed.single.lines, isEmpty);
      },
    );

    test('hands back a refusal as the mapped failure', () async {
      final cubit = await filledIn();
      purchases.commitResult = const Err(PermissionDenied());

      expect(await cubit.commit(), const CommitFailed(PermissionDenied()));
    });

    test('turns an unmapped error into the unexpected failure', () async {
      final cubit = await filledIn();
      purchases.commitThrows = StateError('nothing to do with Firestore');

      expect(await cubit.commit(), const CommitFailed(UnexpectedDataFailure()));
    });
  });

  test('close cancels every subscription', () async {
    final cubit = RecordPurchaseCubit(
      purchases: purchases,
      items: items,
      members: members,
      shoppingList: shoppingList,
      receiptPicker: receiptPicker,
      receipts: receipts,
      receiptReader: receiptReader,
      aliases: aliases,
      currentUser: testUser,
      now: () => _now,
    );
    await Future<void>.delayed(Duration.zero);
    expect(items.hasListener, isTrue);
    expect(members.hasListener, isTrue);
    expect(shoppingList.hasListener, isTrue);

    await cubit.close();

    expect(items.hasListener, isFalse);
    expect(members.hasListener, isFalse);
    expect(shoppingList.hasListener, isFalse);
  });

  group('clearing the shopping list', () {
    PurchaseDraftLine lineFor(Item item) => PurchaseDraftLine(
      item: item,
      quantity: 1,
      unit: ItemUnit.kg,
      lineTotal: 2,
    );

    Future<RecordPurchaseCubit> filledIn() async {
      final cubit = await ready();
      cubit.setShopName('Conad');
      cubit.setTotalText('10');
      return cubit;
    }

    test('passes the entries the purchase covers', () async {
      final cubit = await filledIn();
      shoppingList.emitEntries([
        testEntry(id: 'linked', text: 'Basmati', itemId: 'rice'),
        testEntry(id: 'named', text: 'bread'),
        testEntry(id: 'other', text: 'Eggs'),
      ]);
      await Future<void>.delayed(Duration.zero);
      cubit.addLine(lineFor(testItem(id: 'rice', name: 'Rice')));
      cubit.addLine(lineFor(newTestItem(name: 'Bread')));

      expect(await cubit.commit(), const CommitSucceeded());
      expect(purchases.clearedEntryIds.single, {'linked', 'named'});
    });

    test('passes nothing when nothing matches', () async {
      final cubit = await filledIn();
      shoppingList.emitEntries([testEntry(id: 'e1', text: 'Eggs')]);
      await Future<void>.delayed(Duration.zero);
      cubit.addLine(lineFor(testItem(id: 'rice', name: 'Rice')));

      await cubit.commit();

      expect(purchases.clearedEntryIds.single, isEmpty);
    });

    test('passes nothing before the list has reported', () async {
      final cubit = await filledIn();
      cubit.addLine(lineFor(testItem(id: 'rice', name: 'Rice')));

      expect(await cubit.commit(), const CommitSucceeded());
      expect(purchases.clearedEntryIds.single, isEmpty);
    });

    test('a list failure neither blocks nor fails the screen', () async {
      final cubit = build();
      shoppingList.emitError(const ConnectionUnavailable());
      items.emitItems(const []);
      members.emitMembers(const []);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<RecordPurchaseReady>());

      cubit.setShopName('Conad');
      cubit.setTotalText('10');
      cubit.addLine(lineFor(testItem(id: 'rice', name: 'Rice')));

      expect(await cubit.commit(), const CommitSucceeded());
      expect(purchases.clearedEntryIds.single, isEmpty);
    });

    test('a list failure after it reported clears nothing', () async {
      final cubit = await filledIn();
      shoppingList.emitEntries([testEntry(id: 'e1', text: 'Rice')]);
      await Future<void>.delayed(Duration.zero);
      shoppingList.emitError(const ConnectionUnavailable());
      await Future<void>.delayed(Duration.zero);
      cubit.addLine(lineFor(testItem(id: 'rice', name: 'Rice')));

      await cubit.commit();

      expect(cubit.state, isA<RecordPurchaseReady>());
      expect(purchases.clearedEntryIds.single, isEmpty);
    });

    test('retry listens to the list again', () async {
      final cubit = build();

      cubit.retry();

      expect(shoppingList.watchCalls, 2);
    });
  });

  group('receipt photo', () {
    Future<RecordPurchaseCubit> filledIn() async {
      final cubit = await ready();
      cubit.setShopName('Conad');
      cubit.setTotalText('10');
      return cubit;
    }

    test('a purchase with no photo keeps nothing and writes no path', () async {
      final cubit = await filledIn();

      expect(await cubit.commit(), const CommitSucceeded());
      expect(receipts.kept, isEmpty);
      expect(purchases.receiptPaths.single, isNull);
      expect(purchases.commitIds.single, 'new1');
      await pumpEventQueue();
      expect(receipts.flushes, 0);
    });

    test('attach, replace and remove change the draft', () async {
      final cubit = await filledIn();
      final first = testPhoto(1);
      final second = testPhoto(2);

      cubit.attachReceipt(first);
      expect(draftOf(cubit).receipt, same(first));

      cubit.attachReceipt(second);
      expect(draftOf(cubit).receipt, same(second));

      cubit.removeReceipt();
      expect(draftOf(cubit).receipt, isNull);
    });

    test('keeps the photo under the purchase id, commits its path, then '
        'uploads', () async {
      final cubit = await filledIn();
      final photo = testPhoto();
      cubit.attachReceipt(photo);

      expect(await cubit.commit(), const CommitSucceeded());
      expect(receipts.kept.single.purchaseId, 'new1');
      expect(receipts.kept.single.photo, same(photo));
      expect(purchases.commitIds.single, 'new1');
      expect(purchases.receiptPaths.single, 'receipts/new1');
      await pumpEventQueue();
      expect(receipts.flushes, 1);
    });

    test('a photo that cannot be kept saves without it and says why', () async {
      final cubit = await filledIn();
      cubit.attachReceipt(testPhoto());
      receipts.keepResult = const Err(ConnectionUnavailable());

      expect(
        await cubit.commit(),
        const CommitSucceeded(receiptSkipped: ConnectionUnavailable()),
      );
      expect(purchases.receiptPaths.single, isNull);
      expect(receipts.discarded, isEmpty);
    });

    test('a refused purchase discards its kept photo', () async {
      final cubit = await filledIn();
      cubit.attachReceipt(testPhoto());
      purchases.commitResult = const Err(PermissionDenied());

      expect(await cubit.commit(), const CommitFailed(PermissionDenied()));
      expect(receipts.discarded, ['new1']);
      await pumpEventQueue();
      expect(receipts.flushes, 0);
    });

    test('a thrown commit discards the photo and is reported', () async {
      final cubit = await filledIn();
      cubit.attachReceipt(testPhoto());
      purchases.commitThrows = StateError('boom');

      expect(await cubit.commit(), const CommitFailed(UnexpectedDataFailure()));
      expect(receipts.discarded, ['new1']);
    });

    test('a commit still pending after the window counts as saved', () async {
      final cubit = await filledIn();
      cubit.attachReceipt(testPhoto());
      purchases.writeGate = Completer<void>();

      expect(await cubit.commit(), const CommitSucceeded());
      await pumpEventQueue();
      expect(receipts.flushes, 1);

      purchases.writeGate?.complete();
    });

    test('a failed upload after saving is reported, not thrown', () async {
      final observer = _RecordingObserver();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = _RecordingObserver());
      final cubit = await filledIn();
      cubit.attachReceipt(testPhoto());
      final thrown = StateError('disk');
      receipts.flushThrows = thrown;

      expect(await cubit.commit(), const CommitSucceeded());
      await pumpEventQueue();
      expect(receipts.flushes, 1);
      expect(observer.reported, [thrown]);
    });
  });

  group('picking a receipt', () {
    test('attaches the picked photo', () async {
      final cubit = await ready();
      final photo = testPhoto(3);
      receiptPicker.result = Ok(photo);

      expect(
        await cubit.pickReceipt(ReceiptSource.camera),
        const ReceiptPicked(
          notice: 'Nothing could be read from the receipt. Fill it in by hand',
        ),
      );
      expect(receiptPicker.sources, [ReceiptSource.camera]);
      expect(draftOf(cubit).receipt, same(photo));
    });

    test('a cancel changes nothing', () async {
      final cubit = await ready();
      receiptPicker.result = const Ok(null);

      expect(
        await cubit.pickReceipt(ReceiptSource.gallery),
        const ReceiptPickCancelled(),
      );
      expect(draftOf(cubit).receipt, isNull);
    });

    test('a denied permission is refused with its message', () async {
      final cubit = await ready();
      receiptPicker.result = const Err(ReceiptAccessDenied());

      expect(
        await cubit.pickReceipt(ReceiptSource.camera),
        ReceiptPickRefused(const ReceiptAccessDenied().message),
      );
    });

    test('an unexpected picker failure is refused and reported', () async {
      final observer = _RecordingObserver();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = _RecordingObserver());
      final cubit = await ready();
      final cause = StateError('boom');
      receiptPicker.result = Err(
        ReceiptPickerUnavailable(cause, StackTrace.empty),
      );

      final outcome = await cubit.pickReceipt(ReceiptSource.camera);

      expect(observer.reported, [cause]);

      expect(
        outcome,
        const ReceiptPickRefused('Could not open the camera or gallery'),
      );
    });
  });

  group('reading a receipt', () {
    final reading = ReceiptReading(
      total: 5.48,
      date: DateTime(2026, 9, 20),
      lines: const [
        ScannedLine(
          rawText: 'YOGURT BIANCO',
          quantity: 2,
          unit: ItemUnit.pcs,
          lineTotal: 2.58,
        ),
        ScannedLine(
          rawText: 'MELE GOLDEN',
          quantity: 0.45,
          unit: ItemUnit.kg,
          lineTotal: 2.90,
        ),
      ],
    );

    test('prefills a fresh draft with unmatched lines', () async {
      final cubit = await ready();
      receiptReader.result = Ok(reading);

      final outcome = await cubit.pickReceipt(ReceiptSource.camera);

      expect(outcome, const ReceiptPicked());
      final draft = draftOf(cubit);
      expect(draft.totalText, '5,48');
      expect(draft.date, DateTime(2026, 9, 20));
      expect(draft.scanned, isTrue);
      expect(draft.lines.map((l) => l.scannedText), [
        'YOGURT BIANCO',
        'MELE GOLDEN',
      ]);
      expect(draft.lines.every((l) => !l.isMatched), isTrue);
      expect(draft.lines.last.unit, ItemUnit.kg);
      expect(receiptReader.reads.single, same(draft.receipt));
    });

    test('does not read a draft that already has a total', () async {
      final cubit = await ready();
      cubit.setTotalText('9,99');
      receiptReader.result = Ok(reading);

      final outcome = await cubit.pickReceipt(ReceiptSource.gallery);

      expect(outcome, const ReceiptPicked());
      expect(receiptReader.reads, isEmpty);
      expect(draftOf(cubit).totalText, '9,99');
      expect(draftOf(cubit).scanned, isFalse);
    });

    test('does not read a draft that already has lines', () async {
      final cubit = await ready();
      cubit.addLine(
        PurchaseDraftLine(
          item: testItem(),
          quantity: 1,
          unit: ItemUnit.kg,
          lineTotal: 1,
        ),
      );

      await cubit.pickReceipt(ReceiptSource.gallery);

      expect(receiptReader.reads, isEmpty);
      expect(draftOf(cubit).lines, hasLength(1));
    });

    test('keeps a date the member chose', () async {
      final cubit = await ready();
      cubit.setDate(DateTime(2026, 9, 18));
      receiptReader.result = Ok(reading);

      await cubit.pickReceipt(ReceiptSource.camera);

      expect(draftOf(cubit).date, DateTime(2026, 9, 18));
      expect(draftOf(cubit).totalText, '5,48');
    });

    test('says so when nothing could be read', () async {
      final cubit = await ready();

      final outcome = await cubit.pickReceipt(ReceiptSource.camera);

      expect(
        outcome,
        const ReceiptPicked(
          notice: 'Nothing could be read from the receipt. Fill it in by hand',
        ),
      );
      expect(draftOf(cubit).scanned, isFalse);
      expect(draftOf(cubit).receipt, isNotNull);
    });

    test('a failed read keeps the photo, says so and is reported', () async {
      final observer = _RecordingObserver();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = _RecordingObserver());
      final cubit = await ready();
      final cause = StateError('ml kit');
      receiptReader.result = Err(ReceiptReadFailure(cause, StackTrace.empty));

      final outcome = await cubit.pickReceipt(ReceiptSource.camera);

      expect(
        outcome,
        const ReceiptPicked(
          notice: 'Could not read the receipt. Fill it in by hand',
        ),
      );
      expect(observer.reported, [cause]);
      expect(draftOf(cubit).receipt, isNotNull);
      expect(draftOf(cubit).lines, isEmpty);
    });

    test('shows it is reading while the read runs', () async {
      final cubit = await ready();
      receiptReader.gate = Completer<void>();
      receiptReader.result = Ok(reading);

      final picking = cubit.pickReceipt(ReceiptSource.camera);
      await pumpEventQueue();

      expect((cubit.state as RecordPurchaseReady).reading, isTrue);

      receiptReader.gate?.complete();
      await picking;

      expect((cubit.state as RecordPurchaseReady).reading, isFalse);
    });

    test('a photo removed during the read is not applied', () async {
      final cubit = await ready();
      receiptReader.gate = Completer<void>();
      receiptReader.result = Ok(reading);

      final picking = cubit.pickReceipt(ReceiptSource.camera);
      await pumpEventQueue();
      cubit.removeReceipt();
      receiptReader.gate?.complete();
      await picking;

      expect(draftOf(cubit).lines, isEmpty);
      expect(draftOf(cubit).totalText, isEmpty);
    });

    test('saves a read purchase with its unmatched lines', () async {
      final cubit = await ready();
      receiptReader.result = Ok(reading);
      await cubit.pickReceipt(ReceiptSource.camera);
      cubit.setShopName('Conad');

      expect(await cubit.commit(), const CommitSucceeded());
      final committed = purchases.committed.single;
      expect(committed.scanned, isTrue);
      expect(committed.lines.where((l) => !l.isMatched), hasLength(2));
    });
  });

  group('learned receipt mapping', () {
    final eggs = testItem(id: 'eggs', name: 'Eggs', unit: ItemUnit.pcs);
    const eggsAlias = ReceiptAlias(
      rawTextNormalized: 'UOVA FRESCHE',
      itemId: 'eggs',
      defaultQuantity: 6,
      defaultUnit: ItemUnit.pcs,
      shopName: 'Conad',
    );
    const reading = ReceiptReading(
      lines: [
        ScannedLine(
          rawText: 'UOVA FRESCHE',
          quantity: 1,
          unit: ItemUnit.pcs,
          lineTotal: 2.99,
        ),
        ScannedLine(
          rawText: 'LATTE PS',
          quantity: 1,
          unit: ItemUnit.pcs,
          lineTotal: 1.29,
        ),
      ],
    );

    test('a known wording arrives matched, an unknown one does not', () async {
      final cubit = await ready(catalogue: [eggs]);
      aliases.emitAliases([eggsAlias]);
      await pumpEventQueue();
      receiptReader.result = const Ok(reading);

      await cubit.pickReceipt(ReceiptSource.camera);

      final lines = draftOf(cubit).lines;
      expect(lines.first.item, eggs);
      expect(lines.first.quantity, 6);
      expect(lines.first.scannedText, 'UOVA FRESCHE');
      expect(lines.last.isMatched, isFalse);
    });

    test('an alias failure is reported and changes nothing', () async {
      final observer = _RecordingObserver();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = _RecordingObserver());
      final cubit = await ready(catalogue: [eggs]);
      aliases.emitError(const ConnectionUnavailable());
      await pumpEventQueue();
      receiptReader.result = const Ok(reading);

      await cubit.pickReceipt(ReceiptSource.camera);

      expect(observer.reported, [const ConnectionUnavailable()]);
      expect(cubit.state, isA<RecordPurchaseReady>());
      expect(draftOf(cubit).lines.every((l) => !l.isMatched), isTrue);
    });

    test('saving a matched scanned line teaches it', () async {
      final cubit = await ready(catalogue: [eggs]);
      aliases.emitAliases([eggsAlias]);
      await pumpEventQueue();
      receiptReader.result = const Ok(reading);
      await cubit.pickReceipt(ReceiptSource.camera);
      cubit.setShopName('Lidl');
      cubit.setTotalText('4,28');

      expect(await cubit.commit(), const CommitSucceeded());
      final taught = learnedAliases(
        purchases.committed.single,
        resolveItemId: (item) => item.id,
      );
      expect(taught.single.rawTextNormalized, 'UOVA FRESCHE');
      expect(taught.single.shopName, 'Lidl');
    });

    test('retry and close manage the alias watch too', () async {
      final cubit = build();
      cubit.retry();
      expect(aliases.watchCalls, 2);

      await cubit.close();
      expect(aliases.hasListener, isFalse);
    });
  });

  group('nothing uploads before the purchase is accepted', () {
    Future<RecordPurchaseCubit> withPhoto() async {
      final cubit = await ready();
      cubit.setShopName('Conad');
      cubit.setTotalText('10');
      cubit.attachReceipt(testPhoto());
      return cubit;
    }

    test('phone: the path goes with the purchase, then the photo is '
        'confirmed and flushed', () async {
      final cubit = await withPhoto();

      expect(await cubit.commit(), const CommitSucceeded());
      expect(purchases.receiptPaths.single, 'receipts/new1');
      expect(receipts.confirmed, ['new1']);
      await pumpEventQueue();
      expect(receipts.flushes, 1);
      expect(purchases.linkedReceipts, isEmpty);
    });

    test('phone: a refused purchase discards its photo unconfirmed', () async {
      final cubit = await withPhoto();
      purchases.commitResult = const Err(PermissionDenied());

      await cubit.commit();

      expect(receipts.confirmed, isEmpty);
      expect(receipts.discarded, ['new1']);
    });

    test('web: saved without a path, uploaded, then linked', () async {
      receipts.queuesOffline = false;
      final cubit = await withPhoto();

      expect(await cubit.commit(), const CommitSucceeded());
      expect(purchases.receiptPaths.single, isNull);
      expect(receipts.confirmed, ['new1']);
      expect(purchases.linkedReceipts.single, (
        purchaseId: 'new1',
        path: 'receipts/new1',
      ));
      await pumpEventQueue();
      expect(receipts.flushes, 0);
    });

    test('web: a refused purchase uploads nothing', () async {
      receipts.queuesOffline = false;
      final cubit = await withPhoto();
      purchases.commitResult = const Err(PermissionDenied());

      expect(await cubit.commit(), const CommitFailed(PermissionDenied()));
      expect(receipts.confirmed, isEmpty);
      expect(receipts.discarded, ['new1']);
      expect(purchases.linkedReceipts, isEmpty);
    });

    test('web: a failed upload saves without the photo and says so', () async {
      receipts.queuesOffline = false;
      receipts.confirmResult = const Err(ConnectionUnavailable());
      final cubit = await withPhoto();

      expect(
        await cubit.commit(),
        const CommitSucceeded(receiptSkipped: ConnectionUnavailable()),
      );
      expect(purchases.linkedReceipts, isEmpty);
    });

    test('web: a refused link says the photo was not attached', () async {
      receipts.queuesOffline = false;
      purchases.linkResult = const Err(PermissionDenied());
      final cubit = await withPhoto();

      expect(
        await cubit.commit(),
        const CommitSucceeded(receiptSkipped: PermissionDenied()),
      );
    });
  });
}
