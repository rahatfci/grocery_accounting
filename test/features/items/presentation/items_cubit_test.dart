import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/items/presentation/items_cubit.dart';
import 'package:grocery_accounting/features/items/presentation/items_state.dart';

import '../../purchases/fake_purchase_repository.dart';
import '../fake_item_repository.dart';

/// Records what a cubit reports through `addError`, which is how an
/// unexpected failure is meant to leave the app rather than being swallowed.
class RecordingBlocObserver extends BlocObserver {
  final reported = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    reported.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  late FakeItemRepository repository;
  late FakePurchaseRepository purchases;
  late RecordingBlocObserver observer;

  setUp(() {
    repository = FakeItemRepository();
    purchases = FakePurchaseRepository();
    observer = RecordingBlocObserver();
    Bloc.observer = observer;
  });

  tearDown(() => Bloc.observer = RecordingBlocObserver());

  group('the items stream', () {
    test('starts loading before the stream has reported', () {
      final cubit = ItemsCubit(repository, purchases);

      expect(cubit.state, const ItemsLoading());

      cubit.close();
    });

    test('an empty stream becomes the empty state', () async {
      final cubit = ItemsCubit(repository, purchases);
      final states = <ItemsState>[];
      cubit.stream.listen(states.add);

      repository.emitItems(const []);
      await pumpEventQueue();

      expect(states, [const ItemsEmpty()]);

      await cubit.close();
    });

    test('a populated stream becomes the loaded state', () async {
      final cubit = ItemsCubit(repository, purchases);
      final items = [testItem(name: 'Rice'), testItem(id: 'x', name: 'Salt')];

      repository.emitItems(items);
      await pumpEventQueue();

      expect(cubit.state, ItemsLoaded(items));

      await cubit.close();
    });

    test('emptying a populated catalogue returns to the empty state', () async {
      final cubit = ItemsCubit(repository, purchases);

      repository.emitItems([testItem()]);
      await pumpEventQueue();
      repository.emitItems(const []);
      await pumpEventQueue();

      expect(cubit.state, const ItemsEmpty());

      await cubit.close();
    });

    test('a stream error becomes a renderable failure state', () async {
      final cubit = ItemsCubit(repository, purchases);

      repository.emitError(const PermissionDenied());
      await pumpEventQueue();

      expect(cubit.state, const ItemsFailure(PermissionDenied()));

      await cubit.close();
    });

    test('a stream error is also reported, not just swallowed', () async {
      final cubit = ItemsCubit(repository, purchases);

      repository.emitError(const ConnectionUnavailable());
      await pumpEventQueue();

      expect(observer.reported, [const ConnectionUnavailable()]);

      await cubit.close();
    });

    test('an unmapped stream error still renders', () async {
      final cubit = ItemsCubit(repository, purchases);

      repository.emitError(StateError('something nobody mapped'));
      await pumpEventQueue();

      expect(cubit.state, const ItemsFailure(UnexpectedDataFailure()));

      await cubit.close();
    });

    test('the stream keeps reporting after a failure', () async {
      final cubit = ItemsCubit(repository, purchases);

      repository.emitError(const ConnectionUnavailable());
      await pumpEventQueue();
      repository.emitItems([testItem()]);
      await pumpEventQueue();

      expect(cubit.state, ItemsLoaded([testItem()]));

      await cubit.close();
    });
  });

  group('save', () {
    test('creates an item that has no document id yet', () async {
      final cubit = ItemsCubit(repository, purchases);
      final item = newTestItem(name: 'Flour');

      final result = await cubit.save(item);

      expect(result, isA<Ok<void, DataFailure>>());
      expect(repository.created, [item]);
      expect(repository.updated, isEmpty);

      await cubit.close();
    });

    test('updates an item that already has one', () async {
      final cubit = ItemsCubit(repository, purchases);
      final item = testItem(id: 'abc123', name: 'Rice');

      final result = await cubit.save(item);

      expect(result, isA<Ok<void, DataFailure>>());
      expect(repository.updated, [item]);
      expect(repository.created, isEmpty);

      await cubit.close();
    });

    test('returns the mapped failure when the write is refused', () async {
      repository.createResult = const Err(PermissionDenied());
      final cubit = ItemsCubit(repository, purchases);

      final result = await cubit.save(newTestItem());

      expect(result, const Err<void, DataFailure>(PermissionDenied()));

      await cubit.close();
    });

    test('turns an unexpected throw into a failure and reports it', () async {
      final thrown = StateError('the repository blew up');
      repository.updateThrows = thrown;
      final cubit = ItemsCubit(repository, purchases);

      final result = await cubit.save(testItem());

      expect(result, const Err<void, DataFailure>(UnexpectedDataFailure()));
      expect(observer.reported, [thrown]);

      await cubit.close();
    });

    test('leaves the list state to the stream, not to the write', () async {
      final cubit = ItemsCubit(repository, purchases);

      await cubit.save(newTestItem());

      expect(cubit.state, const ItemsLoading());

      await cubit.close();
    });
  });

