import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_cubit.dart';
import 'package:grocery_accounting/features/shopping_list/presentation/shopping_list_state.dart';

import '../../auth/fake_auth_repository.dart';
import '../../items/fake_item_repository.dart';
import '../fake_shopping_list_repository.dart';

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
  final now = DateTime(2026, 9, 24, 8, 15);
  late FakeShoppingListRepository entries;
  late FakeItemRepository items;
  late _RecordingObserver observer;

  ShoppingListCubit build() => ShoppingListCubit(
    entries,
    items,
    currentUser: testUser,
    clock: () => now,
  );

  setUp(() {
    entries = FakeShoppingListRepository();
    items = FakeItemRepository();
    observer = _RecordingObserver();
    Bloc.observer = observer;
  });

  tearDown(() => Bloc.observer = _RecordingObserver());

  test('starts loading and watches the list and the catalogue', () async {
    final cubit = build();

    expect(cubit.state, const ShoppingListLoading());
    expect(entries.watchCalls, 1);
    expect(items.watchCalls, 1);

    await cubit.close();
  });

  test('lists the entries the stream reports', () async {
    final cubit = build();
    final reported = [testEntry(id: 'e1'), testEntry(id: 'e2', text: 'Eggs')];

    entries.emitEntries(reported);
    await pumpEventQueue();

    expect(cubit.state, ShoppingListLoaded(reported));

    await cubit.close();
  });

  test('an empty list is its own state', () async {
    final cubit = build();

    entries.emitEntries(const []);
    await pumpEventQueue();

    expect(cubit.state, const ShoppingListEmpty());

    await cubit.close();
  });

  test(
    'a list failure is shown and reported, and retry listens again',
    () async {
      final cubit = build();

      entries.emitError(const ConnectionUnavailable());
      await pumpEventQueue();

      expect(cubit.state, const ShoppingListFailure(ConnectionUnavailable()));
      expect(observer.reported, [const ConnectionUnavailable()]);

      cubit.retry();
      expect(cubit.state, const ShoppingListLoading());
      expect(entries.watchCalls, 2);
      expect(items.watchCalls, 2);

      entries.emitEntries([testEntry()]);
      await pumpEventQueue();

      expect(cubit.state, ShoppingListLoaded([testEntry()]));

      await cubit.close();
    },
  );

  test('an unmapped list error becomes the unexpected failure', () async {
    final cubit = build();

    entries.emitError(StateError('boom'));
    await pumpEventQueue();

    expect(cubit.state, const ShoppingListFailure(UnexpectedDataFailure()));

    await cubit.close();
  });

  group('add', () {
    test('writes trimmed text with the author and the clock', () async {
      final cubit = build();

      final result = await cubit.add('  Bread  ');

      expect(result, isA<Ok<void, DataFailure>>());
      expect(entries.added.single.text, 'Bread');
      expect(entries.added.single.addedByUserId, testUser.uid);
      expect(entries.added.single.addedAt, now);
      expect(entries.added.single.itemId, isNull);

      await cubit.close();
    });

    test('links the item the text names', () async {
      final cubit = build();
      items.emitItems([
        testItem(id: 'milk', name: 'Milk'),
        testItem(id: 'rice', name: 'Rice'),
      ]);
      await pumpEventQueue();

      await cubit.add('milk');

      expect(entries.added.single.itemId, 'milk');

      await cubit.close();
    });

    test('writes nothing for blank text', () async {
      final cubit = build();

      await cubit.add('   ');

      expect(entries.added, isEmpty);

      await cubit.close();
    });

    test('returns a refusal as its mapped failure', () async {
      final cubit = build();
      entries.addResult = const Err(PermissionDenied());

      final result = await cubit.add('Bread');

      expect(result, isA<Err<void, DataFailure>>());
      expect(
        (result as Err<void, DataFailure>).error,
        const PermissionDenied(),
      );

      await cubit.close();
    });

    test(
      'returns a thrown write as the unexpected failure and reports it',
      () async {
        final cubit = build();
        final thrown = StateError('boom');
        entries.addThrows = thrown;

        final result = await cubit.add('Bread');

        expect(
          (result as Err<void, DataFailure>).error,
          const UnexpectedDataFailure(),
        );
        expect(observer.reported, [thrown]);

        await cubit.close();
      },
    );

    test(
      'a catalogue failure leaves the list working and adds unlinked',
      () async {
        final cubit = build();
        items.emitItems([testItem(id: 'milk', name: 'Milk')]);
        await pumpEventQueue();
        items.emitError(const ConnectionUnavailable());
        entries.emitEntries([testEntry()]);
        await pumpEventQueue();

        expect(cubit.state, ShoppingListLoaded([testEntry()]));
        expect(observer.reported, [const ConnectionUnavailable()]);

        await cubit.add('Milk');

        expect(entries.added.single.itemId, isNull);

        await cubit.close();
      },
    );
  });

  group('remove', () {
    test('deletes the entry by id', () async {
      final cubit = build();

      final result = await cubit.remove(testEntry(id: 'e4'));

      expect(result, isA<Ok<void, DataFailure>>());
      expect(entries.removed, ['e4']);

      await cubit.close();
    });

    test('returns a refusal as its mapped failure', () async {
      final cubit = build();
      entries.removeResult = const Err(PermissionDenied());

      final result = await cubit.remove(testEntry());

      expect(
        (result as Err<void, DataFailure>).error,
        const PermissionDenied(),
      );

      await cubit.close();
    });

    test('returns a thrown delete as the unexpected failure', () async {
      final cubit = build();
      entries.removeThrows = StateError('boom');

      final result = await cubit.remove(testEntry());

      expect(
        (result as Err<void, DataFailure>).error,
        const UnexpectedDataFailure(),
      );
      expect(observer.reported, hasLength(1));

      await cubit.close();
    });
  });

  test('close cancels both subscriptions', () async {
    final cubit = build();
    expect(entries.hasListener, isTrue);
    expect(items.hasListener, isTrue);

    await cubit.close();

    expect(entries.hasListener, isFalse);
    expect(items.hasListener, isFalse);
  });
}
