import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../data/run_out_notifier.dart';
import '../logic/run_out_reminder.dart';
import 'run_out_reminders_state.dart';

/// Keeps this device's run-out reminders in step with the catalogue.
///
/// Every catalogue report rebuilds the plan, and the scheduled reminders are
/// replaced only when the plan differs from what was last scheduled.
class RunOutRemindersCubit extends Cubit<RunOutRemindersState> {
  RunOutRemindersCubit(
    this._repository,
    this._notifier, {
    this._clock = DateTime.now,
  }) : super(const RunOutRemindersIdle()) {
    _subscribe();
  }

  final ItemRepository _repository;
  final RunOutNotifier _notifier;

  /// Injected so which reminders are already past is testable.
  final DateTime Function() _clock;

  StreamSubscription<List<Item>>? _subscription;

  /// The last catalogue the stream reported. Null before the first report and
  /// after a stream failure, which [refresh] then recovers from.
  List<Item>? _items;

  /// The plan the notifier last accepted. Null until then and after a failed
  /// schedule, so the next evaluation always tries again.
  List<RunOutReminder>? _scheduled;

  /// Each schedule waits for the one before, so two quick evaluations cannot
  /// interleave their cancel and schedule calls.
  Future<void> _queue = Future.value();

  /// Rebuilds the plan at the current time, or resubscribes after a stream
  /// failure. Home calls this on resume, when a reminder time may have passed.
  void refresh() {
    final items = _items;
    if (items != null) {
      _plan(items);
    } else if (state is RunOutRemindersFailure) {
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchItems().listen((items) {
      _items = items;
      _plan(items);
    }, onError: _onStreamError);
  }

  void _plan(List<Item> items) {
    final plan = runOutReminders(items, now: _clock());
    _queue = _queue.then((_) => _schedule(plan));
  }

  Future<void> _schedule(List<RunOutReminder> plan) async {
    final scheduled = _scheduled;
    if (isClosed || (scheduled != null && listEquals(scheduled, plan))) {
      return;
    }
    try {
      await _notifier.replaceAll(plan);
      _scheduled = plan;
      if (!isClosed) {
        emit(RunOutRemindersScheduled(plan));
      }
    } catch (error, stackTrace) {
      _scheduled = null;
      if (!isClosed) {
        addError(error, stackTrace);
        emit(const RunOutRemindersFailure());
      }
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _items = null;
    addError(error, stackTrace);
    emit(const RunOutRemindersFailure());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
