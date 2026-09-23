import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_cubit.dart';
import 'package:grocery_accounting/features/purchases/presentation/record_purchase_state.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';
import '../fake_purchase_repository.dart';

final _now = DateTime(2026, 9, 21, 18, 30);

void main() {
  late FakePurchaseRepository purchases;
  late FakeItemRepository items;
  late FakeMemberRepository members;
  late FakeShoppingListRepository shoppingList;

  setUp(() {
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
}
