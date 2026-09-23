import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../../items/logic/running_low.dart';
import 'running_low_state.dart';

/// What is under its threshold right now, for Home.
///
/// Read only. Nothing about running low is stored, so there is nothing to
/// write and nothing to clean up when a restock lifts an item back over.
class RunningLowCubit extends Cubit<RunningLowState> {
  RunningLowCubit(this._repository, {this._clock = DateTime.now})
    : super(const RunningLowLoading()) {
    _subscribe();
  }

  final ItemRepository _repository;

  /// Injected so the rule's `now` is testable.
  final DateTime Function() _clock;

  StreamSubscription<List<Item>>? _subscription;

  /// The last catalogue the stream reported, kept so [refresh] can re-judge
  /// it. Null before the first report and after a failure.
  List<Item>? _items;

  /// Subscribes again after a failure. A snapshot stream is finished once it
  /// has errored, so recovering takes a new subscription.
  void retry() {
    _items = null;
    emit(const RunningLowLoading());
    _subscribe();
  }

  /// Re-applies the rule at the current time.
  ///
  /// Staples run down with no write to `items`, so the stream alone never
  /// reports a staple crossing its threshold. Home calls this on resume.
  void refresh() {
    final items = _items;
    if (items != null) {
      _judge(items);
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchItems().listen((items) {
      _items = items;
      _judge(items);
    }, onError: _onStreamError);
  }

  void _judge(List<Item> items) {
    final low = runningLow(items, now: _clock());
    emit(low.isEmpty ? const RunningLowNone() : RunningLowLoaded(low));
  }

  /// A stream error must reach Home as a renderable state, never as an
  /// unhandled error that leaves the section stuck on its spinner.
  void _onStreamError(Object error, StackTrace stackTrace) {
    _items = null;
    addError(error, stackTrace);
    emit(
      RunningLowFailure(
        error is DataFailure ? error : const UnexpectedDataFailure(),
      ),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