  group('delete', () {
    test('removes the item and reports success', () async {
      final cubit = ItemsCubit(repository, purchases);
      final item = testItem();

      final result = await cubit.delete(item);

      expect(result, isA<Ok<void, DataFailure>>());
      expect(repository.deleted, [item]);

      await cubit.close();
    });

    test(
      'checks that nothing references the item before deleting it',
      () async {
        final cubit = ItemsCubit(repository, purchases);

        await cubit.delete(testItem(id: 'abc123'));

        expect(purchases.referenceChecks, ['abc123']);
        expect(repository.deleted, hasLength(1));
      },
    );

    test('refuses to delete an item a purchase still references', () async {
      purchases.referenceResult = const Ok(true);
      final cubit = ItemsCubit(repository, purchases);

      expect(
        await cubit.delete(testItem()),
        isA<Err<void, DataFailure>>().having(
          (result) => result.error,
          'error',
          const ReferenceInUse(
            'This item is on a purchase and cannot be deleted',
          ),
        ),
      );
      expect(repository.deleted, isEmpty);
    });

    test('refuses a delete whose check could not be completed', () async {
      purchases.referenceResult = const Err(ConnectionUnavailable());
      final cubit = ItemsCubit(repository, purchases);

      expect(
        await cubit.delete(testItem()),
        isA<Err<void, DataFailure>>().having(
          (result) => result.error,
          'error',
          const ConnectionUnavailable(),
        ),
      );
      expect(repository.deleted, isEmpty);
    });

    test('refuses a delete whose check threw', () async {
      purchases.referenceThrows = StateError('nothing to do with Firestore');
      final cubit = ItemsCubit(repository, purchases);

      expect(
        await cubit.delete(testItem()),
        isA<Err<void, DataFailure>>().having(
          (result) => result.error,
          'error',
          const UnexpectedDataFailure(),
        ),
      );
      expect(repository.deleted, isEmpty);
      expect(observer.reported, hasLength(1));
    });

    test('returns the mapped failure when the delete is refused', () async {
      repository.deleteResult = const Err(PermissionDenied());
      final cubit = ItemsCubit(repository, purchases);

      final result = await cubit.delete(testItem());

      expect(result, const Err<void, DataFailure>(PermissionDenied()));

      await cubit.close();
    });

    test('turns an unexpected throw into a failure and reports it', () async {
      final thrown = StateError('the repository blew up');
      repository.deleteThrows = thrown;
      final cubit = ItemsCubit(repository, purchases);

      final result = await cubit.delete(testItem());

      expect(result, const Err<void, DataFailure>(UnexpectedDataFailure()));
      expect(observer.reported, [thrown]);

      await cubit.close();
    });

    test('leaves the list state to the stream', () async {
      final cubit = ItemsCubit(repository, purchases);

      await cubit.delete(testItem());

      expect(cubit.state, const ItemsLoading());

      await cubit.close();
    });
  });

  group('retry', () {
    test('subscribes again after a failure', () async {
      final cubit = ItemsCubit(repository, purchases);
      repository.emitError(const ConnectionUnavailable());
      await pumpEventQueue();

      cubit.retry();

      expect(cubit.state, const ItemsLoading());
      expect(repository.watchCalls, 2);

      repository.emitItems([testItem()]);
      await pumpEventQueue();
      expect(cubit.state, ItemsLoaded([testItem()]));

      await cubit.close();
    });

    test('leaves only the newest subscription listening', () async {
      final cubit = ItemsCubit(repository, purchases);
      repository.emitError(const ConnectionUnavailable());
      await pumpEventQueue();

      cubit.retry();
      await pumpEventQueue();

      expect(repository.hasListener, isTrue);

      await cubit.close();

      expect(repository.hasListener, isFalse);
    });
  });

  test('close cancels the subscription', () async {
    final cubit = ItemsCubit(repository, purchases);
    await pumpEventQueue();
    expect(repository.hasListener, isTrue);

    await cubit.close();

    expect(repository.hasListener, isFalse);
  });
}
