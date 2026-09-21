import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../data/item_repository.dart';
import '../logic/item.dart';
import 'items_state.dart';

class ItemsCubit extends Cubit<ItemsState> {
  ItemsCubit(this._repository) : super(const ItemsLoading()) {
    _subscribe();
  }

  final ItemRepository _repository;
  StreamSubscription<List<Item>>? _subscription;

  /// Subscribes again after a failure.
  ///
  /// A snapshot stream is finished once it has errored, so recovering takes a
  /// new subscription rather than waiting for the old one to right itself.
  void retry() {
    emit(const ItemsLoading());
    _subscribe();
  }

  /// Writes an item: a create when it has no document id yet, an update
  /// otherwise.
  ///
  /// The list is refreshed by the stream rather than by this call. With
  /// persistence on, the write completes only once the server acknowledges it,
  /// so a caller must not block navigation on the returned future.
  Future<Result<void, DataFailure>> save(Item item) async {
    try {
      return item.id.isEmpty
          ? await _repository.create(item)
          : await _repository.update(item);
    } catch (error, stackTrace) {
      // The repository maps the Firebase codes it knows. Anything else still
      // has to reach the caller as a failure rather than an unhandled error.
      addError(error, stackTrace);
      return const Err(UnexpectedDataFailure());
    }
  }

  /// Removes an item. Like [save], the catalogue is refreshed by the stream
  /// rather than by this call, and the returned future must not block
  /// navigation.
  Future<Result<void, DataFailure>> delete(Item item) async {
    try {
      return await _repository.delete(item);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return const Err(UnexpectedDataFailure());
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchItems().listen(
      _onItemsChanged,
      onError: _onStreamError,
    );
  }

  void _onItemsChanged(List<Item> items) =>
      emit(items.isEmpty ? const ItemsEmpty() : ItemsLoaded(items));

  /// A stream error must reach the user as a renderable state, never as an
  /// unhandled error that leaves the screen stuck on its spinner.
  void _onStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      ItemsFailure(
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
