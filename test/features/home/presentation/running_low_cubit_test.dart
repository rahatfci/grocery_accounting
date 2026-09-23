import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_cubit.dart';
import 'package:grocery_accounting/features/home/presentation/running_low_state.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/running_low.dart';

import '../../items/fake_item_repository.dart';

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
  final baseline = DateTime(2026, 9, 1, 10, 30);
  late FakeItemRepository repository;
  late _RecordingObserver observer;
  late DateTime now;

  Item stocked(
    String name, {
    required double stock,
    required double threshold,
    double dailyUsage = 0,
  }) => testItem(
    id: name,
    name: name,
    dailyUsage: dailyUsage,
    lowThreshold: threshold,
  ).copyWith(stockAtBaseline: stock, baselineDate: baseline);

  RunningLowCubit build() => RunningLowCubit(repository, clock: () => now);

  setUp(() {
    repository = FakeItemRepository();
    observer = _RecordingObserver();
    Bloc.observer = observer;
    now = baseline;
  });

  tearDown(() => Bloc.observer = _RecordingObserver());

  test('starts loading and watches the catalogue', () async {
    final cubit = build();

    expect(cubit.state, const RunningLowLoading());
    expect(repository.watchCalls, 1);

    await cubit.close();
  });

  test('lists what is under its threshold', () async {
    final cubit = build();
    final rice = stocked('Rice', stock: 1, threshold: 2);

    repository.emitItems([rice, stocked('Salt', stock: 5, threshold: 1)]);
    await pumpEventQueue();

    expect(cubit.state, RunningLowLoaded([LowStockItem(item: rice, stock: 1)]));

    await cubit.close();
  });

  test('reports nothing low for a well stocked catalogue', () async {
    final cubit = build();

    repository.emitItems([stocked('Salt', stock: 5, threshold: 1)]);
    await pumpEventQueue();

    expect(cubit.state, const RunningLowNone());

    await cubit.close();
  });

  test('reports nothing low for an empty catalogue', () async {
    final cubit = build();

    repository.emitItems(const []);
    await pumpEventQueue();

    expect(cubit.state, const RunningLowNone());

    await cubit.close();
  });

  test('clears an item once a restock lifts it over the threshold', () async {
    final cubit = build();
    final rice = stocked('Rice', stock: 1, threshold: 2);

    repository.emitItems([rice]);
    await pumpEventQueue();
    repository.emitItems([rice.copyWith(stockAtBaseline: 3)]);
    await pumpEventQueue();

    expect(cubit.state, const RunningLowNone());

    await cubit.close();
  });

  test('a stream error becomes a failure and is reported', () async {
    final cubit = build();

    repository.emitError(const PermissionDenied());
    await pumpEventQueue();

    expect(cubit.state, const RunningLowFailure(PermissionDenied()));
    expect(observer.reported, [const PermissionDenied()]);

    await cubit.close();
  });

  test('an unknown stream error maps to the unexpected failure', () async {
    final cubit = build();

    repository.emitError(StateError('boom'));
    await pumpEventQueue();

    expect(cubit.state, const RunningLowFailure(UnexpectedDataFailure()));
    expect(observer.reported.single, isA<StateError>());

    await cubit.close();
  });

  test('retry resubscribes and recovers', () async {
    final cubit = build();
    repository.emitError(const PermissionDenied());
    await pumpEventQueue();

    cubit.retry();

    expect(cubit.state, const RunningLowLoading());
    expect(repository.watchCalls, 2);

    repository.emitItems([stocked('Salt', stock: 5, threshold: 1)]);
    await pumpEventQueue();

    expect(cubit.state, const RunningLowNone());

    await cubit.close();
  });

  test('refresh picks up a staple that ran down with no write', () async {
    final cubit = build();
    final pasta = stocked('Pasta', stock: 3, threshold: 2, dailyUsage: 0.5);

    repository.emitItems([pasta]);
    await pumpEventQueue();
    expect(cubit.state, const RunningLowNone());

    now = baseline.add(const Duration(days: 3));
    cubit.refresh();

    expect(
      cubit.state,
      RunningLowLoaded([LowStockItem(item: pasta, stock: 1.5)]),
    );

    await cubit.close();
  });

  test('refresh before the stream has reported does nothing', () async {
    final cubit = build();

    cubit.refresh();

    expect(cubit.state, const RunningLowLoading());

    await cubit.close();
  });

  test('refresh after a failure keeps the failure', () async {
    final cubit = build();
    repository.emitItems([stocked('Rice', stock: 1, threshold: 2)]);
    await pumpEventQueue();
    repository.emitError(const PermissionDenied());
    await pumpEventQueue();

    cubit.refresh();

    expect(cubit.state, const RunningLowFailure(PermissionDenied()));

    await cubit.close();
  });

  test('close cancels the subscription', () async {
    final cubit = build();
    expect(repository.hasListener, isTrue);

    await cubit.close();

    expect(repository.hasListener, isFalse);
  });
}
