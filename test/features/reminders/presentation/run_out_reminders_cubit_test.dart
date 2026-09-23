import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/reminders/logic/run_out_reminder.dart';
import 'package:grocery_accounting/features/reminders/presentation/run_out_reminders_cubit.dart';
import 'package:grocery_accounting/features/reminders/presentation/run_out_reminders_state.dart';

import '../../items/fake_item_repository.dart';
import '../fake_run_out_notifier.dart';

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
  late FakeRunOutNotifier notifier;
  late _RecordingObserver observer;
  late DateTime now;

  /// A staple that runs out [days] after [baseline].
  Item staple(String name, {required double days}) => testItem(
    id: name,
    name: name,
    dailyUsage: 1,
  ).copyWith(stockAtBaseline: days, baselineDate: baseline);

  RunOutRemindersCubit build() =>
      RunOutRemindersCubit(repository, notifier, clock: () => now);

  setUp(() {
    repository = FakeItemRepository();
    notifier = FakeRunOutNotifier();
    observer = _RecordingObserver();
    Bloc.observer = observer;
    now = baseline;
  });

  tearDown(() => Bloc.observer = _RecordingObserver());

  test('starts idle and watches the catalogue', () async {
    final cubit = build();

    expect(cubit.state, const RunOutRemindersIdle());
    expect(repository.watchCalls, 1);
    expect(notifier.calls, isEmpty);

    await cubit.close();
  });

  test('schedules the first plan', () async {
    final cubit = build();
    final items = [staple('Rice', days: 4), staple('Salt', days: 0)];

    repository.emitItems(items);
    await pumpEventQueue();

    final plan = runOutReminders(items, now: baseline);
    expect(plan, hasLength(1));
    expect(notifier.calls, [plan]);
    expect(cubit.state, RunOutRemindersScheduled(plan));

    await cubit.close();
  });

  test('schedules an empty plan, clearing anything left over', () async {
    final cubit = build();

    repository.emitItems(const []);
    await pumpEventQueue();

    expect(notifier.calls, [isEmpty]);
    expect(cubit.state, const RunOutRemindersScheduled([]));

    await cubit.close();
  });

  test('does not reschedule an unchanged plan', () async {
    final cubit = build();
    final items = [staple('Rice', days: 4)];

    repository.emitItems(items);
    await pumpEventQueue();
    now = baseline.add(const Duration(hours: 5));
    repository.emitItems(items);
    cubit.refresh();
    await pumpEventQueue();

    expect(notifier.calls, hasLength(1));

    await cubit.close();
  });

  test('reschedules when the plan changes', () async {
    final cubit = build();

    repository.emitItems([staple('Rice', days: 4)]);
    await pumpEventQueue();
    final restocked = [staple('Rice', days: 9)];
    repository.emitItems(restocked);
    await pumpEventQueue();

    expect(notifier.calls, hasLength(2));
    expect(notifier.calls.last, runOutReminders(restocked, now: baseline));
    expect(
      cubit.state,
      RunOutRemindersScheduled(runOutReminders(restocked, now: baseline)),
    );

    await cubit.close();
  });

  test('drops a reminder on refresh once its time has passed', () async {
    final cubit = build();
    final items = [staple('Rice', days: 4)];

    repository.emitItems(items);
    await pumpEventQueue();
    now = DateTime(2026, 9, 4, 9, 1);
    cubit.refresh();
    await pumpEventQueue();

    expect(notifier.calls, hasLength(2));
    expect(notifier.calls.last, isEmpty);

    await cubit.close();
  });

  test('runs one schedule at a time', () async {
    final cubit = build();
    notifier.gate = Completer<void>();

    repository.emitItems([staple('Rice', days: 4)]);
    await pumpEventQueue();
    repository.emitItems([staple('Rice', days: 9)]);
    await pumpEventQueue();

    expect(notifier.calls, hasLength(1));

    notifier.gate!.complete();
    await pumpEventQueue();

    expect(notifier.calls, hasLength(2));
    expect(notifier.maxInFlight, 1);

    await cubit.close();
  });

  test(
    'reports a failed schedule and retries on the next evaluation',
    () async {
      final cubit = build();
      final items = [staple('Rice', days: 4)];
      final error = StateError('plugin');
      notifier.throwsOnce = error;

      repository.emitItems(items);
      await pumpEventQueue();

      expect(cubit.state, const RunOutRemindersFailure());
      expect(observer.reported, [error]);

      cubit.refresh();
      await pumpEventQueue();

      expect(notifier.calls, hasLength(2));
      expect(
        cubit.state,
        RunOutRemindersScheduled(runOutReminders(items, now: baseline)),
      );

      await cubit.close();
    },
  );

  test('reports a stream error and resubscribes on refresh', () async {
    final cubit = build();
    const failure = PermissionDenied();

    repository.emitError(failure);
    await pumpEventQueue();

    expect(cubit.state, const RunOutRemindersFailure());
    expect(observer.reported, [failure]);
    expect(notifier.calls, isEmpty);

    cubit.refresh();
    expect(repository.watchCalls, 2);
    repository.emitItems([staple('Rice', days: 4)]);
    await pumpEventQueue();

    expect(notifier.calls, hasLength(1));

    await cubit.close();
  });

  test('refresh before the catalogue reports does nothing', () async {
    final cubit = build();

    cubit.refresh();
    await pumpEventQueue();

    expect(notifier.calls, isEmpty);
    expect(repository.watchCalls, 1);
    expect(cubit.state, const RunOutRemindersIdle());

    await cubit.close();
  });

  test('cancels the subscription on close', () async {
    final cubit = build();
    expect(repository.hasListener, isTrue);

    await cubit.close();

    expect(repository.hasListener, isFalse);
  });

  test('a schedule finishing after close does not emit', () async {
    final cubit = build();
    notifier.gate = Completer<void>();

    repository.emitItems([staple('Rice', days: 4)]);
    await pumpEventQueue();
    await cubit.close();
    notifier.gate!.complete();
    await pumpEventQueue();

    expect(cubit.state, const RunOutRemindersIdle());
    expect(observer.reported, isEmpty);
  });
}
